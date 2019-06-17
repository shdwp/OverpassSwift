//
//  OverpassClient.swift
//  SwiftUITest
//
//  Created by Vasyl Horbachenko on 6/12/19.
//  Copyright © 2019. All rights reserved.
//

import Foundation
import Combine

public struct OverpassClient {
    private struct Subject: Publisher {
        typealias Output = OverpassResult
        typealias Failure = Error
        
        var task: URLSessionTask?
        let subject: PassthroughSubject<Output, Failure>
        
        init() {
            self.subject = PassthroughSubject()
        }
        
        func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
            self.subject.receive(subscriber: subscriber)
        }
    }
    
    public let url: URL
    let urlSession = URLSession(configuration: URLSessionConfiguration.default, delegate: nil, delegateQueue: OperationQueue.main)
    
    public init(_ url: URL) {
        self.url = url
    }
    
    public func request(_ apiRequest: OverpassRequest) -> AnyPublisher<OverpassResult, Error> {
        var passtrough = OverpassClient.Subject()
        var request = URLRequest(url: self.url)
        request.httpMethod = "POST"
        request.httpBody = apiRequest.requestData

        let task = self.urlSession.dataTask(with: request) { (data, response, error) in
             if let data = data {
                switch OverpassResponse(box: apiRequest.box, data: data) {
                case .result(let result):
                    passtrough.subject.send(result)
                    passtrough.subject.send(completion: .finished)
                case .error:
                    passtrough.subject.send(completion: .failure(NSError()))
                }
            } else {
                passtrough.subject.send(completion: .failure(error ?? NSError()))
            }
        }
        
        passtrough.task = task
        task.resume()
        
        return AnyPublisher(passtrough)
    }
}

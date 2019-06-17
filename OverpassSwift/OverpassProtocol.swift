//
//  OverpassML.swift
//  SwiftUITest
//
//  Created by Vasyl Horbachenko on 6/12/19.
//  Copyright © 2019. All rights reserved.
//

import Foundation
import SwiftUI

// MARK: Request
public struct OverpassRequest {
    internal let statement: OverpassStatement
    internal var box: OverpassBox
    
    public init(@OFBuilder _ content: OFBuilderSClosure) {
        self.statement = content()
        self.box = .arbitrary
        self.setupBox()
    }
    
    public init(@OFBuilder _ contents: OFBuilderMClosure) {
        self.statement = Script(contents)
        self.box = .arbitrary
        self.setupBox()
    }
    
    mutating internal func setupBox() {
        for statement in self {
            if let query = statement as? BoundingBoxQuery {
                guard
                    let s = OverpassCoordinate(query.properties["s"] ?? ""),
                    let w = OverpassCoordinate(query.properties["w"] ?? ""),
                    let n = OverpassCoordinate(query.properties["n"] ?? ""),
                    let e = OverpassCoordinate(query.properties["e"] ?? "")
                    else { continue }
                    
                self.box = .bounding(s: s, w: w, n: n, e: e)
            }
        }
    }
}

extension OverpassRequest: Sequence {
    public struct RequestIterator: IteratorProtocol {
        public typealias Element = OverpassStatement
        var iterators: [AnyIterator<OverpassStatement>]

        mutating public func next() -> OverpassStatement? {
            if let next = self.iterators.first?.next() {
                return next
            } else if let _ = self.iterators.first {
                self.iterators.removeFirst()
                return self.next()
            } else {
                return nil
            }
        }
    }
    
    public typealias Element = OverpassStatement
    public typealias Iterator = RequestIterator
    
     public func makeIterator() -> OverpassRequest.RequestIterator {
        var iterators: [AnyIterator<OverpassStatement>] = []
        func fillIterators(_ statement: OverpassStatement) {
            iterators.append(AnyIterator(statement.contents.makeIterator()))
            for statement in statement.contents {
                fillIterators(statement)
            }
        }

        fillIterators(self.statement)
        return RequestIterator(iterators: iterators)
    }
}

internal extension OverpassRequest {
    var requestData: Data {
        func append(_ node: XMLNode, _ statement: OverpassStatement) {
            for childStatement in statement.contents {
                let childNode = node.add(childStatement.name)
                for (k, v) in childStatement.properties {
                    childNode[k] = v
                }
                
                append(childNode, childStatement)
            }
        }
        
        let xml = XMLDocument(rootName: self.statement.name)
        append(xml.root, self.statement)
        
        return xml.description.data(using: .utf8)!
    }
}

// MARK: Response
public enum OverpassResponse {
    case result(result: OverpassResult)
    case error

    internal init(box: OverpassBox, data: Data) {
        var nodeMap: [OverpassId: Node] = [:]
        var interimWayArray: [InterimWay] = []
        
        // parse data
        let document = XMLDocument(data: data)
        for child in document.root.children {
            switch child.name {
            case "node":
                guard let latText = child["lat"], let lat = Double(latText) else { continue }
                guard let lonText = child["lon"], let lon = Double(lonText) else { continue }
                guard let id = child["id"] else { continue }
                nodeMap[id] = Node(id: id, location: OverpassLocation(lat: lat, lon: lon))
                
            case "way":
                guard let id = child["id"] else { continue }
                var tags: [String: String] = [:]
                var references: [OverpassId] = []
                for wayChild in child.children {
                    switch wayChild.name {
                    case "tag":
                        guard let k = wayChild["k"], let v = wayChild["v"] else { break }
                        tags[k] = v
                    case "nd":
                        guard let ref = wayChild["ref"] else { break }
                        references.append(ref)
                    default:
                        break
                    }
                }
                interimWayArray.append(InterimWay(id: id, references: references, tags: tags))
                
            default:
                break
            }
        }
        
        // filter out intermediate values
        var ways: [Way] = []
        var referencedNodeKeys: [OverpassId] = []
        for interimWay in interimWayArray {
            let referencedNodes = interimWay.references.compactMap { nodeMap[$0] }
            ways.append(interimWay.elevate(referencedNodes))
            
            referencedNodeKeys.append(contentsOf: referencedNodes.map { $0.id })
        }
        
        for referencedNodeKey in referencedNodeKeys {
            nodeMap.removeValue(forKey: referencedNodeKey)
        }
        
        self = .result(result: OverpassResult(box: box, ways: ways, loneNodes: Array(nodeMap.values)))
    }
}

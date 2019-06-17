//
//  OverpassModels.swift
//  SwiftUITest
//
//  Created by Vasyl Horbachenko on 6/13/19.
//  Copyright © 2019. All rights reserved.
//

import Foundation

// MARK: Types
public typealias OverpassCoordinate = Double
public typealias OverpassDistance = Double
public typealias OverpassId = String

public enum OverpassBox {
    case bounding(s: OverpassCoordinate, w: OverpassCoordinate, n: OverpassCoordinate, e: OverpassCoordinate)
    case area(center: OverpassLocation, area: Double)
    case arbitrary
}

// MARK: Models
public struct OverpassLocation {
    public let lat, lon: OverpassCoordinate
    
    public init(lat: OverpassCoordinate, lon: OverpassCoordinate) {
        self.lat = lat
        self.lon = lon
    }
}

public struct Node {
    public let id: OverpassId
    public let location: OverpassLocation
}

public struct Way {
    public let id: OverpassId
    public let nodes: [Node]
    public let tags: [String: String]
}

internal struct InterimWay {
    public let id: OverpassId
    public let references: [OverpassId]
    public let tags: [String: String]
    
    internal func elevate(_ nodes: [Node]) -> Way {
        return Way(id: self.id,
                   nodes: nodes,
                   tags: self.tags)
    }
}

public struct OverpassResult {
    public let box: OverpassBox
    public let ways: [Way]
    public let loneNodes: [Node]
}

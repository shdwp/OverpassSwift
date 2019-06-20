//
//  OverpassModels.swift
//  SwiftUITest
//
//  Created by Vasyl Horbachenko on 6/13/19.
//  Copyright © 2019. All rights reserved.
//

import Foundation

// MARK: Point
/// Structure representing point in lat-lon coordinate space
public struct OverpassPoint: Equatable {
    public let lat, lon: OverpassCoordinate
    
    public init(lat: OverpassCoordinate, lon: OverpassCoordinate) {
        self.lat = lat
        self.lon = lon
    }
}

extension OverpassPoint: CustomStringConvertible {
    public var description: String {
        return "point \(self.lat); \(self.lon)"
    }
}

public extension OverpassPoint {
    /// Calculate distance to other point
    /// - Parameter to: another point
    /// - Returns: distance
    func distance(to: OverpassPoint) -> OverpassDistance {
        return sqrt(pow(abs(self.lat - to.lat), 2) + pow(abs(self.lon - to.lon), 2))
    }
}

// MARK: Size
/// Structure representing size in lat-lon coordinate space
public struct OverpassSize {
    public let lat, lon: OverpassCoordinate
    
    public init(lat: OverpassCoordinate, lon: OverpassCoordinate) {
        self.lat = lat
        self.lon = lon
    }
}

extension OverpassSize: CustomStringConvertible {
    public var description: String {
        return "size \(self.lat); \(self.lon)"
    }
}

// MARK: Node
/// Basic mapping node, proving coordinates
/// Usually attached to other objects (like Ways)
public struct Node: Equatable {
    public let id: OverpassId
    public let location: OverpassPoint
}

extension Node: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
}

// MARK: Way
/// Structure representing any kind of a way (road, sidewalk, etc)
@dynamicMemberLookup
public struct Way: Equatable {
    public let id: OverpassId
    /// array of nodes. Way can be mapped if you go trough coordinates of the nodes in order of the array
    public let nodes: [Node]
    /// tags
    public let tags: [String: String]
}

extension Way: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
}

// MARK: Way: dynamicMemberLookup
public extension Way {
    subscript(dynamicMember key: String) -> String? {
        get {
            return self.tags[key]
        }
    }
}

// MARK: Way: Operators
public extension Way {
    static func +(_ lhs: Way, _ rhs: Way) -> Way {
        if lhs == rhs {
            return Way(id: lhs.id,
                       nodes: Array(lhs.nodes + rhs.nodes.filter( { !lhs.nodes.contains($0) })),
                       tags: lhs.tags)
        } else {
            return lhs
        }
    }
    
    static func +=(_ lhs: inout Way, _ rhs: Way) {
        lhs = lhs + rhs
    }
}

/// Intermediate struct used during parsing
internal struct InterimWay {
    public let id: OverpassId
    public let references: [OverpassId]
    public let tags: [String: String]
    
    internal func elevate(_ nodes: [Node]) -> Way {
        Way(id: self.id,
            nodes: nodes,
            tags: self.tags)
    }
}

// MARK: Relation
/// Structure representing relation
@dynamicMemberLookup
public struct Relation: Equatable {
    public let id: OverpassId
    /// array of included ways
    public let ways: [Way]
    /// array of included nodes
    public let nodes: [Node]
    /// tags
    public let tags: [String: String]
}

extension Relation: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
}

// MARK: Relation: dynamicMemberLookup
public extension Relation {
    subscript(dynamicMember key: String) -> String? {
        get {
            return self.tags[key]
        }
    }
}

// MARK: Relation: Operators
public extension Relation {
    static func +(_ lhs: Relation, _ rhs: Relation) -> Relation {
        if lhs == rhs {
            var ways = lhs.ways.map({ (way) -> Way in
                if let rhsWay = rhs.ways.first(where: { $0 == way }) {
                    return way + rhsWay
                } else {
                    return way
                }
            })
            
            ways.append(contentsOf: rhs.ways.filter({ way in !ways.contains(where: { $0 == way }) }))
            
            return Relation(id: lhs.id,
                            ways: ways,
                            nodes: Array(lhs.nodes + rhs.nodes.filter( { !lhs.nodes.contains($0) })),
                            tags: lhs.tags)
        } else {
            return lhs
        }
    }
    
    static func +=(_ lhs: inout Relation, _ rhs: Relation) {
        lhs = lhs + rhs
    }
}

/// Intermediate struct used during parsing
internal struct InterimRelation {
    public let id: OverpassId
    public let wayRefs: [(OverpassId, String)]
    public let nodeRefs: [OverpassId]
    public let tags: [String: String]
    
    func elevate(_ ways: [Way], _ nodes: [Node]) -> Relation {
        Relation(id: self.id,
                 ways: ways,
                 nodes: nodes,
                 tags: self.tags)
    }
}

// MARK: Result
/// Result of request from the server (parsed successful response)
public struct OverpassResult {
    /// bounds of the result (either taken from request or calculated during results merge)
    public let bounds: OverpassBounds
    /// relations
    public let relations: [Relation]
    /// array of ways
    public let ways: [Way]
    /// array of nodes that weren't attached to other objects in the result
    public let loneNodes: [Node]
}

extension OverpassResult: CustomStringConvertible {
    public var description: String {
        return "result(\(self.bounds), relations \(self.relations.count), ways \(self.ways.count), loneNodes \(self.loneNodes.count))"
    }
}

// MARK: Result: Helpers
public extension OverpassResult {
    /// Expand result with another result
    /// Ways and nodes will be correctly merged from two
    /// - Parameter result: another result
    /// - Parameter bounds: explicit bounds
    /// - Returns: merged result
    func expanded(with result: OverpassResult, newBounds bounds: OverpassBounds) -> OverpassResult {
        var relations = self.relations.map({ (relation) -> Relation in
            if let anotherRelation = result.relations.first(where: { $0 == relation }) {
                return relation + anotherRelation
            } else {
                return relation
            }
        })
        
        relations.append(contentsOf: result.relations.filter { !relations.contains($0) })
        
        var ways = self.ways.map({ (way) -> Way in
            if let anotherWay = result.ways.first(where: { $0 == way }) {
                return way + anotherWay
            } else {
                return way
            }
        })
        
        ways.append(contentsOf: result.ways.filter { !ways.contains($0) })
        
        return OverpassResult(bounds: bounds,
                              relations: relations,
                              ways: ways,
                              loneNodes: Array(Set(self.loneNodes + result.loneNodes)))
    }
    
    /// Expand result with another result
    /// Ways and nodes will be correctly merged from two
    /// Bounds will be taken from `result`
    /// - Parameter result: another result
    /// - Returns: merged result
    func expanded(with result: OverpassResult) -> OverpassResult {
        return self.expanded(with: result, newBounds: result.bounds)
    }
}

//MARK: Result: Operators
public extension OverpassResult {
    static func +(_ lhs: OverpassResult, _ rhs: OverpassResult) -> OverpassResult {
        return lhs.expanded(with: rhs, newBounds: rhs.bounds)
    }
    
    static func +=(_ lhs: inout OverpassResult, _ rhs: OverpassResult) {
        lhs = lhs + rhs
    }
}

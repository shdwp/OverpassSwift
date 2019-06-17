//
//  OverpassRequest.swift
//  SwiftUITest
//
//  Created by Vasyl Horbachenko on 6/13/19.
//  Copyright © 2019. All rights reserved.
//

import Foundation

// MARK: FunctionBuilder
@_functionBuilder public struct OFBuilder  {
    public typealias T = OverpassStatement

    public static func buildBlock() -> [T] {
        return []
    }
    
    public static func buildBlock(_ a: T) -> [T] {
        return [a, ]
    }

    public static func buildBlock(_ a: T, _ b: T) -> [T] {
        return [a, b, ]
    }
    
    public static func buildBlock(_ a: T, _ b: T, _ c: T) -> [T] {
        return [a, b, c, ]
    }
    
    public static func buildBlock(_ a: T, _ b: T, _ c: T, _ d: T) -> [T] {
        return [a, b, c, d, ]
    }
    
    public static func buildBlock(_ a: T, _ b: T, _ c: T, _ d: T, _ e: T) -> [T] {
        return [a, b, c, d, e, ]
    }
    
    public static func buildBlock(_ a: T, _ b: T, _ c: T, _ d: T, _ e: T, _ f: T) -> [T] {
        return [a, b, c, d, e, f, ]
    }
}

public typealias OFBuilderMClosure = () -> [OverpassStatement]
public typealias OFBuilderSClosure = () -> OverpassStatement

// MARK: Protocol
public protocol OverpassStatement {
    var name: String { get }
    var properties: [String: String] { get }
    var contents: [OverpassStatement] { get }
}

// MARK: Script
public struct Script: OverpassStatement {
    public var name = "osm-script"
    public var contents: [OverpassStatement] = []
    public var properties: [String: String] = [:]
    
    public init() {
        self.properties = [
            "timeout": "10",
            "element-limit": "1073741824",
        ]
    }
    
    public init(@OFBuilder _ contents: OFBuilderSClosure) {
        self.init()
        self.contents = [contents(), ]
    }

    public init(@OFBuilder _ contents: OFBuilderMClosure) {
        self.init()
        self.contents = contents()
    }
}

// MARK: Statements
public struct Union: OverpassStatement {
    public var name = "union"
    public var properties: [String: String] = [:]
    public var contents: [OverpassStatement] = []
    
    public init(@OFBuilder _ contents: OFBuilderSClosure) {
        self.contents = [contents(), ]
    }

    public init(@OFBuilder _ contents: OFBuilderMClosure) {
        self.contents = contents()
    }
    
    public init(into: String) {
        self.properties = [
            "into": into,
        ]
    }
    
    public init(into: String, @OFBuilder _ contents: OFBuilderSClosure) {
        self.init(into: into)
        self.contents = [contents(), ]
    }
    
    public init(into: String, @OFBuilder _ contents: OFBuilderMClosure) {
        self.init(into: into)
        self.contents = contents()
    }
}

// MARK: Query
public struct Query: OverpassStatement {
    public enum QType: String {
        case node = "node"
        case way = "way"
        case relation = "rel"
        case area = "area"
    }

    public var name = "query"
    public var contents: [OverpassStatement] = []
    public var properties: [String: String] = [:]

    public init(_ t: QType, _ into: String = "_") {
        self.properties = [
            "type": t.rawValue,
            "into": into,
        ]
    }
    
    public init(_ t: QType, @OFBuilder _ content: OFBuilderSClosure) {
        self.init(t)
        self.contents = [content(), ]
    }
    
    public init(_ t: QType, @OFBuilder _ contents: OFBuilderMClosure) {
        self.init(t)
        self.contents = contents()
    }
}

public struct BoundingBoxQuery: OverpassStatement {
    public var name = "bbox-query"
    public var contents: [OverpassStatement] = []
    public var properties: [String: String] = [:]
    
    public init(s: OverpassCoordinate, w: OverpassCoordinate, n: OverpassCoordinate, e: OverpassCoordinate) {
        self.properties = [
            "s": String(s),
            "w": String(w),
            "n": String(n),
            "e": String(e),
        ]
    }
}

public struct PolygonQuery: OverpassStatement {
    public var name = "polygon-query"
    public var contents: [OverpassStatement] = []
    public var properties: [String: String] = [:]
    
    public init(bounds: [OverpassCoordinate]) {
        self.properties = [
            "bounds": bounds.map({ String($0) }).joined(separator: " "),
        ]
    }
}

public struct IdQuery: OverpassStatement {
    public var name = "id-query"
    public var contents: [OverpassStatement] = []
    public var properties: [String: String] = [:]
    
    public init(_ t: Query.QType, ref: OverpassId) {
        self.properties = [
            "type": t.rawValue,
            "ref": ref,
        ]
    }
    
    public init(_ t: Query.QType, ref: OverpassId, @OFBuilder _ content: OFBuilderSClosure) {
        self.init(t, ref: ref)
        self.contents = [content(), ]
    }
    
    public init(_ t: Query.QType, ref: OverpassId, @OFBuilder _ contents: OFBuilderMClosure) {
        self.init(t, ref: ref)
        self.contents = contents()
    }
}

public struct Recurse: OverpassStatement {
    public enum RecurseType: String {
        case up = "up"
        case upRel = "up-rel"
        case down = "down"
        case downRel = "down-rel"
    }
    
    public var name = "recurse"
    public var contents: [OverpassStatement] = []
    public var properties: [String: String] = [:]
    
    public init(_ t: RecurseType) {
        self.properties = [
            "type": t.rawValue,
        ]
    }
    
    public init(stringType: String) {
        self.properties = [
            "type": stringType,
        ]
    }
}

// MARK: Filters
public struct HasKV: OverpassStatement {
    public var name = "has-kv"
    public var contents: [OverpassStatement] = []
    public var properties: [String: String] = [:]
    
    public init(hasKey key: String) {
        self.properties = [
            "k": key,
        ]
    }

    public init(key: String, equals: Bool, value: String) {
        self.properties = [
            "k": key,
            "v": value,
        ]
        
        if equals == false {
            self.properties["modv"] = "not"
        }
    }
    
    public init(key: String, value: String) {
        self.init(key: key, equals: true, value: value)
    }
    
    public init(key: String, equals: Bool, regex: String) {
        self.properties = [
            "k": key,
            "regv": regex,
        ]
        
        if equals == false {
            self.properties["modv"] = "not"
        }
    }
    
    public init(key: String, regex: String) {
        self.init(key: key, equals: true, regex: regex)
    }
}

public struct Around: OverpassStatement {
    public var name = "around"
    public var contents: [OverpassStatement] = []
    public var properties: [String: String] = [:]
    
    public init(radius: OverpassDistance) {
        self.properties = [
            "radius": String(radius),
        ]
    }
}

// MARK: Output
public struct Print: OverpassStatement {
    public enum PrintType: String {
        case body = "body"
        case skeleton = "skeleton"
        case idsOnly = "ids_only"
        case meta = "meta"
    }
    
    public var name = "print"
    public var contents: [OverpassStatement] = []
    public var properties: [String: String] = [:]
    
    public init(_ m: PrintType, from: String) {
        self.properties = [
            "mode": m.rawValue,
            "from": from,
        ]
    }
    
    public init(_ m: PrintType) {
        self.init(m, from: "_")
    }

    public init() {
        self.init(.body)
    }
}

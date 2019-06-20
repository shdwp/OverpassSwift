//
//  OverpassRequest.swift
//  SwiftUITest
//
//  Created by Vasyl Horbachenko on 6/13/19.
//  Copyright © 2019. All rights reserved.
//

import Foundation

// MARK: FunctionBuilder
/**
 Note: `@functionBuilder` is in beta as of time when this was written,
 therefore code include a couple of workarounds:
 - `If` helper instead of `buildIf` family of methods
 - Separate constructors for single and many elements
 */
@_functionBuilder public struct OFBuilder  {
    public typealias T = OverpassStatement

    public static func buildBlock() -> [T] {
        return []
    }
    
    public static func buildBlock(_ a: T...) -> [T] {
        return a
    }
}

// closure types for @OFBuilder arguments
public typealias OFBuilderMClosure = () -> [OverpassStatement]
public typealias OFBuilderSClosure = () -> OverpassStatement

// MARK: Protocol
/// General statement protocol, which will be turned to XML for the request
public protocol OverpassStatement {
    /// name of the statement, goes in as a tag name. Empty name will not create new tag, contents will be put directly into parent
    var name: String { get }
    
    /// properties, go into properties
    var properties: [String: String] { get }
    
    /// child statements
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
            "element-limit": "50000",
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
    
    public init(_ t: QType, into: String, @OFBuilder _ content: OFBuilderSClosure) {
        self.init(t, into)
        self.contents = [content(), ]
    }
    
    public init(_ t: QType, into: String, @OFBuilder _ contents: OFBuilderMClosure) {
        self.init(t, into)
        self.contents = contents()
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

public struct Bounding: OverpassStatement {
    internal let bounds: OverpassBounds
    
    public var name: String {
        switch self.bounds {
        case .box:
            return "bbox-query"
        case .area:
            return "around"
        case .polygon:
            return "polygon-query"
        case .arbitrary:
            return "query"
        }
    }
    
    public var contents: [OverpassStatement] = []
    public var properties: [String: String] = [:]
    
    public init(_ bounds: OverpassBounds) {
        self.bounds = bounds
        switch bounds {
        case .box(let s, let w, let n, let e):
            self.properties = [
                "s": String(s),
                "w": String(w),
                "n": String(n),
                "e": String(e),
            ]
        case .area(_, let area):
            self.properties = [
                "radius": String(area),
            ]
        case .polygon(let points):
            self.properties = [
                "bounds": points.map({ "\($0.lat) \($0.lon)" }).joined(separator: " "),
            ]
        default:
            break
        }
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
    
    public init(from: String) {
        self.init(.body, from: from)
    }

    public init() {
        self.init(.body)
    }
}

// MARK: Helpers
public struct ForEach<T>: OverpassStatement {
    public var name = ""
    public var contents: [OverpassStatement] = []
    public var properties: [String: String] = [:]
    
    public init(_ collection: [T], _ body: (T) -> OverpassStatement) {
        self.contents = collection.map( { body($0) } )
    }
    
    public init(_ collection: [T], _ body: (Int, T) -> OverpassStatement) {
        self.contents = collection.enumerated().map( { body($0, $1) } )
    }
    
    public init(_ collection: [T], @OFBuilder _ body: (Int, T) -> [OverpassStatement]) {
        self.contents = collection.enumerated().flatMap( { body($0, $1) } )
    }
}

public struct If: OverpassStatement {
    public var name = ""
    public var contents: [OverpassStatement] = []
    public var properties: [String: String] = [:]
    
    public init(_ condition: Bool, @OFBuilder content: OFBuilderSClosure) {
        if condition {
            self.contents = [content(), ]
        }
    }
    
    public init(_ condition: Bool, @OFBuilder contents: OFBuilderMClosure) {
        if condition {
            self.contents = contents()
        }
    }

    public init(_ condition: Bool, @OFBuilder trueContent: OFBuilderSClosure, @OFBuilder falseContent: OFBuilderSClosure) {
        if condition {
            self.contents = [trueContent(), ]
        } else {
            self.contents = [falseContent(), ]
        }
    }
    
    public init(_ condition: Bool, @OFBuilder trueContents: OFBuilderMClosure, @OFBuilder falseContent: OFBuilderSClosure) {
        if condition {
            self.contents = trueContents()
        } else {
            self.contents = [falseContent(), ]
        }
    }
    
    public init(_ condition: Bool, @OFBuilder trueContent: OFBuilderSClosure, @OFBuilder falseContents: OFBuilderMClosure) {
        if condition {
            self.contents = [trueContent(), ]
        } else {
            self.contents = falseContents()
        }
    }
    
    public init(_ condition: Bool, @OFBuilder trueContents: OFBuilderMClosure, @OFBuilder falseContents: OFBuilderMClosure) {
        if condition {
            self.contents = trueContents()
        } else {
            self.contents = falseContents()
        }
    }
}

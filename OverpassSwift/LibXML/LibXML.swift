//
//  LibXML.swift
//  SwiftUITest
//
//  Created by Vasyl Horbachenko on 6/12/19.
//  Copyright © 2019 Medtronic. All rights reserved.
//

import Foundation
import libxml2

/// Tiny wrapper around libxml2

// MARK: XMLDocument
internal class XMLDocument {
    internal let ptr: xmlDocPtr
    public var root: XMLNode

    public init(rootName: String) {
        let nodePtr = xmlNewNode(nil, rootName)!
        
        self.ptr = xmlNewDoc("1.0")
        xmlDocSetRootElement(self.ptr, nodePtr)
        self.root = XMLNode(nodePtr)
    }
    
    public init(data: Data) {
        self.ptr = xmlParseDoc(String(data: data, encoding: .utf8))
        self.root = XMLNode(xmlDocGetRootElement(self.ptr))
    }

    deinit {
        xmlFree(self.ptr)
    }
}

extension XMLDocument {
    public var data: Data {
        var ptr: UnsafeMutablePointer<xmlChar>?
        var size: Int32 = 0
        
        xmlDocDumpFormatMemoryEnc(self.ptr, &ptr, &size, "UTF-8", 1);
        return Data(bytesNoCopy: ptr!, count: Int(size), deallocator: .free)
    }
}

extension XMLDocument: CustomStringConvertible {
    public var description: String {
        return String(data: self.data, encoding: .utf8) ?? ""
    }
}

// MARK: XMLNode
internal class XMLNode {
    internal let ptr: xmlNodePtr
    
    init(_ ptr: xmlNodePtr) {
        self.ptr = ptr
    }
    
    init(_ name: String, content: String?) {
        self.ptr = xmlNewNode(nil, name)
        if let content = content {
            xmlNodeSetContent(self.ptr, content)
        }
    }
    
}

extension XMLNode: CustomStringConvertible {
    public var description: String {
        var result = "<XMLNode \(self.name) "
        
        var property = self.ptr.pointee.properties
        while property != nil {
            result += String(cString: property!.pointee.name) + ", "
            
            guard let _ = property?.pointee.next else { break }
            property = property?.pointee.next
        }
        
        return result + ">"
    }
}

extension XMLNode: Sequence {
    public struct IteratorImpl: IteratorProtocol {
        public typealias Element = XMLNode
        
        var ptr: xmlNodePtr
        
        public mutating func next() -> XMLNode.IteratorImpl.Element? {
            if let newPtr = self.ptr.pointee.next {
                self.ptr = newPtr
                return XMLNode(newPtr)
            } else {
                return nil
            }
        }
    }
    
    public typealias Element = XMLNode
    public typealias Iterator = IteratorImpl
    
    public func makeIterator() -> XMLNode.IteratorImpl {
        return IteratorImpl(ptr: self.ptr.pointee.children)
    }
}

extension XMLNode {
    public var name: String {
        return String(cString: self.ptr.pointee.name)
    }
    
    public var content: String? {
        return String(cString: self.ptr.pointee.content)
    }
    
    public var children: AnySequence<XMLNode> {
        return AnySequence(self)
    }
    
    public func add(_ name: String) -> XMLNode {
        let node = XMLNode(name, content: nil)
        xmlAddChild(self.ptr, node.ptr)
        return node
    }
    
    public func add(_ name: String, content: String) -> XMLNode {
        let node = XMLNode(name, content: content)
        xmlAddChild(self.ptr, node.ptr)
        return node
    }
    
    public func find(_ name: String) -> XMLNode? {
        return self.children.first(where: { return $0.name == name })
    }
    
    subscript(key: String) -> String? {
        get {
            return String(cString: xmlGetProp(self.ptr, key))
        }
        
        set(value) {
            xmlNewProp(self.ptr, key, value)
        }
    }
}

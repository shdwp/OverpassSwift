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
/// Request struct. Holds a tree of OverpassStatements and serializes them to the XML
public struct OverpassRequest {
    internal let statement: OverpassStatement
    internal var bounds: OverpassBounds
    
    public init(@OFBuilder _ content: OFBuilderSClosure) {
        self.statement = Script {
            content()
        }
        
        self.bounds = .arbitrary
        self.setupBox()
    }
    
    public init(@OFBuilder _ contents: OFBuilderMClosure) {
        self.statement = Script(contents)
        self.bounds = .arbitrary
        self.setupBox()
    }
    
    /// Set the bound variable based on the statement tree
    mutating internal func setupBox() {
        for statement in self {
            if let query = statement as? Bounding {
                self.bounds = query.bounds
            }
        }
    }
}

/// Internal recursive OverpassRequest iterator
extension OverpassRequest: Sequence {
    public struct _RequestIterator: IteratorProtocol {
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
    public typealias Iterator = _RequestIterator
    
     public func makeIterator() -> OverpassRequest._RequestIterator {
        var iterators: [AnyIterator<OverpassStatement>] = []
        func fillIterators(_ statement: OverpassStatement) {
            iterators.append(AnyIterator(statement.contents.makeIterator()))
            for statement in statement.contents {
                fillIterators(statement)
            }
        }

        fillIterators(self.statement)
        return _RequestIterator(iterators: iterators)
    }
}

internal extension OverpassRequest {
    /// XML request data
    var requestData: Data {
        func append(_ node: XMLNode, _ statement: OverpassStatement) {
            for childStatement in statement.contents {
                if childStatement.name.isEmpty {
                    append(node, childStatement)
                } else {
                    let childNode = node.add(childStatement.name)
                    for (k, v) in childStatement.properties {
                        childNode[k] = v
                    }
                    
                    append(childNode, childStatement)
                }
            }
        }
        
        let xml = XMLDocument(rootName: self.statement.name)
        append(xml.root, self.statement)
        
        return xml.description.data(using: .utf8)!
    }
}

// MARK: Response
/// Enum representing server response
public enum OverpassResponse {
    /// request success, providing OverpassResult
    case result(result: OverpassResult)
    /// request failure
    case error

    internal init(bounds: OverpassBounds, data: Data) {
        var nodeMap: [OverpassId: Node] = [:]
        var interimWayMap: [OverpassId: InterimWay] = [:]
        var interimRelations: [InterimRelation] = []
        
        // parse data
        let document = XMLDocument(data: data)
        for child in document.root.children {
            switch child.name {
            case "node":
                guard let latText = child["lat"], let lat = Double(latText) else { continue }
                guard let lonText = child["lon"], let lon = Double(lonText) else { continue }
                guard let id = child["id"] else { continue }
                nodeMap[id] = Node(id: id, location: OverpassPoint(lat: lat, lon: lon))
                
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
                interimWayMap[id] = InterimWay(id: id, references: references, tags: tags)
                
            case "relation":
                guard let id = child["id"] else { continue }
                var tags: [String: String] = [:]
                var wayRefs: [(OverpassId, String)] = []
                var nodeRefs: [OverpassId] = []
                for relChild in child.children {
                    switch relChild.name {
                    case "tag":
                        guard let k = relChild["k"], let v = relChild["v"] else { break }
                        tags[k] = v
                    case "member":
                        guard let type = relChild["type"] else { break }
                        switch type {
                        case "way":
                            guard let id = relChild["ref"] else { break }
                            guard let role = relChild["role"] else { break }
                            wayRefs.append((id, role))
                        case "node":
                            guard let id = relChild["ref"] else { break }
                            nodeRefs.append(id)
                        default:
                            break
                        }
                    default:
                        break
                    }
                }
                interimRelations.append(InterimRelation(id: id,
                                                        wayRefs: wayRefs,
                                                        nodeRefs: nodeRefs,
                                                        tags: tags))
                
            default:
                break
            }
        }
        
        // filter out intermediate values
        var relations: [Relation] = []
        var wayMap: [OverpassId: Way] = [:]
        var referencedWayKeys: [OverpassId] = []
        var referencedNodeKeys: [OverpassId] = []
        
        for interimWay in interimWayMap.values {
            let referencedNodes = interimWay.references.compactMap { nodeMap[$0] }
            wayMap[interimWay.id] = interimWay.elevate(referencedNodes)
            
            referencedNodeKeys.append(contentsOf: referencedNodes.map { $0.id })
        }

        for interimRelation in interimRelations {
            let referencedNodes = interimRelation.nodeRefs.compactMap { nodeMap[$0] }
            let referencedWays = interimRelation.wayRefs.compactMap { wayMap[$0.0] }
            relations.append(interimRelation.elevate(referencedWays, referencedNodes))
            
            referencedNodeKeys.append(contentsOf: referencedNodes.map { $0.id })
            referencedWayKeys.append(contentsOf: referencedWays.map { $0.id })
        }
        
        // leave only lone nodes and ways
        for referencedWayKey in referencedWayKeys {
            wayMap.removeValue(forKey: referencedWayKey)
        }

        for referencedNodeKey in referencedNodeKeys {
            nodeMap.removeValue(forKey: referencedNodeKey)
        }
        
        self = .result(result: OverpassResult(bounds: bounds,
                                              relations: relations,
                                              ways: Array(wayMap.values),
                                              loneNodes: Array(nodeMap.values)))
    }
}

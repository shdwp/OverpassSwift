//
//  OverpassTypes.swift
//  OverpassSwift
//
//  Created by Vasyl Horbachenko on 6/20/19.
//  Copyright © 2019 shdwp. All rights reserved.
//

import Foundation

public typealias OverpassCoordinate = Double
public typealias OverpassDistance = Double
public typealias OverpassId = String

// MARK: Bounds
/// Enum representing any kind of boundary. Used for both requests and results
public enum OverpassBounds: Equatable {
    /// box boundary - rectangular boundary with south, west, north and east coordinates
    case box(s: OverpassCoordinate, w: OverpassCoordinate, n: OverpassCoordinate, e: OverpassCoordinate)
    /// area boundary - location & radius
    case area(center: OverpassPoint, area: OverpassDistance)
    /// polygon
    case polygon(_ points: [OverpassPoint])
    /// no boundary
    case arbitrary
    
    /// Construct .box boundary by providing point and size
    /// - Parameter point: top-left (NW) point
    /// - Parameter size: size in same coordinate space
    public init(point: OverpassPoint, size: OverpassSize) {
        self = .box(s: point.lat - size.lat, w: point.lon, n: point.lat, e: point.lon + size.lon)
    }
}

// MARK: Bounds: Description
extension OverpassBounds: CustomStringConvertible {
    public var description: String {
        switch self {
        case .box(let s, let w, let n, let e):
            return "box (\(s), \(w), \(n), \(e))"
        case .area(let center, let area):
            return "area (\(center), \(area))"
        case .polygon(let points):
            return "poly (\(points))"
        case .arbitrary:
            return "arbitrary"
        }
    }
}

// MARK: Bounds: Geom
public extension OverpassBounds {
    /// diameter of the boundary
    var diameter: OverpassDistance {
        switch self {
        case let .box(s, w, n, e):
            return OverpassPoint(lat: s, lon: w).distance(to: OverpassPoint(lat: n, lon: e))
        case let .area(_, area):
            return area
        default:
            return Double.infinity
        }
    }
    
    /// Check if boundary contains point.
    /// **Returns false on border values!**
    /// - Parameter point: point
    /// - Returns: bool
    func contains(point: OverpassPoint) -> Bool {
        switch self {
        case let .box(s, w, n, e):
            return (point.lat > s && point.lat < n && point.lon >= w && point.lon <= e) || (point.lat >= s && point.lat <= n && point.lon > w && point.lon < e)
        case let .area(center, area):
            return point.distance(to: center) < area
        case .polygon:
            fatalError("not supported")
        case .arbitrary:
            return true
        }
    }
    
    /// Check if point touches boundary (point is on the very edge of the boundary)
    /// - Parameter point: point
    /// - Returns: bool
    func touches(point: OverpassPoint) -> Bool {
        switch self {
        case let .box(s, w, n, e):
            return (point.lat == s || point.lat == n) && (point.lon == w || point.lon == e)
        case let .area(center, area):
            return point.distance(to: center) == area
        case .polygon:
            fatalError("not supported")
        case .arbitrary:
            return false
        }
    }
    
    /// Calculate difference between self and another boundary
    /// Will provide boundary array of areas that are in `another` boundary, but not in `self`
    /// **Only .box on .box is currently implemented**
    /// - Parameter another: another boundary
    /// - Returns: array of boundaries
    func difference(_ another: OverpassBounds) -> [OverpassBounds] {
        switch self {
        case .box(let s1, let w1, let n1, let e1):
            switch another {
            case .box(let s2, let w2, let n2, let e2):
                return Self.boxMinusBox((s1, w1, n1, e1),
                                        (s2, w2, n2, e2))
            default:
                return []
            }
        default:
            return []
        }
    }
}

// MARK: Bounds: Private
fileprivate extension OverpassBounds {
    private static func boxMinusBox(_ lhs: (s: OverpassCoordinate, w: OverpassCoordinate, n: OverpassCoordinate, e: OverpassCoordinate),
                                    _ rhs: (s: OverpassCoordinate, w: OverpassCoordinate, n: OverpassCoordinate, e: OverpassCoordinate)) -> [OverpassBounds] {
        // same bounds for convenience
        let lhsBounds = OverpassBounds.box(s: lhs.s, w: lhs.w, n: lhs.n, e: lhs.e)
        let rhsBounds = OverpassBounds.box(s: rhs.s, w: rhs.w, n: rhs.n, e: rhs.e)
        
        // vertical, lon coordinates sorted
        let vertical = [lhs.e, lhs.w, rhs.e, rhs.w].sorted()
        // horizontal, lat coordinates sorted
        let horizontal = [lhs.n, lhs.s, rhs.n, rhs.s].sorted()
        
        // array of points forming result poly
        var points: [OverpassPoint] = []
        
        // populate result poly array
        for lon in vertical {
            for lat in horizontal {
                let point = OverpassPoint(lat: lat, lon: lon)
                if (lhsBounds.contains(point: point) || lhsBounds.touches(point: point)) && !rhsBounds.contains(point: point) {
                    // point is a part of lhs, that may touch rhs
                    points.append(point)
                }
            }
        }
        
        // array of difference rects
        var rects: [(OverpassPoint, OverpassPoint)] = []
        for point in points {
            // skip already processed points
            if !points.contains(point) {
                continue
            }
            
            // sort remaining points by distance to current one
            let sorted = points.sorted { (a, b) -> Bool in
                return point.distance(to: a) < point.distance(to: b)
            }
            
            // find closest point index that is not the current point
            if let closestIndex = sorted.firstIndex(where: { $0.lat != point.lat && $0.lon != point.lon }) {
                let closestPoint = sorted[closestIndex]
                
                // test whether we already have that rect in the result array
                if !rects.contains(where: {
                    func test(_ a: (OverpassPoint, OverpassPoint), _ b: (OverpassPoint, OverpassPoint)) -> Bool {
                        if a == b {
                            return true
                        }
                        
                        if a == (b.1, b.0) {
                            return true
                        }
                        
                        let c = OverpassPoint(lat: b.0.lat, lon: b.1.lon)
                        let d = OverpassPoint(lat: b.1.lat, lon: b.0.lon)
                        
                        if a == (c, d) {
                            return true
                        }
                        
                        if a == (d, c) {
                            return true
                        }
                        
                        return false
                    }
                    
                    if test($0, (point, closestPoint)) {
                        return true
                    } else {
                        return false
                    }
                }) {
                    rects.append((point, closestPoint))
                }
            }
        }
        
        var bounds: [OverpassBounds] = []
        for rect in rects {
            let bound = OverpassBounds.box(s: min(rect.0.lat, rect.1.lat), w: min(rect.0.lon, rect.1.lon), n: max(rect.0.lat, rect.1.lat), e: max(rect.0.lon, rect.1.lon))
            if bound != rhsBounds {
                bounds.append(bound)
            }
        }
        
        return bounds
    }
    
}


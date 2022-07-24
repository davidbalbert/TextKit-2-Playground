//
//  CGPoint+Extensions.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 6/19/22.
//

import Foundation

extension CGPoint {
    static func - (_ l: CGPoint, _ r: CGPoint) -> CGPoint {
        CGPoint(x: l.x - r.x, y: l.y - r.y)
    }
}

extension CGPoint: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
}

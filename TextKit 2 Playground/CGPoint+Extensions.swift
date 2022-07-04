//
//  CGPoint+Extensions.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 6/19/22.
//

import Foundation

extension CGPoint: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
}

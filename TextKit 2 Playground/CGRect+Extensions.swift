//
//  CGRect+Extensions.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 6/19/22.
//

import Foundation

extension CGRect: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(origin)
        hasher.combine(size)
    }
}

extension CGRect {
    var pixelAligned: CGRect {
        NSIntegralRectWithOptions(self, .alignAllEdgesNearest)
    }
}

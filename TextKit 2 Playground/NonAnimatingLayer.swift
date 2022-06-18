//
//  NonAnimatingLayer.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 6/18/22.
//

import Cocoa

class NonAnimatingLayer: CALayer {
    override static func defaultAction(forKey event: String) -> CAAction? {
        return NSNull()
    }
}

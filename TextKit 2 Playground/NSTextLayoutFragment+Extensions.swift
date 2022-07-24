//
//  NSTextLayoutFragment+Extensions.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 7/23/22.
//

import Cocoa

extension NSTextLayoutFragment {
    var typographicBounds: CGRect {
        CGRect(origin: .zero, size: layoutFragmentFrame.size)
    }

    // Converts point from the textContainer's coordinate system into the layout
    // fragment's coordinate system.
    func convertToLayoutFragment(_ point: CGPoint) -> CGPoint {
        point - layoutFragmentFrame.origin
    }
}

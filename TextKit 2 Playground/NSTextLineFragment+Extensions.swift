//
//  NSTextLineFragment+Extensions.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 7/23/22.
//

import Cocoa

extension NSTextLineFragment {
    // Converts a point in the layout fragment's coordinate system into the
    // line fragment's coordinate system.
    func convertToLineFragment(_ point: CGPoint) -> CGPoint {
        point - typographicBounds.origin
    }
}

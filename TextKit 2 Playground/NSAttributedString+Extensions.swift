//
//  NSAttributedString+Extensions.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 6/26/22.
//

import Foundation

extension NSAttributedString {
    var withoutBackgroundColor: NSAttributedString {
        let s = NSMutableAttributedString(attributedString: self)
        let range = NSRange(location: 0, length: length)
        s.removeAttribute(.backgroundColor, range: range)

        return s
    }

    func containsAttribute(_ name: NSAttributedString.Key, in range: NSRange) -> Bool {
        var found = false

        enumerateAttribute(name, in: range, options: .longestEffectiveRangeNotRequired) { color, attributeRange , stop in

            if color != nil {
                found = true
                stop.pointee = true
            }
        }

        return found
    }
}

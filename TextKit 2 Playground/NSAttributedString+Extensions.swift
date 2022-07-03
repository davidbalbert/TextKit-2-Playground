//
//  NSAttributedString+Extensions.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 6/26/22.
//

import Foundation

extension NSAttributedString.Key {
    static let undrawnBackgroundColor = NSAttributedString.Key("undrawnBackgroundColor")
}

extension NSAttributedString {
    func replacingAttribute(_ oldName: NSAttributedString.Key, with newName: NSAttributedString.Key) -> NSAttributedString {
        let s = NSMutableAttributedString(attributedString: self)
        let range = NSRange(location: 0, length: length)

        s.enumerateAttribute(oldName, in: range) { value, attributeRange, _ in
            if let value = value {
                s.removeAttribute(oldName, range: attributeRange)
                s.addAttributes([newName: value], range: attributeRange)
            }
        }

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

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
    convenience init?(anyString string: Any) {
        if let string = string as? String {
            self.init(string: string)
        } else if let attributedString = string as? NSAttributedString {
            self.init(attributedString: attributedString)
        } else {
            return nil
        }
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

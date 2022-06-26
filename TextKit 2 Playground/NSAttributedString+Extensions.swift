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
}

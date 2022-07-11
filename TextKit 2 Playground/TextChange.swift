//
//  TextChange.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 7/10/22.
//

import Cocoa

enum TextChange {
    case replace(textRange: NSTextRange, attributedString: NSAttributedString)
    case delete(textRange: NSTextRange)
}

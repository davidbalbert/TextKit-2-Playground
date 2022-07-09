//
//  NSMutableAttributedString+Extensions.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 7/9/22.
//

import Foundation

extension NSMutableAttributedString {
    func replaceAttribute(_ oldName: NSAttributedString.Key, with newName: NSAttributedString.Key) {
        let range = NSRange(location: 0, length: length)

        enumerateAttribute(oldName, in: range) { value, attributeRange, _ in
            if let value = value {
                removeAttribute(oldName, range: attributeRange)
                addAttributes([newName: value], range: attributeRange)
            }
        }
    }
}

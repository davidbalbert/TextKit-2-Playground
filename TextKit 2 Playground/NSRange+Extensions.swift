//
//  NSRange+Extensions.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 6/12/22.
//

import Cocoa

extension NSRange {
    init(_ textRange: NSTextRange, in textContentManager: NSTextContentManager) {
        let location = textContentManager.offset(from: textContentManager.documentRange.location, to: textRange.location)
        let length = textContentManager.offset(from: textRange.location, to: textRange.endLocation)

        self.init(location: location, length: length)
    }
}

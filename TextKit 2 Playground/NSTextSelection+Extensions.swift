//
//  NSTextSelection+Extensions.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 7/4/22.
//

import Cocoa

extension NSTextSelection {
    @objc var isMarked: Bool {
        false
    }

    @objc var unmarked: NSTextSelection {
        self
    }

    @objc var markedTextRange: NSTextRange? {
        nil
    }

    @objc var replacementRange: NSTextRange? {
        textRanges.first
    }

    func mark(_ markedRange: NSTextRange) -> MarkedTextSelection {
        MarkedTextSelection(textRanges, affinity: affinity, granularity: granularity, markedRange: markedRange)
    }

    func contiguousTextSelection(offsetBy offset: Int, length: Int, in textElementProvider: NSTextElementProvider) -> NSTextSelection? {
        guard let firstTextRange = textRanges.first else {
            return nil
        }

        guard let location = textElementProvider.location?(firstTextRange.location, offsetBy: offset),
              let end = textElementProvider.location?(location, offsetBy: length),
              let textRange = NSTextRange(location: location, end: end) else {
            return nil
        }

        return textSelection([textRange])
    }
}

//
//  NSTextSelection+Marking.swift
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

    func mark(_ length: Int, selectedRange: NSRange, in textElementProvider: NSTextElementProvider) -> MarkedTextSelection? {
        guard let textRange = textRanges.first else {
            return nil
        }

        let location = textRange.location

        guard let end = textElementProvider.location?(location, offsetBy: length) else {
            return nil
        }

        guard let markedRange = NSTextRange(location: location, end: end) else {
            return nil
        }

        return MarkedTextSelection(textRanges, affinity: affinity, granularity: granularity, markedRange: markedRange)
    }

    @objc func withTextRanges(_ textRanges: [NSTextRange]) -> NSTextSelection {
        return NSTextSelection(textRanges, affinity: affinity, granularity: granularity)
    }
}

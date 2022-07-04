//
//  NSTextRange+Extensions.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 6/26/22.
//

import Cocoa

extension NSTextRange {
    convenience init?(_ nsRange: NSRange, in textElementProvider: NSTextElementProvider) {
        guard let location = textElementProvider.location?(textElementProvider.documentRange.location, offsetBy: nsRange.location) else {
            return nil
        }

        guard let endLocation = textElementProvider.location?(location, offsetBy: nsRange.length) else {
            return nil
        }

        self.init(location: location, end: endLocation)
    }
}

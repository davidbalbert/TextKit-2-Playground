//
//  NSRange+Extensions.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 6/12/22.
//

import Cocoa

extension NSRange {
    static var notFound = NSRange(location: NSNotFound, length: 0)

    init(_ textRange: NSTextRange?, in textElementProvider: NSTextElementProvider) {
        guard let textRange = textRange else {
            self.init(location: NSNotFound, length: 0)
            return
        }

        let location = textElementProvider.offset?(from: textElementProvider.documentRange.location, to: textRange.location)
        let length = textElementProvider.offset?(from: textRange.location, to: textRange.endLocation)

        if let location = location, let length = length {
            self.init(location: location, length: length)
        } else {
            self.init(location: NSNotFound, length: 0)
        }
    }

    func offset(by offset: Int) -> NSRange? {
        if location == NSNotFound {
            return nil
        }

        let newLocation = location + offset

        if newLocation < 0 {
            return nil
        }

        return NSRange(location: newLocation, length: length)
    }
}

//
//  NSViewInvalidating+Extensions.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 6/30/22.
//

import Cocoa

enum CustomInvalidations {
    struct TextDisplay: NSViewInvalidating {
        func invalidate(view: NSView) {
            (view as? TextView)?.setTextNeedsDisplay()
        }
    }

    struct InsertionPointDisplay: NSViewInvalidating {
        func invalidate(view: NSView) {
            (view as? TextView)?.setInsertionPointNeedsDisplay()
        }
    }
}

extension NSViewInvalidating where Self == CustomInvalidations.TextDisplay {
    static var textDisplay: CustomInvalidations.TextDisplay { CustomInvalidations.TextDisplay() }
}

extension NSViewInvalidating where Self == CustomInvalidations.InsertionPointDisplay {
    static var insertionPointDisplay: CustomInvalidations.InsertionPointDisplay { CustomInvalidations.InsertionPointDisplay() }
}

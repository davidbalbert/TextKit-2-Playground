//
//  NSTextLayoutManager+Extensions.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 7/17/22.
//

import Cocoa

extension NSTextLayoutManager {
    // Takes a point in textContainer coordinate space and returns the character index in the backing store.
    func characterIndex(for point: CGPoint) -> Int {
        // TODO: textLayoutFragment(for: point) seems to return nil when you click on trailing whitespace. Confirm this is true, file a bug and find a workaround.
        guard let textLayoutFragment = textLayoutFragment(for: point) else {
            return NSNotFound
        }

        let layoutFragmentPoint = textLayoutFragment.convertToLayoutFragment(point)
        guard let textLineFragment = textLayoutFragment.textLineFragments.first(where: { $0.typographicBounds.contains(layoutFragmentPoint) }) else {
            return NSNotFound
        }

        let lineFragmentPoint = textLineFragment.convertToLineFragment(point)
        let lineFragmentLocation = textLineFragment.characterIndex(for: lineFragmentPoint)

        let layoutFragmentLocation = offset(from: documentRange.location, to: textLayoutFragment.rangeInElement.location)
        if layoutFragmentLocation == NSNotFound {
            return NSNotFound
        }

        return layoutFragmentLocation + textLineFragment.characterRange.location + lineFragmentLocation
    }
}

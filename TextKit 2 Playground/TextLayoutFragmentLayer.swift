//
//  TextFragmentLayer.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 6/18/22.
//

import Cocoa

class TextLayoutFragmentLayer: NonAnimatingLayer {
    var textLayoutFragment: NSTextLayoutFragment

    init(textLayoutFragment: NSTextLayoutFragment) {
        self.textLayoutFragment = textLayoutFragment
        super.init()
        needsDisplayOnBoundsChange = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(layer: Any) {
        self.textLayoutFragment = (layer as! Self).textLayoutFragment
        super.init(layer: layer)
        needsDisplayOnBoundsChange = true
    }

    func updateGeometry() {
        // The textLayoutFragment has a bounds and a frame, like a view, but the bounds and the
        // frame are different sizes. The layoutFragmentFrame is generally smaller and inset within
        // the renderingSurfaceBounds, but not always (blank lines have bounds that are smaller
        // than the frames).
        //
        // We want our layer's size to be set by the renderingSurfaceBounds (the actual area that
        // the layout fragment needs to draw into), and we need to set our position by the layout
        // fragment frame.
        //
        // The bounds origin seems to never be at zero, which means (conceptually) that the
        // layoutFragmentFrame is translated within the bounds. In order to use the frame's
        // origin as our position, we set our layer's anchor to be the the frame's origin
        // in the (slightly translated) coordinate space of the frame.

        bounds = textLayoutFragment.renderingSurfaceBounds
        anchorPoint = CGPoint(x: -bounds.origin.x/bounds.width, y: -bounds.origin.y/bounds.height)
        position = textLayoutFragment.layoutFragmentFrame.origin
    }

    override func draw(in ctx: CGContext) {
        textLayoutFragment.draw(at: .zero, in: ctx)
    }
}

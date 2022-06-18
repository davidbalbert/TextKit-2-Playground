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
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(layer: Any) {
        self.textLayoutFragment = (layer as! Self).textLayoutFragment
        super.init(layer: layer)
    }

    func updateGeometry() {
        let oldFrame = frame

        bounds = textLayoutFragment.renderingSurfaceBounds
        anchorPoint = CGPoint(x: -bounds.origin.x/bounds.width, y: -bounds.origin.y/bounds.height)
        position = textLayoutFragment.layoutFragmentFrame.origin

        if frame != oldFrame {
            setNeedsDisplay()
        }
    }

    override func draw(in ctx: CGContext) {
        textLayoutFragment.draw(at: .zero, in: ctx)
    }
}

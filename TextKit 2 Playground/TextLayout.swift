//
//  TextLayout.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 6/20/22.
//

import Cocoa

class TextLayout: NSObject, CALayoutManager, CALayerDelegate {
    weak var textView: TextView?
    var fragmentLayerMap: NSMapTable<NSTextLayoutFragment, CALayer> = .weakToWeakObjects()

    var layerBeingLayedOut: CALayer?

    init(textView: TextView) {
        self.textView = textView
        super.init()
    }

    func layoutSublayers(of layer: CALayer) {
        guard isEqual(to: layer.layoutManager) else { return }

        guard let textView = textView else { return }

        layerBeingLayedOut = layer
        textView.layoutViewport()
        layerBeingLayedOut = nil
    }

    func textView(_ textView: TextView, textViewportLayoutControllerWillLayout textViewportLayoutController: NSTextViewportLayoutController) {
        layerBeingLayedOut?.sublayers = nil
    }

    func textView(_ textView: TextView, textViewportLayoutController: NSTextViewportLayoutController, configureRenderingSurfaceFor textLayoutFragment: NSTextLayoutFragment) {
        guard let layerBeingLayedOut = layerBeingLayedOut else {
            return
        }

        let layer = fragmentLayerMap.object(forKey: textLayoutFragment) ?? makeLayer(for: textLayoutFragment, contentsScale: textView.window?.backingScaleFactor ?? 1.0)

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

        let bounds = textLayoutFragment.renderingSurfaceBounds
        layer.anchorPoint = CGPoint(x: -bounds.origin.x/bounds.width, y: -bounds.origin.y/bounds.height)
        layer.bounds = bounds
        layer.position = textLayoutFragment.layoutFragmentFrame.origin

        fragmentLayerMap.setObject(layer, forKey: textLayoutFragment)
        layerBeingLayedOut.addSublayer(layer)
    }

    func draw(_ layer: CALayer, in ctx: CGContext) {
        guard let textLayoutFragment = layer.value(forKey: "textLayoutFragment") as? NSTextLayoutFragment else {
            return
        }

        textLayoutFragment.draw(at: .zero, in: ctx)
    }

    func makeLayer(for textLayoutFragment: NSTextLayoutFragment, contentsScale: CGFloat) -> CALayer {
        let layer = NonAnimatingLayer()
        layer.needsDisplayOnBoundsChange = true
        layer.setValue(textLayoutFragment, forKey: "textLayoutFragment")
        layer.contentsScale = contentsScale

        layer.delegate = self

        return layer
    }
}

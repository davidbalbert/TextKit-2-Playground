//
//  TextLayout.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 6/20/22.
//

import Cocoa

class TextLayout: NSObject, CALayoutManager, CALayerDelegate, NSViewLayerContentScaleDelegate {
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

        let layer = fragmentLayerMap.object(forKey: textLayoutFragment) ?? makeLayer(for: textLayoutFragment)

        // The layoutFragmentFrame is the rectangle surrounding the text (including whitespace, but
        // excluding some bits of the text like italicized descenders). It's in the text container's
        // coordinate system. Each layout fragment directly abuts its siblings.
        //
        // The renderingSurfaceBounds is the actual size of the layer we need to draw the text in. It
        // includes the italicized descenders, but it doesn't include trailing whitespace because we
        // don't actually need to draw that. Most of the time, it's larger than the layoutFragmentFrame,
        // but sometimes it can be smaller (if the layout fragment has trailing whitespace), or even
        // a size of zero (if the layout fragment is entirely whitespace). It's in the layout fragment's
        // own coordinate space, and as long as the layout fragment contains some non-whitespace glyphs,
        // it's origin will be negative. In other words, the layout fragment can extend outside the
        // text container.
        //
        // We size each layer based on the renderingSurfaceBounds (see caveat), but position them using
        // the layoutFragmentFrame's origin. To do this, we ensure the layer's anchorPoint is set to
        // (0, 0) in the coordinate system of the layer's bounds. Because the bounds often has a negative
        // origin, the anchorPoint is usually inset from the bounds origin.
        //
        // Caveat: layout fragments that contain only whitespace have a zero sized renderingSurfaceBounds.
        // Using this value alone yields an anchorPoint of (-inf, -inf), which is confusing for debugging.
        // Additionally, when debugLayout is set, we need a layer big enough to draw the layoutFragmentFrame.
        // For this reason, we set the bounds of the layer to be the union of the renderingSurfaceBounds and
        // the typographicBounds, which is just the layoutFragmentFrame with its origin set to zero.

        let renderingSurfaceBounds = textLayoutFragment.renderingSurfaceBounds
        let typographicBounds = textLayoutFragment.typographicBounds
        let bounds = renderingSurfaceBounds.union(typographicBounds)

        layer.anchorPoint = CGPoint(x: -bounds.origin.x/bounds.width, y: -bounds.origin.y/bounds.height)
        layer.bounds = bounds
        layer.position = textLayoutFragment.layoutFragmentFrame.origin

        fragmentLayerMap.setObject(layer, forKey: textLayoutFragment)
        layerBeingLayedOut.addSublayer(layer)
    }

    func makeLayer(for textLayoutFragment: NSTextLayoutFragment) -> CALayer {
        let layer = NonAnimatingLayer()
        layer.needsDisplayOnBoundsChange = true
        layer.setValue(textLayoutFragment, forKey: "textLayoutFragment")
        layer.contentsScale = textView?.window?.backingScaleFactor ?? 1.0

        layer.delegate = self

        return layer
    }

    func draw(_ layer: CALayer, in ctx: CGContext) {
        guard let textView = textView, let textLayoutFragment = layer.value(forKey: "textLayoutFragment") as? NSTextLayoutFragment else {
            return
        }

        textView.effectiveAppearance.performAsCurrentDrawingAppearance {
            textLayoutFragment.draw(at: .zero, in: ctx)

            if textView.debugLayout {
                ctx.saveGState()
                ctx.setStrokeColor(NSColor.systemPurple.cgColor)
                ctx.stroke(textLayoutFragment.typographicBounds.insetBy(dx: 0.5, dy: 0.5), width: 1)

                ctx.setStrokeColor(NSColor.systemOrange.cgColor)
                ctx.stroke(textLayoutFragment.renderingSurfaceBounds.insetBy(dx: 0.5, dy: 0.5), width: 1)

                ctx.setFillColor(NSColor.blue.cgColor)
                ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
                ctx.restoreGState()
            }
        }
    }

    func layer(_ layer: CALayer, shouldInheritContentsScale newScale: CGFloat, from window: NSWindow) -> Bool {
        true
    }
}

//
//  TextView+Drawing.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 7/4/22.
//

import Cocoa

extension TextView: NSTextViewportLayoutControllerDelegate {
    override func layout() {
        super.layout()

        guard let layer = layer else { return }

        if textBackgroundLayer.superlayer == nil {
            textBackgroundLayer.anchorPoint = .zero
            textBackgroundLayer.bounds = layer.bounds
            textBackgroundLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            textBackgroundLayer.name = "Text backgrounds"
            layer.addSublayer(textBackgroundLayer)
        }

        if selectionLayer.superlayer == nil {
            selectionLayer.layoutManager = selectionLayout

            selectionLayer.anchorPoint = .zero
            selectionLayer.bounds = layer.bounds
            selectionLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            selectionLayer.name = "Selections"
            layer.addSublayer(selectionLayer)
        }

        if textLayer.superlayer == nil {
            textLayer.layoutManager = textLayout

            textLayer.anchorPoint = .zero
            textLayer.bounds = layer.bounds
            textLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            textLayer.name = "Text"
            layer.addSublayer(textLayer)
        }

        if insertionPointLayer.superlayer == nil {
            insertionPointLayer.layoutManager = insertionPointLayout

            insertionPointLayer.anchorPoint = .zero
            insertionPointLayer.bounds = layer.bounds
            insertionPointLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            insertionPointLayer.name = "Insertion points"
            layer.addSublayer(insertionPointLayer)
        }

        // We don't set needsLayout manually. This means layout is called in two
        // situations that I know of. The first is when the TextView is resized.
        // In this situation, we don't need to call setNeedsLayout on the following
        // layers, because each layer gets resized due to its autoresizing mask,
        // and layout is triggered automatically.
        //
        // The second situation layout is called is more interesting. I figured this
        // out by doing some disassembly.
        //
        // At the end of performEditingTransaction, if automaticallySynchronizesTextLayoutManagers
        // is true (which it is by default), something like the following call tree occurs:

        // -[NSTextContentManager synchronizeTextLayoutManagers:]                          (public)
        // -[NSTextLayoutManager processLayoutInvalidationForTextRange:synchronizing:]     (undocumented)
        // -[NSTextViewportLayoutController setNeedsLayout]                                (undocumented)
        // -[TextView setNeedsLayout]
        //
        // This behavior is undocumented, but it makes sense. If someone edits the text of our backing store,
        // we expect that our text view would be notified that it needs to do text layout again.
        //
        // One caveat:
        // The docs say this syncronizes the non-primary textLayoutManagers. I'm not sure if the primary
        // one gets syncronized at some other point. Regardless, let's assume it does get synchronized.
        //
        // To look into at some point: the docs for NSTextContentManager.performEditingTransaction say:
        //    Invoked by primaryTextLayoutManager controlling the active editing transaction
        //
        // That's curious. I wonder when this happens. NSTextContentManager has two definitions of
        // replaceContents(in:with:), where with can be an NSAttributedString or an [NSTextElement].
        // I wonder if you're supposed to pass run edits through the textLayoutManager?
        //
        // Regardless, we have these calls to setNeedsLayout here because layout() gets called on the
        // next tick after performEditingTransaction.
        textLayer.setNeedsLayout()
        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
    }

    override func updateLayer() {
        layer?.backgroundColor = backgroundColor.cgColor
    }

    func layoutViewport() {
        textViewportLayoutController.layoutViewport()
    }

    func setSelectionNeedsDisplay() {
        guard let sublayers = selectionLayer.sublayers else { return }

        for layer in sublayers {
            layer.setNeedsDisplay()
        }
    }

    func setTextNeedsDisplay() {
        guard let sublayers = textLayer.sublayers else { return }

        for layer in sublayers {
            layer.setNeedsDisplay()
        }
    }

    func setInsertionPointNeedsDisplay() {
        guard let sublayers = insertionPointLayer.sublayers else { return }

        for layer in sublayers {
            layer.setNeedsDisplay()
        }
    }

    // MARK: - NSTextViewportLayoutControllerDelegate

    func viewportBounds(for textViewportLayoutController: NSTextViewportLayoutController) -> CGRect {
        var viewportBounds: CGRect
        if preparedContentRect.intersects(visibleRect) {
            viewportBounds = preparedContentRect.union(visibleRect)
        } else {
            viewportBounds = visibleRect
        }

        viewportBounds.size.width = bounds.width

        assert(viewportBounds.minY >= 0)

        return viewportBounds
    }

    func textViewportLayoutControllerWillLayout(_ textViewportLayoutController: NSTextViewportLayoutController) {
        textBackgroundLayout.textView(self, textViewportLayoutControllerWillLayout: textViewportLayoutController)
        textLayout.textView(self, textViewportLayoutControllerWillLayout: textViewportLayoutController)
    }

    func textViewportLayoutController(_ textViewportLayoutController: NSTextViewportLayoutController, configureRenderingSurfaceFor textLayoutFragment: NSTextLayoutFragment) {
        textBackgroundLayout.textView(self, textViewportLayoutController: textViewportLayoutController, configureRenderingSurfaceFor: textLayoutFragment)
        textLayout.textView(self, textViewportLayoutController: textViewportLayoutController, configureRenderingSurfaceFor: textLayoutFragment)
    }

    func textViewportLayoutControllerDidLayout(_ textViewportLayoutController: NSTextViewportLayoutController) {
        updateFrameHeightIfNeeded()
    }
}

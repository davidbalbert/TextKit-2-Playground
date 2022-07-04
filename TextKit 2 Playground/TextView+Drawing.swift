//
//  TextView+Drawing.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 7/4/22.
//

import Cocoa

extension TextView: NSTextContentStorageDelegate, NSTextViewportLayoutControllerDelegate {
    override func layout() {
        super.layout()

        guard let layer = layer else { return }

        if textBackgroundLayer.superlayer == nil {
            textBackgroundLayer.anchorPoint = .zero
            textBackgroundLayer.name = "Text backgrounds"
            layer.addSublayer(textBackgroundLayer)
        }

        if selectionLayer.superlayer == nil {
            selectionLayer.layoutManager = selectionLayout

            selectionLayer.anchorPoint = .zero
            selectionLayer.name = "Selections"
            layer.addSublayer(selectionLayer)
        }

        if textLayer.superlayer == nil {
            textLayer.layoutManager = textLayout

            textLayer.anchorPoint = .zero
            textLayer.name = "Text"
            layer.addSublayer(textLayer)
        }

        if insertionPointLayer.superlayer == nil {
            insertionPointLayer.layoutManager = insertionPointLayout

            insertionPointLayer.anchorPoint = .zero
            insertionPointLayer.name = "Insertion points"
            layer.addSublayer(insertionPointLayer)
        }

        // TODO: I think we should be able to do this with an autoresize mask.
        selectionLayer.bounds = layer.bounds
        textLayer.bounds = layer.bounds
        insertionPointLayer.bounds = layer.bounds
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

//
//  TextView.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 5/11/22.
//

import Cocoa

class TextView: NSView, NSTextViewportLayoutControllerDelegate {
//    func scrollableTextKit2TextView() -> NSScrollView {
//        let textContainer = NSTextContainer(size: .zero)
//        textContainer.widthTracksTextView = true
//
//        let textLayoutManager = NSTextLayoutManager()
//        textLayoutManager.textContainer = textContainer
//
//        let textContentStorage = NSTextContentStorage()
//        textContentStorage.addTextLayoutManager(textLayoutManager)
//        textContentStorage.primaryTextLayoutManager = textLayoutManager
//
//        let textView = NSTextView(frame: .zero, textContainer: textContainer)
//
//        let scrollView = NSScrollView()
//        scrollView.hasVerticalScroller = true
//        scrollView.drawsBackground = false
//        scrollView.documentView = textView
//
//        textView.isRichText = false
//        textView.usesRuler = false
//        textView.isVerticallyResizable = true
//        textView.autoresizingMask = [.width, .height]
//
//        return scrollView
//    }


    class func scrollableTextView() -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true

        let textView = Self()
        textView.autoresizingMask = [.width, .height]

        scrollView.documentView = textView

        return scrollView
    }

    @Invalidating(.layout, .display) var textContentStorage: NSTextContentStorage? = nil
    @Invalidating(.layout, .display) var textLayoutManager: NSTextLayoutManager? = nil {
        willSet {
            textLayoutManager?.textViewportLayoutController.delegate = nil
        }
        didSet {
            textLayoutManager?.textViewportLayoutController.delegate = self
            // The LayoutWithTextKit2 sample also calls updateFrameHeightIfNeeded(). I don't think we need
            // to do that here. Setting textLayoutManager invalidates layout. Layout() calls
            // viewportLayoutController.layoutViewport(), which eventually calls updateFrameHeightIfNeeded().
            updateTextContainerSize()
        }
    }

    private var textViewportLayoutController: NSTextViewportLayoutController? {
        textLayoutManager?.textViewportLayoutController
    }

    var textContainer: NSTextContainer? {
        get {
            textLayoutManager?.textContainer
        }
        set {
            // TODO: do we have to do something smarter here (like take other TextKit objects from the textContainer)
            textLayoutManager?.textContainer = newValue
        }
    }

    var textStorage: NSTextStorage? {
        get {
            textContentStorage?.textStorage
        }
        set {
            // TODO: do we have to do something smarter here (like take other TextKit objects from the textStorage)
            textContentStorage?.textStorage = newValue
        }
    }

    var string: String {
        get {
            textContentStorage?.textStorage?.string ?? ""
        }
        set {
            if let textStorage = textContentStorage?.textStorage {
                textStorage.mutableString.setString(newValue)
            } else {
                textContentStorage?.textStorage = NSTextStorage(string: newValue)
            }
        }
    }

    override var isFlipped: Bool {
        true
    }

    private var layoutFragments: [NSTextLayoutFragment] = []

    convenience override init(frame frameRect: NSRect) {
        let textContainer = NSTextContainer()
        textContainer.widthTracksTextView = true // TODO: we don't actually consult this yet

        let textLayoutManager = NSTextLayoutManager()
        textLayoutManager.textContainer = textContainer

        let textContentStorage = NSTextContentStorage()
        textContentStorage.addTextLayoutManager(textLayoutManager)
        textContentStorage.primaryTextLayoutManager = textLayoutManager

        self.init(frame: frameRect, textContainer: textContainer)
    }

    init(frame frameRect: NSRect, textContainer: NSTextContainer?) {
        textLayoutManager = textContainer?.textLayoutManager
        textContentStorage = textContainer?.textLayoutManager?.textContentManager as? NSTextContentStorage
        super.init(frame: frameRect)

        textViewportLayoutController?.delegate = self
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func layout() {
        super.layout()
        textViewportLayoutController?.layoutViewport()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.textBackgroundColor.set()
        dirtyRect.fill()

        for fragment in layoutFragments {
            fragment.draw(at: fragment.layoutFragmentFrame.origin, in: NSGraphicsContext.current!.cgContext)
        }
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateTextContainerSize()
    }

    private func updateTextContainerSize() {
        if (textContainer?.size.width != bounds.width) {
            textContainer?.size = CGSize(width: frame.width, height: 0)
        }
    }

    private func updateFrameHeightIfNeeded() {
        guard let scrollView = enclosingScrollView else {
            return
        }

        let contentHeight = finalLayoutFragment?.layoutFragmentFrame.maxY ?? 0
        let viewportHeight = scrollView.contentSize.height
        let newHeight = max(contentHeight, viewportHeight)

        let currentHeight = frame.height

        if abs(currentHeight - newHeight) > 1e-10 {
            setFrameSize(NSSize(width: frame.width, height: newHeight))
        }
    }

    private var finalLayoutFragment: NSTextLayoutFragment? {
        guard let textLayoutManager = textLayoutManager else {
            return nil
        }

        var layoutFragment: NSTextLayoutFragment? = nil

        textLayoutManager.enumerateTextLayoutFragments(from: textLayoutManager.documentRange.endLocation, options: [.ensuresLayout, .reverse]) { fragment in
            layoutFragment = fragment
            return false
        }

        return layoutFragment
    }

    override func viewWillMove(toSuperview newSuperview: NSView?) {
        if let clipView = enclosingScrollView?.contentView {
            NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: clipView)
        }
    }

    override func viewDidMoveToSuperview() {
        if let clipView = enclosingScrollView?.contentView {
            clipView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(self, selector: #selector(clipViewDidChangeBounds(_:)), name: NSView.boundsDidChangeNotification, object: clipView)
        }
    }

    @objc func clipViewDidChangeBounds(_ notification: Notification) {
        needsLayout = true
        needsDisplay = true
    }

    // MARK: - NSTextViewportLayoutControllerDelegate

    func viewportBounds(for textViewportLayoutController: NSTextViewportLayoutController) -> CGRect {
        // TODO: make this take into account responsive scrolling overdraw with preparedContectRect
        if let scrollView = enclosingScrollView {
            return scrollView.contentView.bounds
        } else {
            return bounds
        }
    }

    func textViewportLayoutControllerWillLayout(_ textViewportLayoutController: NSTextViewportLayoutController) {
        layoutFragments = []
    }

    func textViewportLayoutController(_ textViewportLayoutController: NSTextViewportLayoutController, configureRenderingSurfaceFor textLayoutFragment: NSTextLayoutFragment) {
        layoutFragments.append(textLayoutFragment)
    }

    func textViewportLayoutControllerDidLayout(_ textViewportLayoutController: NSTextViewportLayoutController) {
        updateFrameHeightIfNeeded()
    }
}

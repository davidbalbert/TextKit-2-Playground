//
//  TextView.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 5/11/22.
//

import Cocoa

class TextView: NSView, NSTextViewportLayoutControllerDelegate {
    class func scrollableTextView() -> NSScrollView {
        let textView = Self()

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        // TODO: when we're drawing paragraphs into CALayers, we can disable drawsBackground. Our root layer will never move, and will draw its background.
        // scrollView.drawsBackground = false
        scrollView.documentView = textView

        textView.autoresizingMask = [.width, .height]

        return scrollView
    }

    @Invalidating(.display) var textContentStorage: NSTextContentStorage? = nil
    @Invalidating(.display) var textLayoutManager: NSTextLayoutManager? = nil {
        willSet {
            textLayoutManager?.textViewportLayoutController.delegate = nil
        }
        didSet {
            textLayoutManager?.textViewportLayoutController.delegate = self
            // The LayoutWithTextKit2 sample also calls updateFrameHeightIfNeeded(). I don't think we need
            // to do that here. Setting textLayoutManager invalidates display. draw(_:) calls
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

    override var isOpaque: Bool {
        true
    }

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

        let trackingArea = NSTrackingArea(rect: .zero, options: [.inVisibleRect, .cursorUpdate, .activeInKeyWindow], owner: self)
        addTrackingArea(trackingArea)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // Pretty sure this is unnecessary, but the LayoutWithTextKit2 sets it, so
    // we might as well. One thing that's odd: no matter what I do, I haven't
    // seen the scroll view ask me for overdraw without scrolling
    override class var isCompatibleWithResponsiveScrolling: Bool {
        true
    }

    private var viewportRect: CGRect = .zero
    private var layoutFragments: [NSTextLayoutFragment] = []

    override func draw(_ dirtyRect: NSRect) {
        NSColor.textBackgroundColor.set()
        dirtyRect.fill()

        viewportRect = dirtyRect
        textViewportLayoutController?.layoutViewport()

        drawSelections(in: dirtyRect)

        for fragment in layoutFragments {
            fragment.draw(at: fragment.layoutFragmentFrame.origin, in: NSGraphicsContext.current!.cgContext)
        }
    }

    func drawSelections(in dirtyRect: NSRect) {
        guard let textLayoutManager = textLayoutManager else {
            return
        }

        if windowIsKey && isFirstResponder {
            NSColor.selectedTextBackgroundColor.set()
        } else {
            NSColor.unemphasizedSelectedTextBackgroundColor.set()
        }

        for textSelection in textLayoutManager.textSelections {
            for textRange in textSelection.textRanges {
                textLayoutManager.enumerateTextSegments(in: textRange, type: .selection) { segmentRange, segmentFrame, baselinePosition, textContainer in
                    if segmentFrame.intersects(dirtyRect) {
                        segmentFrame.fill()
                    }

                    return true
                }
            }
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
        let newHeight = round(max(contentHeight, viewportHeight))

        let currentHeight = frame.height

        if abs(currentHeight - newHeight) > 1e-10 {
            setFrameSize(NSSize(width: frame.width, height: newHeight))
        }
    }

    private var previousFinalLayoutFragment: NSTextLayoutFragment?

    private var finalLayoutFragment: NSTextLayoutFragment? {
        guard let textLayoutManager = textLayoutManager else {
            return nil
        }

        // finalLayoutFragment is read after we finish laying out the text, but before we draw. If the viewport contains
        // the finalLayoutFragment, we don't want to invalidate it, because then we wouldn't draw it.
        if let previousFinalLayoutFragment = previousFinalLayoutFragment, !layoutFragments.contains(previousFinalLayoutFragment) {
            textLayoutManager.invalidateLayout(for: previousFinalLayoutFragment.rangeInElement)
        }

        var layoutFragment: NSTextLayoutFragment? = nil

        textLayoutManager.enumerateTextLayoutFragments(from: textLayoutManager.documentRange.endLocation, options: [.ensuresLayout, .reverse]) { fragment in
            layoutFragment = fragment
            return false
        }

        previousFinalLayoutFragment = layoutFragment

        return layoutFragment
    }

    // MARK: - NSTextViewportLayoutControllerDelegate

    func viewportBounds(for textViewportLayoutController: NSTextViewportLayoutController) -> CGRect {
        // TODO: make this take into account responsive scrolling overdraw with preparedContectRect
        return viewportRect
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

    // MARK: - Selection

    override func mouseDown(with event: NSEvent) {
        guard let textLayoutManager = textLayoutManager else { return }
        let point = convert(event.locationInWindow, from: nil)

        if event.modifierFlags.contains(.shift) && !textLayoutManager.textSelections.isEmpty {
            extendSelection(to: point)
        } else {
            startSelection(at: point)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        extendSelection(to: point)
    }

    override func mouseUp(with event: NSEvent) {
        guard let textLayoutManager = textLayoutManager else { return }

        // TODO: once we have editing, we should only do this if we're editable
        // If we're not editable, we're only drawing selections, not insertion points,
        // so we want to exclude any empty selections. If we didn't do this, if you shift-click
        // with no existing (visible) selection, you'd get a new selection, which is confusing.
        textLayoutManager.textSelections.removeAll { textSelection in
            textSelection.textRanges.allSatisfy { $0.isEmpty }
        }
    }

    func startSelection(at point: CGPoint) {
        guard let textLayoutManager = textLayoutManager else { return }
        let navigation = textLayoutManager.textSelectionNavigation

        textLayoutManager.textSelections = navigation.textSelections(interactingAt: point,
                                                                     inContainerAt: textLayoutManager.documentRange.location,
                                                                     anchors: [],
                                                                     modifiers: [],
                                                                     selecting: false,
                                                                     bounds: .zero)

        // TODO: can we only ask for redisplay of the layout fragments rects that overlap with the selection?
        needsDisplay = true
    }

    func extendSelection(to point: CGPoint) {
        guard let textLayoutManager = textLayoutManager else { return }
        let navigation = textLayoutManager.textSelectionNavigation

        textLayoutManager.textSelections = navigation.textSelections(interactingAt: point,
                                                                     inContainerAt: textLayoutManager.documentRange.location,
                                                                     anchors: textLayoutManager.textSelections,
                                                                     modifiers: .extend,
                                                                     selecting: false,
                                                                     bounds: .zero)
        // TODO: can we only ask for redisplay of the layout fragments rects that overlap with the selection?
        needsDisplay = true
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.iBeam.set()
    }

    // MARK: - First responder

    override var acceptsFirstResponder: Bool {
        true
    }

    private var isFirstResponder: Bool {
        window?.firstResponder == self
    }

    private var windowIsKey: Bool {
        window?.isKeyWindow ?? false
    }

    override func becomeFirstResponder() -> Bool {
        needsDisplay = true
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        needsDisplay = true
        return super.resignFirstResponder()
    }

    private var didBecomeKeyObserver: Any?
    private var didResignKeyObserver: Any?

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if let didBecomeKeyObserver = didBecomeKeyObserver {
            NotificationCenter.default.removeObserver(didBecomeKeyObserver)
        }

        if let didResignKeyObserver = didResignKeyObserver {
            NotificationCenter.default.removeObserver(didResignKeyObserver)
        }
    }

    override func viewDidMoveToWindow() {
        guard let window = window else { return }

        didBecomeKeyObserver = NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: nil) { [weak self] notification in
            self?.needsDisplay = true
        }

        didResignKeyObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: nil) { [weak self] notification in
            self?.needsDisplay = true
        }
    }
}

//
//  TextView.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 5/11/22.
//

import Cocoa

extension NSRange {
    init?(_ textRange: NSTextRange, in provider: NSTextElementProvider) {
        guard let location = provider.offset?(from: provider.documentRange.location, to: textRange.location) else {
            return nil
        }

        guard let length = provider.offset?(from: textRange.location, to: textRange.endLocation) else {
            return nil
        }

        self.init(location: location, length: length)
    }
}

class TextView: NSView, NSTextViewportLayoutControllerDelegate, NSMenuItemValidation {
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

    @Invalidating(.display) public var isSelectable: Bool = true {
        didSet {
            if !isSelectable {
                isEditable = false
                textLayoutManager?.textSelections = []
            }
        }
    }

    @Invalidating(.display) public var isEditable: Bool = true {
        didSet {
            if isEditable {
                isSelectable = true
            }

            updateInsertionPointTimer()
        }
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

        drawInsertionPoints(in: dirtyRect)
    }

    func drawSelections(in dirtyRect: NSRect) {
        guard let textLayoutManager = textLayoutManager, let viewportRange = textViewportLayoutController?.viewportRange else {
            return
        }

        if windowIsKey && isFirstResponder {
            NSColor.selectedTextBackgroundColor.set()
        } else {
            NSColor.unemphasizedSelectedTextBackgroundColor.set()
        }

        let textRanges = textLayoutManager.textSelections.flatMap(\.textRanges).filter { !$0.isEmpty }
        let rangesInViewport = textRanges.compactMap { $0.intersection(viewportRange) }

        for textRange in rangesInViewport {
            textLayoutManager.enumerateTextSegments(in: textRange, type: .selection, options: .rangeNotRequired) { segmentRange, segmentFrame, baselinePosition, textContainer in
                segmentFrame.fill()
                return true
            }
        }
    }

    @Invalidating(.display) private var shouldDrawInsertionPoints = true
    private var insertionPointTimer: Timer?

    // TODO: split into an onInterval and offInterval and read NSTextInsertionPointBlinkPeriodOn and NSTextInsertionPointBlinkPeriodOff from defaults
    private var insertionPointBlinkInterval: TimeInterval {
        0.5
    }

    var caretTextRanges: [NSTextRange] {
        guard let textLayoutManager = textLayoutManager else {
            return []
        }

        return textLayoutManager.textSelections.flatMap(\.textRanges).filter { $0.isEmpty }
    }

    var shouldBlinkInsertionPoint: Bool {
        isEditable && caretTextRanges.count > 0 && isFirstResponder && windowIsKey
    }

    // TODO: is there a way to run this directly after the current RunLoop tick in the same way that needsDisplay works?
    func updateInsertionPointTimer() {
        insertionPointTimer?.invalidate()

        if shouldBlinkInsertionPoint {
            shouldDrawInsertionPoints = true

            insertionPointTimer = Timer.scheduledTimer(withTimeInterval: insertionPointBlinkInterval, repeats: true) { [weak self] timer in
                guard let self = self else { return }
                self.shouldDrawInsertionPoints.toggle()
            }
        } else {
            shouldDrawInsertionPoints = false
        }
    }

    func drawInsertionPoints(in dirtyRect: NSRect) {
        guard shouldDrawInsertionPoints else { return }

        guard let textLayoutManager = textLayoutManager, let viewportRange = textViewportLayoutController?.viewportRange else {
            return
        }

        let rangesInViewport = caretTextRanges.compactMap { $0.intersection(viewportRange) }

        NSColor.black.set()

        for textRange in rangesInViewport {
            textLayoutManager.enumerateTextSegments(in: textRange, type: .selection, options: .rangeNotRequired) { segmentRange, segmentFrame, baselinePosition, textContainer in
                var caretFrame = segmentFrame
                caretFrame.size.width = 1
                caretFrame.fill()
                return true
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
        guard isSelectable else { return }

        guard let textLayoutManager = textLayoutManager else { return }
        let point = convert(event.locationInWindow, from: nil)

        if event.modifierFlags.contains(.shift) && !textLayoutManager.textSelections.isEmpty {
            extendSelection(to: point)
        } else {
            startSelection(at: point)
        }

        updateInsertionPointTimer()
    }

    override func mouseDragged(with event: NSEvent) {
        guard isSelectable else { return }

        let point = convert(event.locationInWindow, from: nil)
        extendSelection(to: point)

        updateInsertionPointTimer()
    }

    override func mouseUp(with event: NSEvent) {
        guard isSelectable else { return }

        // Zero length selections are insertion points. We only allow
        // insertion points if we're editable
        if !isEditable {
            removeZeroLengthSelections()
        }

        updateInsertionPointTimer()
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

    func removeZeroLengthSelections() {
        guard let textLayoutManager = textLayoutManager else { return }

        textLayoutManager.textSelections.removeAll { textSelection in
            textSelection.textRanges.allSatisfy { $0.isEmpty }
        }
    }

    override func cursorUpdate(with event: NSEvent) {
        if isSelectable {
            NSCursor.iBeam.set()
        }
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
        updateInsertionPointTimer()
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        needsDisplay = true
        updateInsertionPointTimer()
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
            self?.updateInsertionPointTimer()
        }

        didResignKeyObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: nil) { [weak self] notification in
            self?.needsDisplay = true
            self?.updateInsertionPointTimer()
        }
    }

    // MARK: - Pasteboard

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(selectAll(_:)):
            return isSelectable
        case #selector(copy(_:)):
            return hasSelectedText
        case #selector(cut(_:)), #selector(paste(_:)):
            return false
        default:
            return true
        }
    }

    class override var defaultMenu: NSMenu? {
        let menu = NSMenu()

        menu.addItem(withTitle: "Cut", action: #selector(cut(_ :)), keyEquivalent: "")
        menu.addItem(withTitle: "Copy", action: #selector(copy(_ :)), keyEquivalent: "")
        menu.addItem(withTitle: "Paste", action: #selector(paste(_ :)), keyEquivalent: "")

        return menu
    }

    private var hasSelectedText: Bool {
        guard let textLayoutManager = textLayoutManager else {
            return false
        }

        for textSelection in textLayoutManager.textSelections {
            for textRange in textSelection.textRanges {
                if !textRange.isEmpty {
                    return true
                }
            }
        }

        return false
    }

    @objc func cut(_ sender: Any) {
    }

    @objc func copy(_ sender: Any) {
        guard let textLayoutManager = textLayoutManager, let textContentStorage = textContentStorage, let textStorage = textStorage else {
            return
        }

        let textRanges = textLayoutManager.textSelections.flatMap { $0.textRanges }.filter { !$0.isEmpty }
        let nsRanges = textRanges.compactMap { NSRange($0, in: textContentStorage) }
        let attributedStrings = nsRanges.map { textStorage.attributedSubstring(from: $0) }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(attributedStrings)
    }

    @objc func paste(_ sender: Any) {
    }

    @objc override func selectAll(_ sender: Any?) {
        guard isSelectable else { return }

        guard let textLayoutManager = textLayoutManager else {
            return
        }

        textLayoutManager.textSelections = [NSTextSelection(range: textLayoutManager.documentRange, affinity: .downstream, granularity: .character)]
        
        needsDisplay = true
    }
}

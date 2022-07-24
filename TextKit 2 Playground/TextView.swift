//
//  TextView.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 5/11/22.
//

import Cocoa

class TextView: NSView, NSTextContentStorageDelegate {
    class func scrollableTextView() -> NSScrollView {
        let textView = Self()

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        // It would be nice to be able to set drawsBackground to false, but I need a way to
        // deal with background drawing during elastic scroll
        // scrollView.drawsBackground = false
        scrollView.documentView = textView

        textView.autoresizingMask = [.width, .height]

        return scrollView
    }

    override var isFlipped: Bool {
        true
    }

    override var isOpaque: Bool {
        true
    }

    var textLayoutManager = NSTextLayoutManager()
    var textStorage = NSTextStorage()
    var textContentStorage = NSTextContentStorage()
    var textContainer = NSTextContainer()

    var textViewportLayoutController: NSTextViewportLayoutController {
        textLayoutManager.textViewportLayoutController
    }

    var textBackgroundLayer: CALayer = NonAnimatingLayer()
    var selectionLayer: CALayer = NonAnimatingLayer()
    var textLayer: CALayer = NonAnimatingLayer()
    var insertionPointLayer: CALayer = NonAnimatingLayer()

    lazy var textBackgroundLayout = TextBackgroundLayout(textView: self, layer: textBackgroundLayer)
    lazy var selectionLayout = SelectionLayout(textView: self)
    lazy var textLayout = TextLayout(textView: self)
    lazy var insertionPointLayout = InsertionPointLayout(textView: self)

    // TODO: figure out how to use NSTextSelection.typingAttributes instead. Each selection should have its own typing attributes based on where it is in the document.
    var typingAttributes: [NSAttributedString.Key : Any] = [
        .foregroundColor: NSColor.black,
    ]

    var markedTextAttributes: [NSAttributedString.Key : Any] = [
        .backgroundColor: NSColor.systemYellow.withSystemEffect(.disabled),
    ]

    @Invalidating(.display) var backgroundColor: NSColor = .white {
        // TODO: Maybe enforce the invariant that no text has a background color that the document has. All that text should have a transparent background color.
        didSet {
            enclosingScrollView?.backgroundColor = backgroundColor
        }
    }

    @Invalidating(.insertionPointDisplay) var insertionPointColor: NSColor = .black

    @Invalidating(.textDisplay) var textColor: NSColor = .black {
        didSet {
            typingAttributes[.foregroundColor] = textColor

            setAttributesForDocumentRange([.foregroundColor: textColor])
        }
    }

    @Invalidating(.layout) public var isRichText: Bool = true {
        didSet {
            if isRichText {
                backgroundColor = .white
                textColor = .black
                insertionPointColor = .black
            } else {
                backgroundColor = .textBackgroundColor
                textColor = .textColor
                insertionPointColor = .textColor
                removeAttributeForDocumentRange(.backgroundColor)
            }
        }
    }

    @Invalidating(.textDisplay) public var debugLayout: Bool = false

    var string: String {
        get {
            textStorage.string
        }
        set {
            textStorage.setAttributedString(NSAttributedString(string: newValue, attributes: typingAttributes))
            createInsertionPointIfNecessary()
        }
    }

    public var isSelectable: Bool = true {
        didSet {
            if !isSelectable {
                isEditable = false
                textSelections = []
            }

            selectionLayer.setNeedsLayout()
        }
    }

    public var isEditable: Bool = true {
        didSet {
            if isEditable {
                isSelectable = true
            }

            createInsertionPointIfNecessary()
            updateInsertionPointTimer()
            insertionPointLayer.setNeedsLayout()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func commonInit() {
        textContentStorage.textStorage = textStorage
        textViewportLayoutController.delegate = self
        textContainer.size.width = bounds.width
        textContainer.size.height = 0

        textContentStorage.addTextLayoutManager(textLayoutManager)
        textContentStorage.primaryTextLayoutManager = textLayoutManager
        textContentStorage.delegate = self

        textLayoutManager.textContainer = textContainer

        let trackingArea = NSTrackingArea(rect: .zero, options: [.inVisibleRect, .cursorUpdate, .activeInKeyWindow], owner: self)
        addTrackingArea(trackingArea)

        createInsertionPointIfNecessary()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)

        if (textContainer.size.width != bounds.width) {
            textContainer.size = CGSize(width: frame.width, height: 0)
        }
    }

    // MARK: - Scrolling

    override class var isCompatibleWithResponsiveScrolling: Bool {
        true
    }

    override func prepareContent(in rect: NSRect) {
        textLayer.setNeedsLayout()
        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()

        super.prepareContent(in: rect)
    }

    func enumerateBackgroundColorFrames(in textLayoutFragment: NSTextLayoutFragment, using block: (CGRect, NSColor) -> Void) {
        guard let textParagraph = textLayoutFragment.textElement as? NSTextParagraph else {
            return
        }

        let attributedString = textParagraph.attributedString
        let stringRange = NSRange(location: 0, length: attributedString.length)

        attributedString.enumerateAttribute(.undrawnBackgroundColor, in: stringRange) { color, range, _ in
            guard let color = color as? NSColor else {
                return
            }

            let documentLocation = textContentStorage.documentRange.location
            let fragmentLocation = textLayoutFragment.rangeInElement.location
            let fragmentOffset = textContentStorage.offset(from: documentLocation, to: fragmentLocation)

            guard let rangeInDocument = range.offset(by: fragmentOffset) else { return }
            guard let textRange = NSTextRange(rangeInDocument, in: textContentStorage) else { return }

            textLayoutManager.enumerateTextSegments(in: textRange, type: .highlight, options: .rangeNotRequired) { _, frame, _, _ in
                block(frame.pixelAligned, color)
                return true
            }
        }
    }

    internal var insertionPointTimer: Timer?

    internal func updateFrameHeightIfNeeded() {
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

    private var finalLayoutFragment: NSTextLayoutFragment? {
        var layoutFragment: NSTextLayoutFragment? = nil

        textLayoutManager.enumerateTextLayoutFragments(from: textLayoutManager.documentRange.endLocation, options: [.ensuresLayout, .reverse]) { fragment in
            layoutFragment = fragment
            return false
        }

        return layoutFragment
    }

    // MARK: - NSTextContentStorageDelegate

    func textContentStorage(_ textContentStorage: NSTextContentStorage, textParagraphWith range: NSRange) -> NSTextParagraph? {
        let markedRanges = markedTextRanges.compactMap { NSRange($0, in: textContentStorage).intersection(range) }

        if markedRanges.isEmpty && !textStorage.containsAttribute(.backgroundColor, in: range) {
            return nil
        }

        let attributedString = NSMutableAttributedString(attributedString: textStorage.attributedSubstring(from: range))
        let normalizedMarkedRanges = markedRanges.compactMap { $0.offset(by: -range.location) }

        for markedRange in normalizedMarkedRanges {
            attributedString.setAttributes(markedTextAttributes, range: markedRange)
        }

        attributedString.replaceAttribute(NSAttributedString.Key.backgroundColor, with: .undrawnBackgroundColor)

        return NSTextParagraph(attributedString: attributedString)
    }

    // MARK: - View lifecycle callbacks

    private var didBecomeKeyObserver: Any?
    private var didResignKeyObserver: Any?

    override func viewDidMoveToWindow() {
        if let didBecomeKeyObserver = didBecomeKeyObserver {
            NotificationCenter.default.removeObserver(didBecomeKeyObserver)
        }

        if let didResignKeyObserver = didResignKeyObserver {
            NotificationCenter.default.removeObserver(didResignKeyObserver)
        }

        guard let window = window else { return }

        didBecomeKeyObserver = NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: nil) { [weak self] notification in
            self?.setSelectionNeedsDisplay()
            self?.updateInsertionPointTimer()
        }

        didResignKeyObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: nil) { [weak self] notification in
            self?.setSelectionNeedsDisplay()
            self?.updateInsertionPointTimer()
        }
    }

    override func viewDidMoveToSuperview() {
        updateInsertionPointTimer()
    }

    override func viewDidChangeEffectiveAppearance() {
        setSelectionNeedsDisplay()
        setTextNeedsDisplay()
        setInsertionPointNeedsDisplay()
    }

    // MARK: - Character manipulation (public methods)

    public func replaceCharacters(in textRange: NSTextRange, with string: String) {
        replaceCharacters(in: textRange, with: NSAttributedString(string: string))
    }

    public func replaceCharacters(in textRange: NSTextRange, with attributedString: NSAttributedString) {
        textContentStorage.performEditingTransaction {
            internalReplaceCharacters(in: textRange, with: attributedString)
        }

        updateInsertionPointTimer()

        unmarkText()
        inputContext?.invalidateCharacterCoordinates()
    }

    // MARK: - Character manipulation (internal methods)

    func internalReplaceCharacters(in textSelections: [NSTextSelection], with string: String) {
        internalReplaceCharacters(in: textSelections, with: NSAttributedString(string: string))
    }

    func internalReplaceCharacters(in textSelections: [NSTextSelection], with attributedString: NSAttributedString) {
        textContentStorage.performEditingTransaction {
            for textSelection in textSelections {
                internalReplaceCharacters(in: textSelection, with: attributedString)
            }
        }
    }

    func internalReplaceCharacters(in textSelection: NSTextSelection, with attributedString: NSAttributedString) {
        textContentStorage.performEditingTransaction {
            if let firstTextRange = textSelection.markedTextRange ?? textSelection.textRanges.first {
                internalReplaceCharacters(in: firstTextRange, with: attributedString)
            }

            for textRange in textSelection.textRanges.dropFirst() {
                internalDeleteCharacters(in: textRange)
            }
        }
    }

    func internalReplaceCharacters(in textRange: NSTextRange, with attributedString: NSAttributedString) {
        textStorage.replaceCharacters(in: NSRange(textRange, in: textContentStorage), with: attributedString)
    }

    func internalDeleteCharacters(in textRange: NSTextRange) {
        textStorage.replaceCharacters(in: NSRange(textRange, in: textContentStorage), with: "")
    }

    // MARK: - Attribute manipulation

    func setAttributesForDocumentRange(_ attrs: [NSAttributedString.Key : Any]?) {
        setAttributes(attrs, textRange: textContentStorage.documentRange)
    }

    func setAttributes(_ attrs: [NSAttributedString.Key : Any]?, textRange: NSTextRange) {
        textContentStorage.performEditingTransaction {
            textStorage.setAttributes(attrs, range: NSRange(textRange, in: textContentStorage))
        }
    }

    func removeAttributeForDocumentRange(_ name: NSAttributedString.Key) {
        removeAttribute(name, textRange: textContentStorage.documentRange)
    }

    func removeAttribute(_ name: NSAttributedString.Key, textRange: NSTextRange) {
        textContentStorage.performEditingTransaction {
            textStorage.removeAttribute(name, range: NSRange(textRange, in: textContentStorage))
        }
    }
}

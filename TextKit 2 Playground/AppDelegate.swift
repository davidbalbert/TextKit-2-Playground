//
//  AppDelegate.swift
//  TextKit 2 Playground
//
//  Created by David Albert on 5/11/22.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet var window: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        guard let contentView = window.contentView else {
            print("nope")
            return
        }

        let scrollView = TextView.scrollableTextView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        contentView.subviews = [scrollView]

        scrollView.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
        scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
        scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
        scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor).isActive = true

        let textView = scrollView.documentView as! TextView

        if let url = Bundle.main.url(forResource: "Moby Dick", withExtension: "txt") {
            textView.string = try! String(contentsOf: url)
        }

        window.makeKeyAndOrderFront(self)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}


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

        let textView = TextView()
        textView.translatesAutoresizingMaskIntoConstraints = false

        contentView.subviews = [textView]

        textView.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
        textView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
        textView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
        textView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor).isActive = true

        textView.textContentStorage.textStorage!.replaceCharacters(in: NSRange(location: 0, length: 0), with: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Cras fermentum odio eu feugiat pretium nibh ipsum consequat. Ut tortor pretium viverra suspendisse potenti nullam ac. Sodales neque sodales ut etiam. Velit laoreet id donec ultrices. Eget aliquet nibh praesent tristique magna sit. At tellus at urna condimentum mattis pellentesque. Mattis molestie a iaculis at erat pellentesque adipiscing commodo. Feugiat nibh sed pulvinar proin gravida. Luctus accumsan tortor posuere ac ut consequat semper viverra nam. Pellentesque dignissim enim sit amet venenatis urna cursus. Sagittis vitae et leo duis. Justo nec ultrices dui sapien eget mi proin sed. Et netus et malesuada fames. Amet venenatis urna cursus eget. Ac tortor vitae purus faucibus ornare. Libero enim sed faucibus turpis in eu mi bibendum. Dictum sit amet justo donec enim.\n\nLaoreet sit amet cursus sit amet dictum sit. Diam maecenas sed enim ut sem viverra. Turpis massa sed elementum tempus egestas sed. Fringilla urna porttitor rhoncus dolor purus. Sagittis id consectetur purus ut faucibus pulvinar elementum integer. At risus viverra adipiscing at in tellus. Augue eget arcu dictum varius duis at consectetur lorem donec. Amet mattis vulputate enim nulla aliquet. Magna etiam tempor orci eu lobortis elementum nibh. Id volutpat lacus laoreet non curabitur gravida arcu ac. Sed risus pretium quam vulputate. Aliquam malesuada bibendum arcu vitae. Nisi est sit amet facilisis magna etiam tempor. Vulputate odio ut enim blandit. Eu sem integer vitae justo eget magna fermentum iaculis. Amet aliquam id diam maecenas ultricies mi eget mauris. Et malesuada fames ac turpis egestas integer eget aliquet nibh. A lacus vestibulum sed arcu non odio euismod lacinia at. Sed faucibus turpis in eu mi. Est ultricies integer quis auctor elit sed vulputate mi sit.\n\nFacilisi cras fermentum odio eu feugiat pretium. Habitant morbi tristique senectus et netus et malesuada. Fringilla est ullamcorper eget nulla. Massa sed elementum tempus egestas sed sed risus pretium. Interdum consectetur libero id faucibus nisl tincidunt eget. Arcu non odio euismod lacinia. Tincidunt eget nullam non nisi. Sapien eget mi proin sed libero enim sed faucibus. Pretium nibh ipsum consequat nisl vel pretium. Rhoncus mattis rhoncus urna neque viverra justo nec ultrices dui. Neque convallis a cras semper auctor neque vitae tempus. Augue ut lectus arcu bibendum. Cursus sit amet dictum sit amet justo. Consectetur purus ut faucibus pulvinar elementum integer enim neque volutpat.")

        window.makeKeyAndOrderFront(self)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}


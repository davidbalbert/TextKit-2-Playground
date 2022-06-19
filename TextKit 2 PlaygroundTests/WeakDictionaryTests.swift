//
//  WeakDictionaryTests.swift
//  TextKit 2 PlaygroundTests
//
//  Created by David Albert on 6/19/22.
//

import XCTest
@testable import TextKit_2_Playground

class WeakDictionaryTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testWeakDictionary() throws {
        var d: WeakDictionary<String, NSObject> = WeakDictionary()
        var o: NSObject? = NSObject()
        d["foo"] = o
        XCTAssertEqual(d["foo"], o)
        o = nil
        XCTAssertEqual(d["foo"], nil)
    }
}

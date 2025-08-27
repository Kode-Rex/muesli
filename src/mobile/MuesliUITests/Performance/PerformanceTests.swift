//
//  PerformanceTests.swift
//  MuesliUITests
//
//  Created by Travis Frisinger on 8/25/25.
//

import XCTest

@MainActor
final class PerformanceTests: XCTestCase {
    
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }
    
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
    
    func testScrollPerformance() throws {
        app.launch()
        
        // Test scrolling performance through the notes list
        let notesScrollView = app.scrollViews.firstMatch
        
        measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric]) {
            notesScrollView.swipeUp()
            notesScrollView.swipeDown()
        }
    }
}

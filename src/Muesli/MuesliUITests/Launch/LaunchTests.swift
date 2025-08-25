//
//  LaunchTests.swift
//  MuesliUITests
//
//  Created by Travis Frisinger on 8/25/25.
//

import XCTest

@MainActor
final class LaunchTests: XCTestCase {
    
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }
    
    func testAppLaunches() throws {
        // Verify the app launches successfully
        XCTAssertTrue(app.exists)
        
        // Verify main UI elements are present
        XCTAssertTrue(app.staticTexts["My Notes"].exists)
        XCTAssertTrue(app.searchFields.element.exists)
    }
    
    func testMainViewElements() throws {
        // Check for header elements
        XCTAssertTrue(app.staticTexts["My Notes"].exists)
        XCTAssertTrue(app.images["person.crop.circle"].exists) // Profile icon
        
        // Check for search functionality
        XCTAssertTrue(app.searchFields.element.exists)
        
        // Check for sample notes
        XCTAssertTrue(app.staticTexts["August 2025 HOA Board Meeting"].exists)
        XCTAssertTrue(app.staticTexts["AI integration strategy for higher..."].exists)
        
        // Check for floating action button
        XCTAssertTrue(app.buttons["New"].exists)
    }
    
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}

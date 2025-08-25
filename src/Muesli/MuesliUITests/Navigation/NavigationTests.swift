//
//  NavigationTests.swift
//  MuesliUITests
//
//  Created by Travis Frisinger on 8/25/25.
//

import XCTest

@MainActor
final class NavigationTests: XCTestCase {
    
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }
    
    func testNavigateToSettings() throws {
        // Tap profile icon to open settings
        app.images["person.crop.circle"].tap()
        
        // Verify settings view opened
        XCTAssertTrue(app.staticTexts["Settings"].exists)
        XCTAssertTrue(app.staticTexts["Profile"].exists)
        XCTAssertTrue(app.staticTexts["Archive"].exists)
        
        // Close settings
        app.buttons["Done"].tap()
        
        // Verify back to main view
        XCTAssertTrue(app.staticTexts["My Notes"].exists)
    }
    
    func testNavigateToArchive() throws {
        // Open settings
        app.images["person.crop.circle"].tap()
        
        // Tap Archive
        app.staticTexts["Archive"].tap()
        
        // Verify archive view opened
        XCTAssertTrue(app.staticTexts["Archived Notes"].exists)
        XCTAssertTrue(app.buttons["Done"].exists)
        
        // Go back
        app.buttons["Done"].tap()
        app.buttons["Done"].tap() // Close settings too
        
        // Verify back to main view
        XCTAssertTrue(app.staticTexts["My Notes"].exists)
    }
    
    func testHandleEmptyStates() throws {
        // Navigate to archive which should be empty initially
        app.images["person.crop.circle"].tap()
        app.staticTexts["Archive"].tap()
        
        // Verify empty state or message
        XCTAssertTrue(app.staticTexts["Archived Notes"].exists)
        
        // Go back
        app.buttons["Done"].tap()
        app.buttons["Done"].tap()
    }
}

//
//  FeatureTests.swift
//  MuesliUITests
//
//  Created by Travis Frisinger on 8/25/25.
//

import XCTest

@MainActor
final class FeatureTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testSearchFunctionality() throws {
        // Tap search field
        let searchField = app.searchFields.element
        searchField.tap()

        // Type search query
        searchField.typeText("AI")

        // Verify filtered results
        XCTAssertTrue(app.staticTexts["AI integration strategy for higher..."].exists)
        XCTAssertTrue(app.staticTexts["AI learning and personal reflectio..."].exists)

        // Clear search
        if app.buttons["Clear text"].exists {
            app.buttons["Clear text"].tap()
        } else {
            searchField.clearAndEnterText("")
        }

        // Verify all notes are back
        XCTAssertTrue(app.staticTexts["August 2025 HOA Board Meeting"].exists)
    }

    func testOpenNewNoteView() throws {
        // Tap the "New" button
        app.buttons["New"].tap()

        // Verify new note view opened
        XCTAssertTrue(app.staticTexts["New Note"].exists)
        XCTAssertTrue(app.textFields["Note title"].exists)
        XCTAssertTrue(app.textViews["Start typing your notes..."].exists)

        // Close new note view
        app.buttons["Cancel"].tap()

        // Verify back to main view
        XCTAssertTrue(app.staticTexts["My Notes"].exists)
    }
}

// MARK: - Helper Extensions
extension XCUIElement {
    func clearAndEnterText(_ text: String) {
        guard let stringValue = self.value as? String else {
            XCTFail("Tried to clear and enter text into a non string value")
            return
        }

        self.tap()

        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)

        self.typeText(deleteString)
        self.typeText(text)
    }
}

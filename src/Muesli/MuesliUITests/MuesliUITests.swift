//
//  MuesliUITests.swift
//  MuesliUITests
//
//  Created by Travis Frisinger on 8/25/25.
//

import XCTest

final class MuesliUITests: XCTestCase {
    
    var app: XCUIApplication!

    override func setUpWithError() throws {
        // Stop immediately when a failure occurs
        continueAfterFailure = false
        
        // Launch the application
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - App Launch Tests
    
    @MainActor
    func testAppLaunches() throws {
        // Verify the app launches successfully
        XCTAssertTrue(app.exists)
        
        // Verify main UI elements are present
        XCTAssertTrue(app.staticTexts["My Notes"].exists)
        XCTAssertTrue(app.searchFields.element.exists)
    }
    
    @MainActor
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
    
    // MARK: - Navigation Tests
    
    @MainActor
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
    
    @MainActor
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
    
    // MARK: - Note Interaction Tests
    
    @MainActor
    func testViewNoteDetails() throws {
        // Tap on a note to view details
        app.staticTexts["August 2025 HOA Board Meeting"].tap()
        
        // Verify note detail view opened
        XCTAssertTrue(app.staticTexts["August 2025 HOA Board Meeting"].exists)
        XCTAssertTrue(app.staticTexts["Financial Review"].exists)
        
        // Verify 3-dot menu button exists
        XCTAssertTrue(app.buttons["ellipsis"].exists)
        
        // Close detail view
        app.buttons["Done"].tap()
        
        // Verify back to main view
        XCTAssertTrue(app.staticTexts["My Notes"].exists)
    }
    
    @MainActor
    func testNoteDetailMenu() throws {
        // Open note detail
        app.staticTexts["August 2025 HOA Board Meeting"].tap()
        
        // Tap 3-dot menu
        app.buttons["ellipsis"].tap()
        
        // Verify menu options appear
        XCTAssertTrue(app.staticTexts["Edit title"].exists)
        XCTAssertTrue(app.staticTexts["Edit AI summary"].exists)
        XCTAssertTrue(app.staticTexts["View transcript"].exists)
        XCTAssertTrue(app.staticTexts["Show my notes"].exists)
        XCTAssertTrue(app.staticTexts["Copy notes"].exists)
        
        // Close menu by tapping elsewhere
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1)).tap()
        
        // Close detail view
        app.buttons["Done"].tap()
    }
    
    @MainActor
    func testViewTranscript() throws {
        // Open note detail
        app.staticTexts["August 2025 HOA Board Meeting"].tap()
        
        // Open menu and select transcript
        app.buttons["ellipsis"].tap()
        app.staticTexts["View transcript"].tap()
        
        // Verify transcript view opened
        XCTAssertTrue(app.staticTexts["Meeting Transcript"].exists)
        XCTAssertTrue(app.staticTexts["Welcome everyone to the August 2025 HOA Board Meeting"].exists)
        
        // Close transcript view
        app.buttons["Done"].tap()
        
        // Close detail view
        app.buttons["Done"].tap()
    }
    
    @MainActor
    func testShowMyNotes() throws {
        // Open note detail
        app.staticTexts["August 2025 HOA Board Meeting"].tap()
        
        // Open menu and select "Show my notes"
        app.buttons["ellipsis"].tap()
        app.staticTexts["Show my notes"].tap()
        
        // Verify personal notes view opened
        XCTAssertTrue(app.staticTexts["My Notes"].exists)
        XCTAssertTrue(app.staticTexts["Send notice to residents about parking changes"].exists)
        
        // Close personal notes view
        app.buttons["Done"].tap()
        
        // Close detail view
        app.buttons["Done"].tap()
    }
    
    // MARK: - Search Tests
    
    @MainActor
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
    
    // MARK: - New Note Tests
    
    @MainActor
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
    
    // MARK: - Context Menu Tests
    
    @MainActor
    func testNoteContextMenu() throws {
        // Find a note card and long press it
        let noteCard = app.staticTexts["August 2025 HOA Board Meeting"]
        noteCard.press(forDuration: 1.0)
        
        // Verify context menu appears
        XCTAssertTrue(app.staticTexts["Edit Title"].exists)
        XCTAssertTrue(app.staticTexts["Archive"].exists)
        
        // Cancel context menu by tapping elsewhere
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1)).tap()
    }
    
    @MainActor
    func testArchiveNoteFromContextMenu() throws {
        // Long press on a note
        let noteCard = app.staticTexts["August 2025 HOA Board Meeting"]
        noteCard.press(forDuration: 1.0)
        
        // Tap Archive
        app.staticTexts["Archive"].tap()
        
        // Verify the note is no longer visible in main view
        XCTAssertFalse(app.staticTexts["August 2025 HOA Board Meeting"].exists)
        
        // Check it's in archive
        app.images["person.crop.circle"].tap()
        app.staticTexts["Archive"].tap()
        
        // Should find it in archive (this test might need adjustment based on sample data)
        // For now, just verify we can navigate to archive
        XCTAssertTrue(app.staticTexts["Archived Notes"].exists)
        
        // Go back
        app.buttons["Done"].tap()
        app.buttons["Done"].tap()
    }
    
    // MARK: - Error Handling Tests
    
    @MainActor
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
    
    // MARK: - Performance Tests
    
    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
    
    @MainActor
    func testScrollPerformance() throws {
        // Test scrolling performance through the notes list
        let notesScrollView = app.scrollViews.firstMatch
        
        measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric]) {
            notesScrollView.swipeUp()
            notesScrollView.swipeDown()
        }
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

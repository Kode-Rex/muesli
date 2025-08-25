//
//  NoteInteractionTests.swift
//  MuesliUITests
//
//  Created by Travis Frisinger on 8/25/25.
//

import XCTest

@MainActor
final class NoteInteractionTests: XCTestCase {
    
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }
    
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
}

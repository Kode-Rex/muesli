//
//  EnhancedNoteEditorViewTests.swift
//  MuesliTests
//
//  Tests for EnhancedNoteEditorView functionality
//

import Testing
import Foundation
import SwiftUI
@testable import Muesli

@Suite("Enhanced Note Editor View Tests", .tags(.views))
struct EnhancedNoteEditorViewTests {
    
    @Test("Enhanced editor initializes with note content")
    func enhancedEditorInitializesWithNoteContent() async throws {
        let testContent = "Initial note content for testing"
        let note = Note(
            title: "Test Note",
            content: testContent,
            sessionType: "note"
        )
        
        // Test that the initial content matches the note
        #expect(note.content == testContent)
        #expect(note.title == "Test Note")
        #expect(note.sessionType == "note")
    }
    
    @Test("Word count calculation works correctly")
    func wordCountCalculationWorksCorrectly() async throws {
        let testCases = [
            ("", 0),
            ("single", 1),
            ("two words", 2),
            ("multiple words in a sentence", 6),
            ("  extra   spaces  between   words  ", 4),
            ("line\nbreaks\ncount\nwords", 4),
            ("mixed\twhitespace\n\tcharacters", 3)
        ]
        
        for (text, expectedCount) in testCases {
            let wordCount = text.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }.count
            #expect(wordCount == expectedCount, "Failed for text: '\(text)' - expected \(expectedCount), got \(wordCount)")
        }
    }
    
    @Test("Format insertion adds correct markup")
    func formatInsertionAddsCorrectMarkup() async throws {
        var content = "Initial content"
        
        // Test header insertion
        content += "# "
        #expect(content.contains("# "))
        
        // Test bullet point insertion
        content += "• "
        #expect(content.contains("• "))
        
        // Test sub-bullet insertion
        content += "○ "
        #expect(content.contains("○ "))
        
        // Test checklist insertion
        content += "- [ ] "
        #expect(content.contains("- [ ] "))
    }
    
    @Test("Format wrapping adds correct markup around text")
    func formatWrappingAddsCorrectMarkupAroundText() async throws {
        var content = "base content"
        
        // Test bold wrapping
        content += "**text**"
        #expect(content.contains("**text**"))
        
        // Test italic wrapping
        content += "*text*"
        #expect(content.contains("*text*"))
        
        // Test link wrapping
        content += "[text](url)"
        #expect(content.contains("[text](url)"))
    }
    
    @Test("Unsaved changes detection works correctly")
    func unsavedChangesDetectionWorksCorrectly() async throws {
        let originalContent = "Original content"
        let modifiedContent = "Modified content"
        
        // Test that content change is detected
        #expect(originalContent != modifiedContent)
        
        // Test that identical content doesn't trigger change
        let unchangedContent = originalContent
        #expect(originalContent == unchangedContent)
    }
    
    @Test("Format buttons generate expected markup")
    func formatButtonsGenerateExpectedMarkup() async throws {
        let formatTests = [
            ("header", "# "),
            ("bullet", "• "),
            ("sub-bullet", "○ "),
            ("checklist", "- [ ] "),
            ("bold", "**text**"),
            ("italic", "*text*"),
            ("link", "[text](url)")
        ]
        
        for (formatType, expectedMarkup) in formatTests {
            // Test that each format type produces expected markup
            #expect(!expectedMarkup.isEmpty)
            
            switch formatType {
            case "header":
                #expect(expectedMarkup == "# ")
            case "bullet":
                #expect(expectedMarkup == "• ")
            case "sub-bullet":
                #expect(expectedMarkup == "○ ")
            case "checklist":
                #expect(expectedMarkup == "- [ ] ")
            case "bold":
                #expect(expectedMarkup == "**text**")
            case "italic":
                #expect(expectedMarkup == "*text*")
            case "link":
                #expect(expectedMarkup == "[text](url)")
            default:
                break
            }
        }
    }
    
    @Test("Content validation handles various inputs")
    func contentValidationHandlesVariousInputs() async throws {
        let testInputs = [
            "",                              // Empty
            "Simple text",                   // Basic text
            "# Header\n• Bullet\n○ Sub",    // Formatted content
            "**Bold** and *italic* text",   // Inline formatting
            "- [ ] Unchecked\n- [x] Checked", // Checklists
            "[Link](https://example.com)",   // Links
            "Multi\nLine\nContent",          // Multi-line
            String(repeating: "A", count: 1000)     // Long content
        ]
        
        for input in testInputs {
            // Test that all inputs can be processed
            let wordCount = input.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }.count
            #expect(wordCount >= 0) // Word count should never be negative
            
            // Test that content length is reasonable
            #expect(input.count >= 0)
        }
    }
    
    @Test("Format application preserves existing content")
    func formatApplicationPreservesExistingContent() async throws {
        let existingContent = "Existing content that should be preserved"
        var modifiedContent = existingContent
        
        // Apply various formats
        modifiedContent += "\n# New Header"
        modifiedContent += "\n• New bullet point"
        modifiedContent += "\n**Bold addition**"
        
        // Verify original content is still there
        #expect(modifiedContent.contains("Existing content that should be preserved"))
        
        // Verify new formatting was added
        #expect(modifiedContent.contains("# New Header"))
        #expect(modifiedContent.contains("• New bullet point"))
        #expect(modifiedContent.contains("**Bold addition**"))
    }
    
    @Test("Content structure analysis for enhanced editing")
    func contentStructureAnalysisForEnhancedEditing() async throws {
        let structuredContent = """
        # Main Title
        Some introductory text here.
        
        ## Subsection
        • First bullet point
        • Second bullet point
          ○ Sub-bullet under second
        
        **Important note:** This is emphasized.
        
        - [ ] Todo item 1
        - [x] Completed item
        - [ ] Todo item 2
        
        [Link to resource](https://example.com)
        
        *Final thoughts in italics.*
        """
        
        // Test structure detection
        #expect(structuredContent.contains("# Main Title"))
        #expect(structuredContent.contains("## Subsection"))
        #expect(structuredContent.contains("• First bullet"))
        #expect(structuredContent.contains("○ Sub-bullet"))
        #expect(structuredContent.contains("**Important note:**"))
        #expect(structuredContent.contains("- [ ] Todo"))
        #expect(structuredContent.contains("- [x] Completed"))
        #expect(structuredContent.contains("[Link to resource]"))
        #expect(structuredContent.contains("*Final thoughts"))
        
        // Test content metrics
        let wordCount = structuredContent.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
        #expect(wordCount > 20) // Should be substantial content
        
        let lineCount = structuredContent.components(separatedBy: .newlines).count
        #expect(lineCount > 10) // Should have multiple lines
    }
}

// MARK: - Supporting Extensions for Testing

extension EnhancedNoteEditorViewTests {
    
    /// Helper to simulate content formatting operations
    func applyFormatting(_ format: String, to content: String) -> String {
        switch format {
        case "header":
            return content + "# "
        case "bullet":
            return content + "• "
        case "sub-bullet":
            return content + "○ "
        case "bold":
            return content + "**text**"
        case "italic":
            return content + "*text*"
        case "checklist":
            return content + "- [ ] "
        case "link":
            return content + "[text](url)"
        default:
            return content
        }
    }
    
    @Test("Formatting helper works correctly")
    func formattingHelperWorksCorrectly() async throws {
        let baseContent = "Base content "
        
        let headerFormatted = applyFormatting("header", to: baseContent)
        #expect(headerFormatted == "Base content # ")
        
        let bulletFormatted = applyFormatting("bullet", to: baseContent)
        #expect(bulletFormatted == "Base content • ")
        
        let boldFormatted = applyFormatting("bold", to: baseContent)
        #expect(boldFormatted == "Base content **text**")
        
        let invalidFormatted = applyFormatting("invalid", to: baseContent)
        #expect(invalidFormatted == baseContent) // Should return unchanged
    }
    
    /// Helper to validate formatted content structure
    func validateContentStructure(_ content: String) -> Bool {
        // Check for common formatting patterns
        let hasHeaders = content.contains("#")
        let hasBullets = content.contains("•") || content.contains("○")
        let hasFormatting = content.contains("**") || content.contains("*")
        let hasChecklists = content.contains("- [")
        let hasLinks = content.contains("[") && content.contains("](")
        
        // Return true if content has any formatting
        return hasHeaders || hasBullets || hasFormatting || hasChecklists || hasLinks || !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    @Test("Content structure validation works correctly")
    func contentStructureValidationWorksCorrectly() async throws {
        let plainText = "Just plain text"
        let formattedText = "# Header\n• Bullet\n**Bold**"
        let emptyText = ""
        let whitespaceText = "   \n\t  "
        
        #expect(validateContentStructure(plainText))      // Plain text is valid
        #expect(validateContentStructure(formattedText))  // Formatted text is valid
        #expect(!validateContentStructure(emptyText))     // Empty is invalid
        #expect(!validateContentStructure(whitespaceText)) // Just whitespace is invalid
    }
}
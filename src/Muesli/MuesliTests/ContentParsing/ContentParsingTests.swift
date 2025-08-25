//
//  ContentParsingTests.swift
//  MuesliTests
//
//  Created by Travis Frisinger on 8/25/25.
//

import Testing
import Foundation
@testable import Muesli

@Suite("Content Parsing Tests", .tags(.contentParsing))
struct ContentParsingTests {
    
    @Test("Parse content handles headers correctly")
    func parseContentHandlesHeaders() async throws {
        let content = "# Header 1\n# Header 2"
        let parsed = SampleData.parseContent(content)
        
        let headers = parsed.filter { $0.1 == .header }
        #expect(headers.count == 2)
        #expect(headers[0].0 == "Header 1")
        #expect(headers[1].0 == "Header 2")
    }
    
    @Test("Parse content handles bullet points")
    func parseContentHandlesBullets() async throws {
        let content = "• Bullet 1\n• Bullet 2"
        let parsed = SampleData.parseContent(content)
        
        let bullets = parsed.filter { $0.1 == .bullet }
        #expect(bullets.count == 2)
        #expect(bullets[0].0 == "Bullet 1")
        #expect(bullets[1].0 == "Bullet 2")
    }
    
    @Test("Parse content handles sub-bullets")
    func parseContentHandlesSubBullets() async throws {
        let content = "• Main bullet\n○ Sub bullet 1\n○ Sub bullet 2"
        let parsed = SampleData.parseContent(content)
        
        let mainBullets = parsed.filter { $0.1 == .bullet }
        let subBullets = parsed.filter { $0.1 == .subBullet }
        
        #expect(mainBullets.count == 1)
        #expect(subBullets.count == 2)
        #expect(mainBullets[0].0 == "Main bullet")
        #expect(subBullets[0].0 == "Sub bullet 1")
        #expect(subBullets[1].0 == "Sub bullet 2")
    }
    
    @Test("Parse content handles regular text")
    func parseContentHandlesText() async throws {
        let content = "Regular text line"
        let parsed = SampleData.parseContent(content)
        
        #expect(parsed.count == 1)
        #expect(parsed[0].1 == .bullet) // Regular text is treated as bullet in the actual implementation
        #expect(parsed[0].0 == "Regular text line")
    }
    
    @Test("Parse content handles mixed content types")
    func parseContentHandlesMixedContent() async throws {
        let content = """
        # Header
        Regular text
        • Bullet point
        ○ Sub bullet
        More text
        """
        
        let parsed = SampleData.parseContent(content)
        
        #expect(parsed.count == 5)
        #expect(parsed[0].1 == .header)
        #expect(parsed[1].1 == .bullet)
        #expect(parsed[2].1 == .bullet)
        #expect(parsed[3].1 == .subBullet)
        #expect(parsed[4].1 == .bullet)
    }
    
    @Test("Parse content ignores empty lines")
    func parseContentIgnoresEmptyLines() async throws {
        let content = "Line 1\n\n\nLine 2\n\n"
        let parsed = SampleData.parseContent(content)
        
        #expect(parsed.count == 2)
        #expect(parsed[0].0 == "Line 1")
        #expect(parsed[1].0 == "Line 2")
    }
    
    @Test("Parse content handles special characters")
    func parseContentHandlesSpecialCharacters() async throws {
        let content = "# Header with émojis 🚀\n• Bullet with special chars: @#$%"
        let parsed = SampleData.parseContent(content)
        
        #expect(parsed.count == 2)
        #expect(parsed[0].0.contains("Header with émojis 🚀"))
        #expect(parsed[1].0.contains("Bullet with special chars: @#$%"))
    }
}

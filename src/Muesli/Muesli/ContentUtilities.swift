//
//  ContentUtilities.swift
//  Muesli
//
//  Created by AI Assistant on 8/25/25.
//

import Foundation

enum ContentType {
    case header, bullet, subBullet
}

struct ContentUtilities {
    
    // MARK: - Content Parsing
    
    static func parseContent(_ content: String) -> [(String, ContentType)] {
        let lines = content.components(separatedBy: .newlines)
        var result: [(String, ContentType)] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.isEmpty {
                continue
            } else if trimmed.hasPrefix("# ") {
                let headerText = String(trimmed.dropFirst(2))
                result.append((headerText, .header))
            } else if trimmed.hasPrefix("• ") {
                let bulletText = String(trimmed.dropFirst(2))
                result.append((bulletText, .bullet))
            } else if trimmed.hasPrefix("○ ") {
                let subBulletText = String(trimmed.dropFirst(2))
                result.append((subBulletText, .subBullet))
            } else {
                result.append((trimmed, .bullet))
            }
        }
        
        return result
    }
    
    // MARK: - Personal Notes Extraction
    
    static func extractPersonalNotes(from content: String) -> [String] {
        let lines = content.components(separatedBy: .newlines)
        return lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.contains("Action items") ||
                   trimmed.contains("Follow up") ||
                   trimmed.contains("Goals for") ||
                   trimmed.contains("Next steps") ||
                   trimmed.contains("Personal") ||
                   trimmed.hasPrefix("• Schedule") ||
                   trimmed.hasPrefix("• Complete") ||
                   trimmed.hasPrefix("• Implement") ||
                   trimmed.hasPrefix("• Share") ||
                   trimmed.hasPrefix("○ Schedule") ||
                   trimmed.hasPrefix("○ Get quotes") ||
                   trimmed.hasPrefix("○ Send notice")
        }
    }
    
    // MARK: - Sample Content for Transcripts
    
    static let sampleTranscript = """
        [00:00] Welcome everyone to today's meeting. Let's get started with our agenda.
        
        [00:15] First item is the project status update. Sarah, could you walk us through the numbers?
        
        [00:30] Sarah: Absolutely. We've made significant progress this quarter. Our key milestones have been achieved on schedule.
        
        [01:15] The outstanding tasks are manageable, and we're on track for our delivery timeline.
        
        [01:45] One item that needs attention is the resource allocation for the next phase.
        
        [02:00] Team Lead: What about our budget considerations for Q4?
        
        [02:10] Sarah: We're within budget limits. Current spending is tracking at 85% of allocated funds.
        
        [02:45] This gives us flexibility for any unexpected requirements or opportunities.
        
        [03:15] We'll discuss budget adjustments in next week's planning session.
        
        [03:30] Any other financial considerations we should address today?
        
        [03:40] Team Lead: The equipment procurement is still pending approval.
        
        [04:00] Sarah: Moving on to our action items for next week. We need to finalize vendor contracts and schedule team reviews.
        
        [04:30] Let's also prepare for the client presentation scheduled for next month.
        
        [05:00] Action items: finalize contracts, schedule reviews, prepare presentation materials.
        
        [05:30] Meeting adjourned. Thank you everyone for your participation.
        """
}

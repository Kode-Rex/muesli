//
//  SampleData.swift
//  Muesli
//
//  Created by Travis Frisinger on 8/25/25.
//

import Foundation

enum ContentType {
    case header, bullet, subBullet
}

struct SampleData {
    
    static let notes: [SampleNote] = [
        ("August 2025 HOA Board Meeting", "6:20 PM", "Wed 20 Aug", false),
        ("AI integration strategy for higher...", "12:52 PM", "Wed 13 Aug", false),
        ("AI learning and personal reflectio...", "12:29 PM", "Wed 13 Aug", false),
        ("AI opportunities for marketplace...", "12:15 PM", "Wed 13 Aug", false)
    ]
    
    static func generateContent(for title: String) -> String {
        switch title {
        case "August 2025 HOA Board Meeting":
            return """
            # Financial Review
            
            • Haven invoice disputes resolved
                ○ Credit for pool management payments clarified
                ○ Outstanding invoices pending approval until supporting documentation reviewed
                ○ Invoice #40744 requires backup before approval
            
            • Operating account balance unusually high at $268,785
                ○ Consistently maintained ~$300k since new leadership (previously ~$130k max)
                ○ Attributed to reduced spending and board handling tasks vs. outsourcing
                ○ Excess funds discussion deferred to budget meeting
            
            • Excel Energy gas bill missing
            
            # Maintenance Updates
            
            • Pool resurfacing approved - $5,000 budget allocated
            • New guest parking restrictions effective Sept 1
            • Monthly landscaping budget increased to $800
            
            # Action Items
            
            • Send notice to residents about parking changes
            • Get quotes for pool work
            • Schedule community meeting for October
            • Follow up on missing gas bill
            """
            
        case let title where title.contains("AI integration"):
            return """
            # AI Integration Strategy Discussion
            
            • Current market analysis
                ○ GPT-4 for content generation capabilities
                ○ Claude for complex analysis tasks
                ○ Custom fine-tuned models for specific use cases
            
            • Implementation timeline
                ○ Q1: Prototype development and testing
                ○ Q2: User testing and feedback collection
                ○ Q3: Full deployment and training
            
            • Budget considerations
                ○ Initial setup costs: $50,000
                ○ Monthly operational costs: $5,000
                ○ ROI expected within 18 months
            
            # Next Steps
            
            • Prototype development begins next week
            • Schedule user testing sessions
            • Present to board for final approval
            """
            
        case let title where title.contains("AI learning"):
            return """
            # Personal AI Learning Reflection
            
            • Key insights gained
                ○ AI is transforming traditional workflows
                ○ Prompt engineering is becoming essential skill
                ○ Integration requires careful change management
            
            • Skills development priorities
                ○ Advanced prompt engineering techniques
                ○ AI tool evaluation and selection
                ○ Team training and adoption strategies
            
            • Practical applications identified
                ○ Content creation automation
                ○ Data analysis and reporting
                ○ Customer service enhancement
            
            # Goals for Next Month
            
            • Complete AI certification course
            • Implement AI tools in current projects
            • Share learnings with team through workshop
            """
            
        case let title where title.contains("AI opportunities"):
            return """
            # AI Marketplace Opportunities
            
            • Market size and potential
                ○ Global AI market projected $1.8T by 2030
                ○ Enterprise adoption rate: 85% by 2025
                ○ Our target segment growing 40% annually
            
            • Competitive landscape
                ○ OpenAI leading consumer market
                ○ Microsoft/Google dominating enterprise
                ○ Niche opportunities in specialized verticals
            
            • Strategic recommendations
                ○ Focus on vertical-specific solutions
                ○ Partner with established platforms
                ○ Build proprietary data advantages
            
            # Investment Requirements
            
            • Technical team expansion: $2M
            • Platform development: $5M
            • Marketing and sales: $3M
            """
            
        default:
            return """
            # Conference Session Notes
            
            • Key discussion points
                ○ Topic overview and context
                ○ Industry trends and implications
                ○ Best practices shared by speakers
            
            • Actionable insights
                ○ Implementation strategies discussed
                ○ Tools and resources recommended
                ○ Common pitfalls to avoid
            
            • Networking connections
                ○ Contact information for follow-up
                ○ Potential collaboration opportunities
                ○ Industry expertise to leverage
            
            # Follow-up Actions
            
            • Schedule follow-up meetings with key contacts
            • Research recommended tools and platforms
            • Share insights with team
            • Plan implementation of new strategies
            """
        }
    }
    
    static let transcript = """
        [00:00] Welcome everyone to the August 2025 HOA Board Meeting. I'm Sarah, your board president.
        
        [00:15] First item on our agenda is the financial review. Tom, could you walk us through the numbers?
        
        [00:30] Tom: Absolutely. So we've resolved those Haven invoice disputes. The credit for pool management payments has been clarified, and we're in a much better position now.
        
        [01:15] The outstanding invoices are still pending approval, but that's just because we're waiting for the supporting documentation to be reviewed properly.
        
        [01:45] Invoice #40744 in particular requires backup documentation before we can approve it.
        
        [02:00] Sarah: What about our operating account balance? I noticed it's higher than usual.
        
        [02:10] Tom: Yes, we're at $268,785, which is unusually high. We've consistently maintained around $300k since the new leadership took over, compared to the previous maximum of around $130k.
        
        [02:45] This is attributed to reduced spending and the board handling more tasks internally versus outsourcing everything.
        
        [03:15] We'll defer the excess funds discussion to the budget meeting next month.
        
        [03:30] Sarah: Any other financial items? What about that Excel Energy bill?
        
        [03:40] Tom: Unfortunately, the Excel Energy gas bill is still missing. I'll follow up on that this week.
        
        [04:00] Sarah: Moving on to maintenance updates. The pool resurfacing has been approved with a $5,000 budget allocation.
        
        [04:30] New guest parking restrictions will be effective September 1st, and we've increased the monthly landscaping budget to $800.
        
        [05:00] Action items for next week include sending notices to residents about parking changes, getting quotes for pool work, and scheduling the October community meeting.
        
        [05:30] Meeting adjourned. Thank you everyone.
        """
}

// MARK: - Content Parsing Utilities
extension SampleData {
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
}

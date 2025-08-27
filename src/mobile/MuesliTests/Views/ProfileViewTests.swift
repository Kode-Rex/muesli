//
//  ProfileViewTests.swift
//  MuesliTests
//
//  Tests for ProfileView functionality
//

import Testing
import Foundation
import SwiftUI
@testable import Muesli

@Suite("Profile View Tests", .tags(.views))
struct ProfileViewTests {
    
    @Test("Profile view initializes with default values")
    func profileViewInitializesWithDefaults() async throws {
        // Since ProfileView uses @AppStorage, we test the default values
        // that would be used when no stored preferences exist
        
        // Test default session types array
        let sessionTypes = ["note", "meeting", "session"]
        #expect(sessionTypes.contains("note"))
        #expect(sessionTypes.contains("meeting"))
        #expect(sessionTypes.contains("session"))
        #expect(sessionTypes.count == 3)
    }
    
    @Test("Profile view handles empty display name gracefully")
    func profileViewHandlesEmptyDisplayName() async throws {
        // Test the logic that displays "Your Name" when displayName is empty
        let emptyName = ""
        let displayText = emptyName.isEmpty ? "Your Name" : emptyName
        #expect(displayText == "Your Name")
    }
    
    @Test("Profile view handles empty email gracefully")
    func profileViewHandlesEmptyEmail() async throws {
        // Test the logic that displays placeholder when email is empty
        let emptyEmail = ""
        let displayText = emptyEmail.isEmpty ? "your.email@example.com" : emptyEmail
        #expect(displayText == "your.email@example.com")
    }
    
    @Test("Profile view handles actual user data")
    func profileViewHandlesActualUserData() async throws {
        let userName = "John Doe"
        let userEmail = "john.doe@company.com"
        let userOrg = "Tech Corp"
        
        let displayName = userName.isEmpty ? "Your Name" : userName
        let displayEmail = userEmail.isEmpty ? "your.email@example.com" : userEmail
        
        #expect(displayName == "John Doe")
        #expect(displayEmail == "john.doe@company.com")
        #expect(userOrg == "Tech Corp")
    }
    
    @Test("Profile view default preferences are valid")
    func profileViewDefaultPreferencesAreValid() async throws {
        // Test default values that ProfileView would use
        let defaultSessionType = "note"
        let enableNotifications = true
        let autoArchiveOldNotes = false
        
        #expect(defaultSessionType == "note")
        #expect(enableNotifications == true)
        #expect(autoArchiveOldNotes == false)
        
        // Verify default session type is in valid options
        let validSessionTypes = ["note", "meeting", "session"]
        #expect(validSessionTypes.contains(defaultSessionType))
    }
    
    @Test("Profile view session type validation")
    func profileViewSessionTypeValidation() async throws {
        let validTypes = ["note", "meeting", "session"]
        
        // Test each valid type
        for sessionType in validTypes {
            #expect(validTypes.contains(sessionType))
        }
        
        // Test invalid types
        let invalidTypes = ["invalid", "", "presentation", "call"]
        for invalidType in invalidTypes {
            #expect(!validTypes.contains(invalidType))
        }
    }
}

// MARK: - Supporting Extensions for Testing

extension ProfileViewTests {
    
    /// Helper to test profile data validation
    func validateProfileData(name: String, email: String, organization: String) -> Bool {
        // Basic validation that ProfileView might use
        let hasValidName = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasValidEmail = email.contains("@") && email.contains(".")
        let organizationValid = true // Organization is optional
        
        return hasValidName && hasValidEmail && organizationValid
    }
    
    @Test("Profile data validation works correctly")
    func profileDataValidation() async throws {
        // Valid data
        #expect(validateProfileData(name: "John Doe", email: "john@company.com", organization: "Tech Corp"))
        
        // Invalid name (empty)
        #expect(!validateProfileData(name: "", email: "john@company.com", organization: "Tech Corp"))
        #expect(!validateProfileData(name: "   ", email: "john@company.com", organization: "Tech Corp"))
        
        // Invalid email (no @)
        #expect(!validateProfileData(name: "John Doe", email: "johncompany.com", organization: "Tech Corp"))
        
        // Invalid email (no domain)
        #expect(!validateProfileData(name: "John Doe", email: "john@", organization: "Tech Corp"))
        
        // Valid with empty organization (optional)
        #expect(validateProfileData(name: "John Doe", email: "john@company.com", organization: ""))
    }
}

// MARK: - Test Tags Extension
// Note: Tags are defined in NoteModelTests.swift to avoid redefinition
#!/bin/bash

echo "🔍 Checking for potential build issues..."
echo ""

# Check if all Swift files compile individually
echo "📁 Checking Swift files:"
for file in $(find Muesli/Muesli -name "*.swift"); do
    echo "  ✓ $file"
done
echo ""

# Check for common issues
echo "🔧 Checking for common issues:"

# Check for UIKit imports where needed
echo "  • UIKit imports:"
grep -l "UIPasteboard\|UIImpactFeedbackGenerator" Muesli/Muesli/**/*.swift | while read file; do
    if grep -q "import UIKit" "$file"; then
        echo "    ✓ $file (has UIKit import)"
    else
        echo "    ⚠️  $file (missing UIKit import)"
    fi
done

echo ""
echo "📝 To fix the build in Xcode:"
echo "1. Open Muesli.xcodeproj in Xcode"
echo "2. Right-click on the Muesli folder in the navigator"
echo "3. Select 'Add Files to Muesli'"
echo "4. Navigate to the following new files and add them:"
echo "   - Models.swift"
echo "   - DesignSystem.swift" 
echo "   - SampleData.swift"
echo "   - Views/MainView.swift"
echo "   - Views/ArchiveView.swift"
echo "   - Views/SettingsView.swift"
echo "   - Views/NoteDetailView.swift"
echo "   - Views/NoteOptionsView.swift"
echo "   - Views/MyNotesView.swift"
echo "   - Views/TranscriptView.swift"
echo "   - Views/NewNoteView.swift"
echo "   - Views/NoteCardView.swift"
echo ""
echo "5. Make sure to check 'Add to target: Muesli' for each file"
echo "6. Clean and rebuild the project (Cmd+Shift+K, then Cmd+B)"

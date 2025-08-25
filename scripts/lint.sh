#!/bin/bash
# SwiftLint runner script for Muesli
# Usage: ./scripts/lint.sh [fix]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

FIX_MODE=false

# Parse arguments
if [ $# -gt 0 ] && [ "$1" = "fix" ]; then
    FIX_MODE=true
fi

echo -e "${BLUE}🔍 Running SwiftLint${NC}"

# Check if SwiftLint is installed
if ! command -v swiftlint &> /dev/null; then
    echo -e "${YELLOW}⚠️  SwiftLint not found. Installing...${NC}"
    if command -v brew &> /dev/null; then
        brew install swiftlint
    else
        echo -e "${RED}❌ Homebrew not found. Please install SwiftLint manually.${NC}"
        echo "Visit: https://github.com/realm/SwiftLint#installation"
        exit 1
    fi
fi

# Run SwiftLint
if [ "$FIX_MODE" = true ]; then
    echo -e "${YELLOW}🔧 Running SwiftLint with autocorrect...${NC}"
    swiftlint --fix --format --config .swiftlint.yml
    echo -e "${GREEN}✅ SwiftLint autocorrect completed${NC}"
    
    # Run analysis after fixing to show remaining issues
    echo -e "${YELLOW}🔍 Running analysis to show remaining issues...${NC}"
    swiftlint lint --config .swiftlint.yml
else
    echo -e "${YELLOW}🔍 Running SwiftLint analysis...${NC}"
    swiftlint lint --strict --config .swiftlint.yml
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ SwiftLint passed${NC}"
    else
        echo -e "${RED}❌ SwiftLint found issues${NC}"
        echo -e "${YELLOW}💡 Run './scripts/lint.sh fix' to auto-fix some issues${NC}"
        exit 1
    fi
fi

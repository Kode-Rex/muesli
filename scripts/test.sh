#!/bin/bash
# Test runner script for Muesli
# Usage: ./scripts/test.sh [unit|ui|all] [device]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
TEST_TYPE="all"
DEVICE="iPhone 16"
WORKSPACE_DIR="src/Muesli"

# Parse arguments
if [ $# -gt 0 ]; then
    TEST_TYPE=$1
fi

if [ $# -gt 1 ]; then
    DEVICE=$2
fi

echo -e "${BLUE}🚀 Running Muesli Tests${NC}"
echo -e "${BLUE}📱 Device: $DEVICE${NC}"
echo -e "${BLUE}🧪 Test Type: $TEST_TYPE${NC}"
echo ""

# Change to workspace directory
cd "$WORKSPACE_DIR"

# Function to run unit tests
run_unit_tests() {
    echo -e "${YELLOW}🔬 Running Unit Tests...${NC}"
    xcodebuild test \
        -scheme Muesli \
        -destination "platform=iOS Simulator,name=$DEVICE,OS=latest" \
        -only-testing:MuesliTests \
        | xcpretty --color --test
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Unit Tests Passed${NC}"
    else
        echo -e "${RED}❌ Unit Tests Failed${NC}"
        exit 1
    fi
}

# Function to run UI tests
run_ui_tests() {
    echo -e "${YELLOW}📱 Running UI Tests...${NC}"
    xcodebuild test \
        -scheme Muesli \
        -destination "platform=iOS Simulator,name=$DEVICE,OS=latest" \
        -only-testing:MuesliUITests \
        | xcpretty --color --test
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ UI Tests Passed${NC}"
    else
        echo -e "${RED}❌ UI Tests Failed${NC}"
        exit 1
    fi
}

# Function to run all tests
run_all_tests() {
    echo -e "${YELLOW}🧪 Running All Tests...${NC}"
    xcodebuild test \
        -scheme Muesli \
        -destination "platform=iOS Simulator,name=$DEVICE,OS=latest" \
        -enableCodeCoverage YES \
        | xcpretty --color --test
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ All Tests Passed${NC}"
    else
        echo -e "${RED}❌ Some Tests Failed${NC}"
        exit 1
    fi
}

# Check if xcpretty is installed
if ! command -v xcpretty &> /dev/null; then
    echo -e "${YELLOW}⚠️  xcpretty not found. Installing...${NC}"
    gem install xcpretty
fi

# Run tests based on type
case $TEST_TYPE in
    "unit")
        run_unit_tests
        ;;
    "ui")
        run_ui_tests
        ;;
    "all")
        run_all_tests
        ;;
    *)
        echo -e "${RED}❌ Invalid test type: $TEST_TYPE${NC}"
        echo "Usage: $0 [unit|ui|all] [device]"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}🎉 Tests completed successfully!${NC}"

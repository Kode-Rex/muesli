#!/bin/bash
# Build script for Muesli
# Usage: ./scripts/build.sh [clean] [device]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
CLEAN_BUILD=false
DEVICE="iPhone 16"
WORKSPACE_DIR="src/mobile"

# Parse arguments
for arg in "$@"; do
    case $arg in
        "clean")
            CLEAN_BUILD=true
            ;;
        *)
            if [[ $arg == *"iPhone"* ]]; then
                DEVICE=$arg
            fi
            ;;
    esac
done

echo -e "${BLUE}🔨 Building Muesli${NC}"
echo -e "${BLUE}📱 Device: $DEVICE${NC}"
echo -e "${BLUE}🧹 Clean Build: $CLEAN_BUILD${NC}"
echo ""

# Change to workspace directory
cd "$WORKSPACE_DIR"

# Build command
BUILD_CMD="xcodebuild"

if [ "$CLEAN_BUILD" = true ]; then
    echo -e "${YELLOW}🧹 Cleaning build directory...${NC}"
    BUILD_CMD="$BUILD_CMD clean"
fi

BUILD_CMD="$BUILD_CMD build -scheme Muesli -destination \"platform=iOS Simulator,name=$DEVICE,OS=latest\""

# Check if xcpretty is installed
if command -v xcpretty &> /dev/null; then
    BUILD_CMD="$BUILD_CMD | xcpretty --color"
fi

echo -e "${YELLOW}🔨 Building project...${NC}"
eval $BUILD_CMD

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Build succeeded${NC}"
else
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 Build completed successfully!${NC}"

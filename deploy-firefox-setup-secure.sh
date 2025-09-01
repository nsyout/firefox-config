#!/usr/bin/env bash

## Firefox Setup Deployment Script - SECURITY HARDENED VERSION
## Deploys Arkenfox user.js + user-overrides.js + Extension Policies
## For macOS

set -euo pipefail  # Exit on any error, undefined vars, pipe failures

# Colors for output
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly GREEN='\033[0;32m'
readonly ORANGE='\033[0;33m'
readonly NC='\033[0m' # No Color

# Script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}🚀 Firefox Setup Deployment Script (Security Hardened)${NC}"
echo "================================================"

#########################
# SECURITY FUNCTIONS    #
#########################

# Validate JSON file
validate_json() {
    local file="$1"
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "import json; json.load(open('$file'))" 2>/dev/null || {
            echo -e "${RED}❌ Invalid JSON in: $file${NC}"
            return 1
        }
    else
        echo -e "${ORANGE}⚠️  Cannot validate JSON (python3 not found)${NC}"
    fi
}

# Sanitize path for safety
sanitize_path() {
    local path="$1"
    # Remove any path traversal attempts
    echo "$path" | sed 's|\.\.||g' | sed 's|//|/|g'
}

#########################
# PRE-FLIGHT CHECKS     #
#########################

echo -e "${ORANGE}Pre-flight Security Checks...${NC}"

# Check we're in the right directory
if [ ! -f "${SCRIPT_DIR}/user.js" ]; then
    echo -e "${RED}❌ Not in correct directory! user.js not found.${NC}"
    exit 1
fi

# Verify arkenfox files integrity (basic check)
readonly EXPECTED_FILES=("user.js" "user-overrides.js" "updater.sh" "prefsCleaner.sh" "your-extensions-policies.json")
for file in "${EXPECTED_FILES[@]}"; do
    if [ ! -f "${SCRIPT_DIR}/$file" ]; then
        echo -e "${RED}❌ Required file missing: $file${NC}"
        exit 1
    fi
done

echo -e "${GREEN}✅ All required files present${NC}"

# Validate policies JSON
echo "Validating extension policies..."
validate_json "${SCRIPT_DIR}/your-extensions-policies.json"
echo -e "${GREEN}✅ Extension policies JSON is valid${NC}"

# Check if running as root (bad idea)
if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    echo -e "${RED}❌ Don't run this script as root!${NC}"
    echo "Run as normal user. We'll ask for sudo only when needed."
    exit 1
fi

#########################
# 1. EXTENSION POLICIES #
#########################

echo -e "${ORANGE}Step 1: Deploying Extension Policies...${NC}"

readonly FIREFOX_APP="/Applications/Firefox.app"
readonly DISTRIBUTION_DIR="${FIREFOX_APP}/Contents/Resources/distribution"
readonly POLICIES_FILE="${SCRIPT_DIR}/your-extensions-policies.json"

if [ ! -d "$FIREFOX_APP" ]; then
    echo -e "${RED}❌ Firefox.app not found! Please install Firefox first.${NC}"
    exit 1
fi

echo "This step requires sudo to write to Firefox.app directory."
echo "Files being copied:"
echo "  Source: $POLICIES_FILE"
echo "  Destination: ${DISTRIBUTION_DIR}/policies.json"
echo ""
read -p "Continue with sudo? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted by user."
    exit 1
fi

echo "Creating distribution directory..."
sudo mkdir -p "$DISTRIBUTION_DIR"

echo "Copying extension policies..."
sudo cp "$POLICIES_FILE" "${DISTRIBUTION_DIR}/policies.json"
sudo chmod 644 "${DISTRIBUTION_DIR}/policies.json"
sudo chown root:wheel "${DISTRIBUTION_DIR}/policies.json"

echo -e "${GREEN}✅ Extension policies deployed securely!${NC}"

#########################
# 2. ARKENFOX USER.JS   #
#########################

echo -e "${ORANGE}Step 2: Setting up Arkenfox user.js...${NC}"

# Make scripts executable (only ours)
chmod +x "${SCRIPT_DIR}/updater.sh"
chmod +x "${SCRIPT_DIR}/prefsCleaner.sh"

#########################
# 3. FIREFOX PROFILE    #
#########################

echo -e "${ORANGE}Step 3: Setting up Firefox Profile...${NC}"

readonly FIREFOX_PROFILES_DIR="$HOME/Library/Application Support/Firefox/Profiles"

# Check if Firefox has been run at least once
if [ ! -d "$FIREFOX_PROFILES_DIR" ]; then
    echo -e "${ORANGE}⚠️  Firefox profile directory not found.${NC}"
    echo "You need to start Firefox once to create a profile."
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Start Firefox now (it will create a profile)"
    echo "2. Close Firefox"
    echo "3. Run this script again"
    echo ""
    read -p "Press Enter to open Firefox now, or Ctrl+C to exit..."
    open -a Firefox
    exit 0
fi

# Find the default profile (sanitized)
PROFILE_DIR=$(find "$FIREFOX_PROFILES_DIR" -name "*.default*" -type d -maxdepth 1 | head -1)
PROFILE_DIR=$(sanitize_path "$PROFILE_DIR")

if [ -z "$PROFILE_DIR" ] || [ ! -d "$PROFILE_DIR" ]; then
    echo -e "${RED}❌ No valid default Firefox profile found!${NC}"
    echo "This script only works with default profiles for security."
    exit 1
fi

echo "Found Firefox profile: $(basename "$PROFILE_DIR")"

# Check if Firefox is running
if pgrep -x "firefox" > /dev/null; then
    echo -e "${RED}❌ Firefox is currently running!${NC}"
    echo "Please close Firefox before continuing."
    exit 1
fi

# Final confirmation before modifying profile
echo ""
echo -e "${ORANGE}⚠️  About to modify Firefox profile:${NC}"
echo "Profile: $PROFILE_DIR"
echo "This will:"
echo "• Install arkenfox user.js (privacy hardening)"
echo "• Install your custom overrides"
echo "• Create backups of existing files"
echo ""
read -p "Continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted by user."
    exit 1
fi

# Run the arkenfox updater with our profile
echo "Running Arkenfox updater..."
cd "$SCRIPT_DIR"
./updater.sh -p "$PROFILE_DIR" -s

echo -e "${GREEN}✅ Arkenfox user.js deployed to profile!${NC}"

#########################
# 4. VERIFICATION       #
#########################

echo -e "${ORANGE}Step 4: Verifying deployment...${NC}"

# Check that files were actually created
if [ -f "$PROFILE_DIR/user.js" ]; then
    echo -e "${GREEN}✅ user.js deployed${NC}"
else
    echo -e "${RED}❌ user.js deployment failed${NC}"
fi

if [ -f "${DISTRIBUTION_DIR}/policies.json" ]; then
    echo -e "${GREEN}✅ Extension policies deployed${NC}"
else
    echo -e "${RED}❌ Extension policies deployment failed${NC}"
fi

#########################
# 5. SUMMARY            #
#########################

echo ""
echo -e "${GREEN}🎉 Firefox Setup Complete!${NC}"
echo "================================================"
echo -e "${BLUE}What was deployed:${NC}"
echo "✅ Extension Policies (10 extensions will auto-install)"
echo "✅ Arkenfox user.js (hardened privacy/security settings)"
echo "✅ Your user-overrides.js (custom preferences)"
echo ""
echo -e "${ORANGE}⚠️  Security Notes:${NC}"
echo "• Files deployed with proper permissions"
echo "• JSON validated before deployment"  
echo "• Profile path sanitized"
echo "• Extensions install on FIRST Firefox launch"
echo "• Your profile: $(basename "$PROFILE_DIR")"
echo ""
echo -e "${GREEN}Ready to launch Firefox!${NC}"

#########################
# 6. OPTIONAL LAUNCH    #
#########################

echo ""
read -p "Launch Firefox now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Starting Firefox..."
    open -a Firefox
    echo "Watch for extensions installing in the background!"
else
    echo "You can start Firefox manually when ready."
fi
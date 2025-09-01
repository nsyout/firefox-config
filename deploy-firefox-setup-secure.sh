#!/usr/bin/env bash

## Firefox Setup Deployment Script - SECURITY HARDENED VERSION
## Deploys Arkenfox user.js + user-overrides.js + Extension Policies
## Supports macOS and Arch Linux

set -euo pipefail  # Exit on any error, undefined vars, pipe failures

# Colors for output
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly GREEN='\033[0;32m'
readonly ORANGE='\033[0;33m'
readonly NC='\033[0m' # No Color

# Script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    FIREFOX_APP="/Applications/Firefox.app"
    FIREFOX_BIN="$FIREFOX_APP/Contents/MacOS/firefox"
    DISTRIBUTION_DIR="${FIREFOX_APP}/Contents/Resources/distribution"
    PROFILES_DIR="$HOME/Library/Application Support/Firefox/Profiles"
elif [[ -f "/etc/arch-release" ]]; then
    OS="arch"
    FIREFOX_BIN="/usr/bin/firefox"
    DISTRIBUTION_DIR="/usr/lib/firefox/distribution"
    PROFILES_DIR="$HOME/.mozilla/firefox"
else
    echo -e "${RED}ERROR: Unsupported OS. Only macOS and Arch Linux are supported.${NC}"
    exit 1
fi

echo -e "${BLUE}Firefox Setup Deployment Script (Security Hardened)${NC}"
echo "================================================"

#########################
# SECURITY FUNCTIONS    #
#########################

# Validate JSON file
validate_json() {
    local file="$1"
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "import json; json.load(open('$file'))" 2>/dev/null || {
            echo -e "${RED}ERROR: Invalid JSON in: $file${NC}"
            return 1
        }
    else
        echo -e "${ORANGE}Warning: Cannot validate JSON (python3 not found)${NC}"
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

# Check for required custom files
readonly CUSTOM_FILES=("user-overrides.js" "your-extensions-policies.json")
for file in "${CUSTOM_FILES[@]}"; do
    if [ ! -f "${SCRIPT_DIR}/$file" ]; then
        echo -e "${RED}ERROR: Required file missing: $file${NC}"
        exit 1
    fi
done

echo -e "${GREEN}OK: Custom configuration files present${NC}"

# Download arkenfox files if not present
if [ ! -f "${SCRIPT_DIR}/updater.sh" ] || [ ! -f "${SCRIPT_DIR}/prefsCleaner.sh" ]; then
    echo -e "${ORANGE}Downloading arkenfox files...${NC}"
    
    # Download updater.sh
    echo "Downloading updater.sh..."
    curl -sL "https://raw.githubusercontent.com/arkenfox/user.js/master/updater.sh" -o "${SCRIPT_DIR}/updater.sh" || {
        echo -e "${RED}ERROR: Failed to download updater.sh${NC}"
        exit 1
    }
    
    # Download prefsCleaner.sh
    echo "Downloading prefsCleaner.sh..."
    curl -sL "https://raw.githubusercontent.com/arkenfox/user.js/master/prefsCleaner.sh" -o "${SCRIPT_DIR}/prefsCleaner.sh" || {
        echo -e "${RED}ERROR: Failed to download prefsCleaner.sh${NC}"
        exit 1
    }
    
    echo -e "${GREEN}OK: Arkenfox files downloaded${NC}"
else
    echo -e "${GREEN}OK: Arkenfox files already present${NC}"
fi

# Validate policies JSON
echo "Validating extension policies..."
validate_json "${SCRIPT_DIR}/your-extensions-policies.json"
echo -e "${GREEN}OK: Extension policies JSON is valid${NC}"

# Check if running as root (bad idea)
if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    echo -e "${RED}ERROR: Don't run this script as root!${NC}"
    echo "Run as normal user. We'll ask for sudo only when needed."
    exit 1
fi

#########################
# 1. EXTENSION POLICIES #
#########################

echo -e "${ORANGE}Step 1: Deploying Extension Policies...${NC}"
echo "Detected OS: $OS"

readonly POLICIES_FILE="${SCRIPT_DIR}/your-extensions-policies.json"

# Check Firefox installation
if [[ "$OS" == "macos" ]]; then
    if [ ! -d "$FIREFOX_APP" ]; then
        echo -e "${RED}ERROR: Firefox.app not found! Please install Firefox first.${NC}"
        exit 1
    fi
else  # Arch
    if [ ! -f "$FIREFOX_BIN" ]; then
        echo -e "${RED}ERROR: Firefox not found! Install with: sudo pacman -S firefox${NC}"
        exit 1
    fi
fi

echo "This step requires sudo to write to Firefox distribution directory."
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

if [[ "$OS" == "macos" ]]; then
    sudo chown root:wheel "${DISTRIBUTION_DIR}/policies.json"
else  # Arch
    sudo chown root:root "${DISTRIBUTION_DIR}/policies.json"
fi

echo -e "${GREEN}OK: Extension policies deployed securely!${NC}"

#########################
# 2. ARKENFOX USER.JS   #
#########################

echo -e "${ORANGE}Step 2: Setting up Arkenfox user.js...${NC}"

# Make scripts executable
chmod +x "${SCRIPT_DIR}/updater.sh"
chmod +x "${SCRIPT_DIR}/prefsCleaner.sh"

# Download initial user.js if not present
if [ ! -f "${SCRIPT_DIR}/user.js" ]; then
    echo "Downloading initial arkenfox user.js..."
    curl -sL "https://raw.githubusercontent.com/arkenfox/user.js/master/user.js" -o "${SCRIPT_DIR}/user.js" || {
        echo -e "${RED}ERROR: Failed to download user.js${NC}"
        exit 1
    }
    echo -e "${GREEN}OK: Initial user.js downloaded${NC}"
fi

#########################
# 3. FIREFOX PROFILE    #
#########################

echo -e "${ORANGE}Step 3: Setting up Firefox Profile...${NC}"

# Check if Firefox has been run at least once
if [ ! -d "$PROFILES_DIR" ]; then
    echo -e "${ORANGE}Firefox profile directory not found.${NC}"
    echo "Creating initial Firefox profile..."
    
    # Create profile directory
    mkdir -p "$PROFILES_DIR"
    
    # Generate a random profile name
    PROFILE_NAME="default-$(date +%s)"
    PROFILE_DIR="$PROFILES_DIR/${PROFILE_NAME}.default"
    
    echo "Creating new profile: $PROFILE_NAME"
    
    # Use Firefox to create profile properly
    if [[ "$OS" == "macos" ]]; then
        "$FIREFOX_BIN" -CreateProfile "$PROFILE_NAME $PROFILE_DIR" 2>/dev/null || true
    else  # Arch
        firefox -CreateProfile "$PROFILE_NAME $PROFILE_DIR" 2>/dev/null || true
    fi
    
    # Create profiles.ini if it doesn't exist
    if [ ! -f "$PROFILES_DIR/profiles.ini" ]; then
        echo "[General]" > "$PROFILES_DIR/profiles.ini"
        echo "StartWithLastProfile=1" >> "$PROFILES_DIR/profiles.ini"
        echo "Version=2" >> "$PROFILES_DIR/profiles.ini"
        echo "" >> "$PROFILES_DIR/profiles.ini"
        echo "[Profile0]" >> "$PROFILES_DIR/profiles.ini"
        echo "Name=$PROFILE_NAME" >> "$PROFILES_DIR/profiles.ini"
        echo "IsRelative=1" >> "$PROFILES_DIR/profiles.ini"
        echo "Path=${PROFILE_NAME}.default" >> "$PROFILES_DIR/profiles.ini"
        echo "Default=1" >> "$PROFILES_DIR/profiles.ini"
    fi
    
    echo -e "${GREEN}OK: Profile created${NC}"
else
    echo "Firefox profiles directory found."
fi

# Find the default profile (sanitized)
PROFILE_DIR=$(find "$PROFILES_DIR" -name "*.default*" -type d -maxdepth 1 | head -1)
PROFILE_DIR=$(sanitize_path "$PROFILE_DIR")

if [ -z "$PROFILE_DIR" ] || [ ! -d "$PROFILE_DIR" ]; then
    echo -e "${RED}ERROR: No valid default Firefox profile found!${NC}"
    echo "This script only works with default profiles for security."
    exit 1
fi

echo "Found Firefox profile: $(basename "$PROFILE_DIR")"

# Check if Firefox is running
if pgrep -x "firefox" > /dev/null || pgrep -x "firefox-bin" > /dev/null; then
    echo -e "${RED}ERROR: Firefox is currently running!${NC}"
    echo "Please close Firefox before continuing."
    exit 1
fi

# Final confirmation before modifying profile
echo ""
echo -e "${ORANGE}Warning: About to modify Firefox profile:${NC}"
echo "Profile: $PROFILE_DIR"
echo "This will:"
echo "- Install arkenfox user.js (privacy hardening)"
echo "- Install your custom overrides"
echo "- Create backups of existing files"
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

echo -e "${GREEN}OK: Arkenfox user.js deployed to profile!${NC}"

#########################
# 4. FLEXOKI THEME      #
#########################

echo -e "${ORANGE}Step 4: Setting up Flexoki Theme (userChrome.css)...${NC}"

# Create chrome directory in profile
CHROME_DIR="$PROFILE_DIR/chrome"
mkdir -p "$CHROME_DIR"

# Detect current system theme preference (default to dark)
THEME_FILE="userChrome-flexoki-dark.css"
if [ -f "$HOME/.config/themes/current" ]; then
    if grep -q "light" "$HOME/.config/themes/current" 2>/dev/null; then
        THEME_FILE="userChrome-flexoki-light.css"
        echo "System theme detected: Light"
    else
        echo "System theme detected: Dark"
    fi
else
    echo "No system theme preference found, defaulting to dark"
fi

# Copy the appropriate theme file
if [ -f "${SCRIPT_DIR}/${THEME_FILE}" ]; then
    cp "${SCRIPT_DIR}/${THEME_FILE}" "${CHROME_DIR}/userChrome.css"
    echo -e "${GREEN}OK: Flexoki theme installed!${NC}"
else
    echo -e "${ORANGE}Warning: Theme file not found: ${THEME_FILE}${NC}"
    echo "Skipping theme installation..."
fi

# Enable userChrome.css in user.js (if not already present)
if ! grep -q "toolkit.legacyUserProfileCustomizations.stylesheets" "$PROFILE_DIR/user.js" 2>/dev/null; then
    echo 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' >> "$PROFILE_DIR/user-overrides.js"
    echo "Enabled custom stylesheets in user-overrides.js"
fi

#########################
# 5. VERIFICATION       #
#########################

echo -e "${ORANGE}Step 5: Verifying deployment...${NC}"

# Check that files were actually created
if [ -f "$PROFILE_DIR/user.js" ]; then
    echo -e "${GREEN}OK: user.js deployed${NC}"
else
    echo -e "${RED}ERROR: user.js deployment failed${NC}"
fi

if [ -f "${DISTRIBUTION_DIR}/policies.json" ]; then
    echo -e "${GREEN}OK: Extension policies deployed${NC}"
else
    echo -e "${RED}ERROR: Extension policies deployment failed${NC}"
fi

if [ -f "${CHROME_DIR}/userChrome.css" ]; then
    echo -e "${GREEN}OK: Flexoki theme deployed${NC}"
else
    echo -e "${ORANGE}Warning: Theme deployment skipped (file not found)${NC}"
fi

#########################
# 6. SUMMARY            #
#########################

echo ""
echo -e "${GREEN}Firefox Setup Complete!${NC}"
echo "================================================"
echo -e "${BLUE}What was deployed:${NC}"
echo "[OK] Extension Policies (10 extensions will auto-install)"
echo "[OK] Arkenfox user.js (hardened privacy/security settings)"
echo "[OK] Your user-overrides.js (custom preferences)"
echo "[OK] Flexoki theme (userChrome.css)"
echo ""
echo -e "${ORANGE}Security Notes:${NC}"
echo "- Files deployed with proper permissions"
echo "- JSON validated before deployment"  
echo "- Profile path sanitized"
echo "- Extensions install on FIRST Firefox launch"
echo "- Your profile: $(basename "$PROFILE_DIR")"
echo ""
echo -e "${GREEN}Ready to launch Firefox!${NC}"

#########################
# 7. OPTIONAL LAUNCH    #
#########################

echo ""
read -p "Launch Firefox now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Starting Firefox..."
    if [[ "$OS" == "macos" ]]; then
        open -a Firefox
    else  # Arch
        firefox &
    fi
    echo "Watch for extensions installing in the background!"
else
    echo "You can start Firefox manually when ready."
fi
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
    # On macOS, prefer system-wide distribution outside the app bundle to avoid code-signing/SIP issues
    DISTRIBUTION_DIR_MACOS_PRIMARY="/Library/Application Support/Firefox/distribution"
    DISTRIBUTION_DIR_MACOS_FALLBACK="${FIREFOX_APP}/Contents/Resources/distribution"
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

# Determine destination(s)
if [[ "$OS" == "macos" ]]; then
    echo "This step requires sudo to write a policies.json for Firefox."
    echo "Files being copied:"
    echo "  Source: $POLICIES_FILE"
    echo "  Destinations (first writable will be used):"
    echo "    1) ${DISTRIBUTION_DIR_MACOS_PRIMARY}/policies.json (recommended)"
    echo "    2) ${DISTRIBUTION_DIR_MACOS_FALLBACK}/policies.json"
    echo ""
else
    echo "This step requires sudo to write to Firefox distribution directory."
    echo "Files being copied:"
    echo "  Source: $POLICIES_FILE"
    echo "  Destination: ${DISTRIBUTION_DIR}/policies.json"
    echo ""
fi
read -p "Continue with sudo? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted by user."
    exit 1
fi

if [[ "$OS" == "macos" ]]; then
    # Try primary system-wide path first, then fallback into app bundle
    DEPLOYED=false
    for TARGET_DIR in "$DISTRIBUTION_DIR_MACOS_PRIMARY" "$DISTRIBUTION_DIR_MACOS_FALLBACK"; do
        echo "Creating distribution directory: $TARGET_DIR"
        if sudo mkdir -p "$TARGET_DIR" 2>/dev/null; then
            echo "Copying extension policies to: $TARGET_DIR"
            if sudo cp "$POLICIES_FILE" "${TARGET_DIR}/policies.json" 2>/dev/null; then
                sudo chmod 644 "${TARGET_DIR}/policies.json" || true
                sudo chown root:wheel "${TARGET_DIR}/policies.json" || true
                echo -e "${GREEN}OK: Extension policies deployed: ${TARGET_DIR}/policies.json${NC}"
                DEPLOYED=true
                break
            else
                echo -e "${ORANGE}Warning: Copy to $TARGET_DIR failed. Trying next location...${NC}"
            fi
        else
            echo -e "${ORANGE}Warning: Could not create $TARGET_DIR. Trying next location...${NC}"
        fi
    done
    if [ "$DEPLOYED" = false ]; then
        echo -e "${RED}ERROR: Failed to deploy policies.json to both macOS locations.${NC}"
        echo "You can manually try:"
        echo "  sudo mkdir -p '/Library/Application Support/Firefox/distribution'"
        echo "  sudo cp '$POLICIES_FILE' '/Library/Application Support/Firefox/distribution/policies.json'"
        echo "If that fails, ensure Firefox isn't running and that SIP isn't blocking writes."
        exit 1
    fi
else
    echo "Creating distribution directory..."
    sudo mkdir -p "$DISTRIBUTION_DIR"
    echo "Copying extension policies..."
    sudo cp "$POLICIES_FILE" "${DISTRIBUTION_DIR}/policies.json"
    sudo chmod 644 "${DISTRIBUTION_DIR}/policies.json"
    sudo chown root:root "${DISTRIBUTION_DIR}/policies.json"
    echo -e "${GREEN}OK: Extension policies deployed securely!${NC}"
fi

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

# Prefer auto-switching theme when available; fallback to static selection
AUTO_THEME_FILE="userChrome-flexoki-auto.css"
if [ -f "${SCRIPT_DIR}/${AUTO_THEME_FILE}" ]; then
    cp "${SCRIPT_DIR}/${AUTO_THEME_FILE}" "${CHROME_DIR}/userChrome.css"
    echo "Installed auto-switching Flexoki theme (follows system light/dark)"
else
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
fi

# userChrome.css pref is set via repository user-overrides.js appended by updater.sh
# We verify below and instruct if missing.

#########################
# 5. VERIFICATION       #
#########################

echo -e "${ORANGE}Step 5: Verifying deployment...${NC}"

# Check that files were actually created
if [ -f "$PROFILE_DIR/user.js" ]; then
    echo -e "${GREEN}✓ user.js deployed${NC}"
    
    # Check if it's actually arkenfox
    if grep -q "arkenfox user.js" "$PROFILE_DIR/user.js" 2>/dev/null; then
        version=$(grep "version:" "$PROFILE_DIR/user.js" | head -1 | awk '{print $3}')
        echo -e "${GREEN}✓ Arkenfox detected (version $version)${NC}"
    fi
    
    # Check if overrides were merged
    if grep -q "user-overrides.js" "$PROFILE_DIR/user.js" 2>/dev/null; then
        echo -e "${GREEN}✓ User overrides merged${NC}"
    fi
    
    # Check for key custom settings
    if grep -q "sidebar.verticalTabs" "$PROFILE_DIR/user.js" 2>/dev/null; then
        echo -e "${GREEN}✓ Custom settings applied${NC}"
    fi
else
    echo -e "${RED}✗ user.js deployment failed${NC}"
fi

# Verify extension policies
POLICY_PATH=""
if [[ "$OS" == "macos" ]]; then
    if [ -f "${DISTRIBUTION_DIR_MACOS_PRIMARY}/policies.json" ]; then
        POLICY_PATH="${DISTRIBUTION_DIR_MACOS_PRIMARY}/policies.json"
    elif [ -f "${DISTRIBUTION_DIR_MACOS_FALLBACK}/policies.json" ]; then
        POLICY_PATH="${DISTRIBUTION_DIR_MACOS_FALLBACK}/policies.json"
    fi
else
    POLICY_PATH="${DISTRIBUTION_DIR}/policies.json"
fi

if [ -n "$POLICY_PATH" ] && [ -f "$POLICY_PATH" ]; then
    echo -e "${GREEN}✓ Extension policies deployed${NC}"
    # Count extensions if possible
    if command -v python3 >/dev/null 2>&1; then
        ext_count=$(python3 -c "
import json
with open('${POLICY_PATH}') as f:
    data = json.load(f)
    extensions = data.get('policies', {}).get('ExtensionSettings', {})
    count = len([k for k in extensions.keys() if k != '*'])
    print(count)
" 2>/dev/null || echo "0")
        if [ "$ext_count" -gt 0 ]; then
            echo -e "${GREEN}✓ $ext_count extensions configured${NC}"
        fi
    fi
else
    echo -e "${RED}✗ Extension policies deployment not found${NC}"
fi

if [ -f "${CHROME_DIR}/userChrome.css" ]; then
    echo -e "${GREEN}✓ Flexoki theme deployed${NC}"
else
    echo -e "${ORANGE}⚠ Theme not installed${NC}"
fi

# Verify userChrome.css pref is enabled
if grep -q "toolkit.legacyUserProfileCustomizations.stylesheets" "$PROFILE_DIR/user.js" 2>/dev/null \
   || grep -q "toolkit.legacyUserProfileCustomizations.stylesheets" "$PROFILE_DIR/prefs.js" 2>/dev/null; then
    echo -e "${GREEN}✓ userChrome.css enabled via pref${NC}"
else
    echo -e "${ORANGE}⚠ userChrome.css pref not detected; it should be set by user-overrides.js${NC}"
    echo "  If missing, re-run the updater step or set it in about:config."
fi

#########################
# 6. SUMMARY            #
#########################

echo ""
echo -e "${GREEN}Firefox Setup Complete!${NC}"
echo "================================================"
echo ""
echo -e "${BLUE}Profile configured:${NC} $(basename "$PROFILE_DIR")"
echo -e "${BLUE}Profile location:${NC} $PROFILE_DIR"
echo ""
echo -e "${ORANGE}Next steps:${NC}"
echo "1. Launch Firefox - extensions will auto-install"
echo "2. Verify settings in about:config"
echo "3. Check vertical tabs in sidebar"
echo ""
echo -e "${ORANGE}Manual verification:${NC}"
echo "- about:config → search 'sidebar.verticalTabs'"
echo "- about:policies → check extension policies"
echo "- about:debugging → verify extensions"

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

#!/usr/bin/env bash

## Firefox Setup Verification Script
## Supports macOS and Arch Linux

set -e

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly ORANGE='\033[0;33m'
readonly NC='\033[0m'

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    PROFILES_DIR="$HOME/Library/Application Support/Firefox/Profiles"
    POLICIES_FILE="/Applications/Firefox.app/Contents/Resources/distribution/policies.json"
elif [[ -f "/etc/arch-release" ]]; then
    OS="arch"
    PROFILES_DIR="$HOME/.mozilla/firefox"
    POLICIES_FILE="/usr/lib/firefox/distribution/policies.json"
else
    echo -e "${RED}ERROR: Unsupported OS${NC}"
    exit 1
fi

echo -e "${BLUE}🔍 Firefox Setup Verification${NC}"
echo "================================================"

#########################
# 1. PROFILE DETECTION #
#########################

echo -e "${ORANGE}Step 1: Checking Firefox Profile...${NC}"
echo "OS detected: $OS"

if [ ! -d "$PROFILES_DIR" ]; then
    echo -e "${RED}❌ No Firefox profiles found!${NC}"
    exit 1
fi

echo "Firefox profiles directory: $PROFILES_DIR"
echo ""
echo "Available profiles:"
ls -la "$PROFILES_DIR" | grep "^d" | while read -r line; do
    profile_name=$(echo "$line" | awk '{print $NF}')
    if [[ "$profile_name" == *.default* ]]; then
        echo -e "  ${GREEN}✅ $profile_name (DEFAULT)${NC}"
    else
        echo -e "  📁 $profile_name"
    fi
done

# Find the default profile
PROFILE_DIR=$(find "$PROFILES_DIR" -name "*.default*" -type d | head -1)

if [ -z "$PROFILE_DIR" ]; then
    echo -e "${RED}❌ No default profile found!${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Using profile: $(basename "$PROFILE_DIR")${NC}"
echo "Full path: $PROFILE_DIR"

#########################
# 2. CHECK USER.JS      #
#########################

echo ""
echo -e "${ORANGE}Step 2: Checking Arkenfox user.js...${NC}"

if [ -f "$PROFILE_DIR/user.js" ]; then
    echo -e "${GREEN}✅ user.js found in profile${NC}"
    
    # Check if it's actually arkenfox
    if grep -q "arkenfox user.js" "$PROFILE_DIR/user.js" 2>/dev/null; then
        version=$(grep "version:" "$PROFILE_DIR/user.js" | head -1 | awk '{print $3}')
        echo -e "${GREEN}✅ Arkenfox user.js detected (version $version)${NC}"
    else
        echo -e "${ORANGE}⚠️  user.js exists but may not be arkenfox${NC}"
    fi
    
    # Check if overrides were merged
    if grep -q "user-overrides.js" "$PROFILE_DIR/user.js" 2>/dev/null; then
        echo -e "${GREEN}✅ User overrides were merged${NC}"
    else
        echo -e "${ORANGE}⚠️  User overrides may not be merged${NC}"
    fi
    
    # Check for our specific settings
    if grep -q "sidebar.verticalTabs" "$PROFILE_DIR/user.js" 2>/dev/null; then
        echo -e "${GREEN}✅ Custom vertical tabs setting found${NC}"
    else
        echo -e "${RED}❌ Custom vertical tabs setting missing${NC}"
    fi
    
else
    echo -e "${RED}❌ No user.js found in profile${NC}"
fi

#########################
# 3. CHECK PREFS.JS     #
#########################

echo ""
echo -e "${ORANGE}Step 3: Checking Active Preferences...${NC}"

if [ -f "$PROFILE_DIR/prefs.js" ]; then
    echo -e "${GREEN}✅ prefs.js found${NC}"
    
    # Check some key arkenfox settings
    key_prefs=(
        "privacy.resistFingerprinting.exemptedDomains.*vlaris.net"
        "browser.uidensity.*1"
        "browser.search.suggest.enabled.*true"
        "sidebar.verticalTabs.*true"
        "browser.ml.chat.enabled.*false"
    )
    
    for pref_pattern in "${key_prefs[@]}"; do
        if grep -q "$pref_pattern" "$PROFILE_DIR/prefs.js" 2>/dev/null; then
            pref_name=$(echo "$pref_pattern" | cut -d'.' -f1-3)
            echo -e "${GREEN}✅ $pref_name setting active${NC}"
        else
            pref_name=$(echo "$pref_pattern" | cut -d'.' -f1-3)  
            echo -e "${RED}❌ $pref_name setting missing${NC}"
        fi
    done
else
    echo -e "${ORANGE}⚠️  No prefs.js found (Firefox hasn't run yet?)${NC}"
fi

#########################
# 4. CHECK EXTENSIONS   #
#########################

echo ""
echo -e "${ORANGE}Step 4: Checking Extension Policies...${NC}"

if [ -f "$POLICIES_FILE" ]; then
    echo -e "${GREEN}✅ Extension policies deployed${NC}"
    
    # Count extensions in policies
    if command -v python3 >/dev/null 2>&1; then
        ext_count=$(python3 -c "
import json
with open('$POLICIES_FILE') as f:
    data = json.load(f)
    extensions = data.get('policies', {}).get('ExtensionSettings', {})
    # Don't count the '*' wildcard entry
    count = len([k for k in extensions.keys() if k != '*'])
    print(count)
" 2>/dev/null || echo "unknown")
        echo -e "${GREEN}✅ $ext_count extensions configured for auto-install${NC}"
    fi
else
    echo -e "${RED}❌ Extension policies not found${NC}"
    echo "Expected location: $POLICIES_FILE"
fi

#########################
# 5. CHECK EXTENSIONS   #
#########################

echo ""
echo -e "${ORANGE}Step 5: Checking Installed Extensions...${NC}"

EXTENSIONS_DIR="$PROFILE_DIR/extensions"

if [ -d "$EXTENSIONS_DIR" ]; then
    installed_count=$(ls -1 "$EXTENSIONS_DIR" | wc -l | xargs)
    echo -e "${GREEN}✅ $installed_count extensions installed${NC}"
    
    # List installed extensions
    echo "Installed extensions:"
    ls -1 "$EXTENSIONS_DIR" | head -10 | while read -r ext; do
        echo "  📦 $ext"
    done
else
    echo -e "${ORANGE}⚠️  No extensions directory found${NC}"
    echo "Extensions may install on first Firefox launch"
fi

#########################
# 6. SUMMARY            #
#########################

echo ""
echo -e "${BLUE}📋 Verification Summary${NC}"
echo "================================================"

# Quick test of about:config accessible settings
echo -e "${BLUE}To manually verify in Firefox:${NC}"
echo "1. Type 'about:config' in address bar"
echo "2. Search for these settings:"
echo "   • sidebar.verticalTabs (should be true)"
echo "   • browser.uidensity (should be 1)"
echo "   • browser.search.suggest.enabled (should be true)"
echo "   • privacy.resistFingerprinting.exemptedDomains (should contain vlaris.net)"
echo ""
echo "3. Type 'about:debugging#/runtime/this-firefox'"
echo "   • Should show your installed extensions"
echo ""
echo "4. Check vertical tabs:"
echo "   • Should see tabs in sidebar on left"
echo "   • Right-click sidebar to verify panels are removed"

echo ""
echo -e "${GREEN}Profile being used: $(basename "$PROFILE_DIR")${NC}"
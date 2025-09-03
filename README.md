# Firefox Configuration

Privacy-hardened Firefox setup using [arkenfox user.js](https://github.com/arkenfox/user.js) with custom overrides optimized for usability.

**Supported:** macOS, Arch Linux  
**Firefox Versions:** 115+ ESR, Latest Release

## Quick Start

```bash
git clone <this-repo>
cd firefox-config
./deploy.sh
```

The script:
- Downloads latest arkenfox files
- Creates Firefox profile if needed
- Installs extension policies
- Applies custom overrides
- Sets up Flexoki theme

## Components

### Base Configuration (Arkenfox)
- Privacy-focused defaults blocking tracking/fingerprinting
- Hardened TLS/SSL settings
- Disabled telemetry and data collection
- HTTPS enforcement where possible

### Custom Overrides
Key modifications in `user-overrides.js`:

**Session Management**
- Keeps tabs on restart (vs arkenfox clearing)
- Preserves history and cookies
- Maintains form data

**Compatibility**
- vlaris.net exempted from fingerprinting protection
- Kagi search suggestions enabled
- WebGL and canvas access for specific sites

**Performance**
- HTTP/3 enabled
- Increased connection limits (900 max, 30 per server)
- JIT optimizations enabled
- Accessibility services disabled (re-enable if needed)

**UI/UX**
- Native vertical tabs in sidebar
- Compact density mode
- Bookmarks toolbar always visible
- Dark theme for developer tools
- No hover delays on sidebar

### Extensions (Auto-Install)
Configured via `your-extensions-policies.json`:
- uBlock Origin - Ad/tracker blocking
- 1Password - Password management
- Kagi Search - Search engine integration
- linkding - Bookmark manager
- Obsidian Web Clipper - Note capture
- Harper Grammar - Grammar checking
- readeck - Read-later service
- SingleFile - Full page archival
- UnTrap for YouTube - Clean YouTube UI
- Dark Reader - Universal dark mode

### Theme
Flexoki color scheme (warm, paper-inspired):
- Auto: `userChrome-flexoki-auto.css` follows system light/dark via `prefers-color-scheme`
- Dark: `#100F0F` background (`userChrome-flexoki-dark.css`)
- Light: `#FFFCF0` background (`userChrome-flexoki-light.css`)
- Applied via `userChrome.css` in your profile's `chrome/` directory

## File Structure

```
Repository:
├── user-overrides.js                # Your custom preferences
├── your-extensions-policies.json    # Extension configuration
├── deploy.sh                        # Installation & verification script
├── userChrome-flexoki-auto.css      # Auto theme (light/dark via system)
├── userChrome-flexoki-dark.css     # Dark theme
└── userChrome-flexoki-light.css    # Light theme

Downloaded (not tracked):
├── user.js                          # Arkenfox base
├── updater.sh                       # Arkenfox updater
└── prefsCleaner.sh                  # Preference cleanup
```

## Installation

### Prerequisites

**macOS:**
- Firefox installed from [mozilla.org](https://www.mozilla.org/firefox/)
- Command line tools: `curl`, `bash`

**Arch Linux:**
- Firefox: `sudo pacman -S firefox`
- Standard tools already available

### Fresh Install

1. Clone repository
2. Run `./deploy.sh`
3. Script handles:
   - Profile creation if Firefox never launched
   - Arkenfox download and setup
   - Extension policy deployment (requires sudo)
   - Theme installation (auto-switching if available)
   - Automatic verification of deployment
4. Launch Firefox - extensions install on first run

### Verification

The deploy script automatically verifies the installation.

For manual verification in Firefox:
- `about:config` - Check key preferences
- Settings → General → Website appearance: set “Automatic” to let sites follow light/dark
- `about:debugging` - Verify extensions
- `about:profiles` - Confirm correct profile

### Auto Light/Dark Switching

- The deploy script installs `userChrome-flexoki-auto.css` as `userChrome.css` when present.
- Firefox UI switches live with your OS appearance on macOS and most modern Linux DEs.
- If your Linux DE doesn’t propagate `prefers-color-scheme`, the script falls back to a static theme based on `~/.config/themes/current` containing the word "light" or defaults to dark.

## Maintenance

### Update Arkenfox

When arkenfox releases updates (monitor via RSS):

```bash
./updater.sh -s              # Silent update
# Test Firefox functionality
# Adjust user-overrides.js if needed
git commit -am "Update overrides for arkenfox vXXX"
```

### Clean Obsolete Preferences

Before major Firefox updates:

```bash
./prefsCleaner.sh
```

### Modify Settings

**Add custom preferences:**
```javascript
// In user-overrides.js
user_pref("browser.preference.name", value);
```

**Add extensions:**
```json
// In your-extensions-policies.json
"extension-id@developer": {
  "installation_mode": "normal_installed",
  "install_url": "https://addons.mozilla.org/firefox/downloads/latest/..."
}
```

Get extension IDs from `about:debugging#/runtime/this-firefox`

## Troubleshooting

### Profile Issues

**Wrong profile loading:**
```bash
firefox -P              # Profile manager
about:profiles          # In Firefox
```

**Profile not found:**
- macOS: Check `~/Library/Application Support/Firefox/Profiles/`
- Linux: Check `~/.mozilla/firefox/`

### Extension Issues

**Not auto-installing:**
- Verify policies.json exists:
  - macOS: `/Applications/Firefox.app/Contents/Resources/distribution/`
  - Arch: `/usr/lib/firefox/distribution/`
- Extensions only install on FIRST launch after policy deployment
- Check `about:policies` for active policies

**Manual install fallback:**
- Visit extension URLs in `your-extensions-policies.json`
- Install directly from addons.mozilla.org

### Site Compatibility

**Broken functionality:**
1. Click shield icon in address bar
2. Turn off Enhanced Tracking Protection for site
3. Or add to `privacy.resistFingerprinting.exemptedDomains`

**Canvas/WebGL issues:**
- Check `user-overrides.js` for canvas permissions
- Some sites need explicit canvas access prompts

**Video/Audio problems:**
- WebRTC is disabled by default
- Enable per-site if needed for video calls

### Performance

**Slow startup:**
- Normal with many extensions
- First launch after updates slower
- Consider reducing extension count

**High memory usage:**
- Check `about:memory` for details
- Arkenfox disables some memory optimizations for privacy
- Adjust `browser.cache.memory.capacity` if needed

## Technical Details

### Arkenfox Integration

The setup uses arkenfox's updater mechanism:
1. Downloads latest user.js from GitHub
2. Appends user-overrides.js
3. Deploys merged configuration to profile

This maintains arkenfox's security improvements while preserving customizations.

### Policy Deployment

Extension policies use Firefox's enterprise policy system:
- macOS (preferred): `/Library/Application Support/Firefox/distribution/policies.json`
- macOS (alt within app): `/Applications/Firefox.app/Contents/Resources/distribution/policies.json`
- Arch Linux: `/usr/lib/firefox/distribution/policies.json`
- Requires sudo/admin access; applies to all profiles on the system

### Profile Management

Script handles multiple scenarios:
- Existing profiles: Uses first *.default* profile
- No profiles: Creates new profile via `-CreateProfile`
- Never-run Firefox: Sets up profiles.ini correctly

## Security Notes

### What This Protects Against
- Fingerprinting (with exceptions for specific sites)
- Tracking cookies and beacons
- Telemetry and usage analytics
- Insecure connections
- WebRTC IP leaks

### Trade-offs Made
- Some fingerprinting protection disabled for usability
- Session data preserved (less privacy, more convenience)
- JIT enabled (performance over security)
- Search suggestions enabled (Kagi only)

### Recommendations
- Use different profiles for different threat models
- Enable RFP (ResistFingerprinting) for maximum privacy
- Review arkenfox wiki for additional hardening options
- Keep Firefox and arkenfox updated regularly

## References

- [Arkenfox Wiki](https://github.com/arkenfox/user.js/wiki) - Detailed explanations
- [Firefox Enterprise Policies](https://mozilla.github.io/policy-templates/) - Policy documentation
- [Flexoki Theme](https://github.com/kepano/flexoki) - Color scheme details
- [Betterfox](https://github.com/yokoffing/Betterfox) - Performance tweaks source

# Personal Firefox Setup

Hardened Firefox configuration using [arkenfox user.js](https://github.com/arkenfox/user.js) with custom overrides for usability and performance.

**Supported Systems:** macOS and Arch Linux

## 🚀 Quick Setup

**New machine deployment:**
```bash
git clone <this-repo>
cd firefox-config
./deploy-firefox-setup-secure.sh  # Works on macOS and Arch Linux
```

**Update arkenfox (preserves your settings):**
```bash
# The updater.sh is downloaded during deployment
./updater.sh -s
```

## 📋 What This Setup Does

### 🔒 Security & Privacy (from arkenfox)
- Blocks fingerprinting and tracking
- Hardens TLS/SSL settings
- Disables telemetry and data collection
- Enforces HTTPS where possible

### ⚙️ Custom Overrides (for usability)
- **Session restore**: Remembers tabs on restart
- **Keep browsing data**: History and cookies preserved
- **Search integration**: Kagi search suggestions enabled
- **Site compatibility**: vlaris.net fingerprinting exemption

### 🚀 Performance Optimizations
- Increased HTTP connection limits
- Enhanced memory and cache settings
- Disabled accessibility features (unless needed)
- Faster rendering and JavaScript performance

### 🎨 UI Customizations
- **Vertical tabs**: Mozilla's native sidebar tabs
- **Compact mode**: Smaller UI elements
- **Instant sidebar**: No hover animation delays
- **Bookmarks toolbar**: Always visible
- **Dark dev tools**: Developer tools use dark theme

### 📦 Auto-Installed Extensions (10)
- **uBlock Origin** - Ad blocker
- **1Password** - Password manager  
- **Kagi Search** - Search integration
- **linkding** - Bookmark manager
- **Obsidian Web Clipper** - Save to Obsidian
- **Harper Grammar** - Grammar checker
- **readeck** - Read-later service
- **SingleFile** - Save complete pages
- **UnTrap for YouTube** - Clean YouTube experience
- **Dark Reader** - Universal dark mode

## 📁 File Structure

```
# Your repo (tracked in git):
├── user-overrides.js                # Your custom settings (persistent)
├── your-extensions-policies.json    # Extension auto-install config
├── deploy-firefox-setup-secure.sh   # Deployment script (downloads arkenfox)
├── verify-setup.sh                  # Verify deployment worked
├── userChrome-flexoki-dark.css      # Dark theme
└── userChrome-flexoki-light.css     # Light theme

# Downloaded during deployment (not in git):
├── user.js                          # Arkenfox base (auto-downloaded)
├── updater.sh                       # Update arkenfox (from arkenfox repo)
└── prefsCleaner.sh                  # Clean old prefs (from arkenfox repo)
```

## 🔧 Usage

### Initial Setup

**macOS:**
1. Install Firefox from [mozilla.org](https://www.mozilla.org/firefox/)
2. Clone this repo: `git clone <your-repo-url>`
3. Run `./deploy-firefox-setup-secure.sh`
4. Launch Firefox (extensions install automatically)

**Arch Linux:**
1. Install Firefox: `sudo pacman -S firefox`
2. Clone this repo: `git clone <your-repo-url>`
3. Run `./deploy-firefox-setup-secure.sh`
4. Launch Firefox (extensions install automatically)

**Note:** The script handles fresh Firefox installs that have never been launched.

### Updates
```bash
# Update arkenfox user.js (monthly recommended)
./updater.sh -s

# Before major Firefox updates, clean old prefs
./prefsCleaner.sh
```

### Verification
```bash
# Check if everything deployed correctly
./verify-setup.sh
```

## 🛠️ Customization

### Adding Firefox Preferences
Edit `user-overrides.js` and add:
```javascript
user_pref("preference.name", value);
```

### Adding Extensions
1. Get extension ID from `about:debugging#/runtime/this-firefox`
2. Add to `your-extensions-policies.json`:
```json
"extension-id@domain.com": {
  "installation_mode": "normal_installed", 
  "install_url": "https://addons.mozilla.org/firefox/downloads/latest/extension-name/latest.xpi"
}
```

### Site-Specific Issues
- **Broken site**: Click shield icon → Disable Enhanced Tracking Protection
- **Canvas errors**: Allow site exceptions when prompted
- **SSL errors**: Check user-overrides.js for commented fixes

## 🔍 Key Settings Explained

### Privacy vs Usability Balance
- **RFP disabled globally** but **FPP enabled** (better site compatibility)
- **vlaris.net exempted** from fingerprinting protection
- **Session data kept** (contrary to arkenfox defaults)
- **Search suggestions enabled** for Kagi only

### Performance vs Security
- **Accessibility disabled** (re-enable if using screen readers)
- **Network optimizations** for faster loading
- **JIT compilation enabled** (performance over security)

## 🆘 Troubleshooting

### Extensions not installing
- Check: `/Applications/Firefox.app/Contents/Resources/distribution/policies.json`
- Extensions install on FIRST launch only

### Settings not applying  
- Verify: `user.js` exists in Firefox profile
- Check: `about:profiles` for correct profile usage

### Site compatibility issues
- Use shield icon to disable protection per-site
- Check arkenfox wiki for common fixes

## 📚 References

- [arkenfox user.js](https://github.com/arkenfox/user.js) - Base privacy configuration
- [Betterfox](https://github.com/yokoffing/Betterfox) - Performance optimizations inspiration
- [Firefox Enterprise Policies](https://mozilla.github.io/policy-templates/) - Extension deployment

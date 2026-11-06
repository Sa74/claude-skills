# Distribution, Release Management & CI/CD — Principal Apple Engineer Reference

**Scope:** Multi-platform distribution (iOS, macOS, watchOS, tvOS, visionOS), code signing, notarization, App Store submission, CI/CD automation, release workflows, post-release monitoring.

---

## 0. System Extension Bundle Path (CRITICAL)

When distributing apps with System Extensions (DriverKit, Network Extension, Endpoint Security),
the `.systemextension` bundle MUST be embedded at this exact path:

```
YourApp.app/Contents/Library/SystemExtensions/com.yourcompany.extension.systemextension
```

In Xcode, add a **Copy Files** build phase with destination **System Extensions** or use
the "Embed System Extensions" build phase. Both distribution paths (DMG and App Store) require
this exact location. If the extension is not at `Contents/Library/SystemExtensions/`, the
`OSSystemExtensionManager` will fail to find it.

For apps with System Extensions, both DMG and App Store variants MUST:
- Code-sign the extension with its own signing identity and provisioning profile
- Include the `com.apple.developer.system-extension.install` entitlement in the app
- Request Apple-specific entitlements (Network Extension, Endpoint Security) separately

---

## 1. macOS Dual-Path Distribution Strategy

### 1.1 DMG (Developer ID Path)
**Audience:** Power users, enterprise, direct download distribution.

**Characteristics:**
- Unsigned or Developer ID signed
- Notarization required for Gatekeeper bypass (macOS 10.15+)
- No sandbox required (but recommended)
- Full system access; user grants permissions at install

**Advantages:** Full capabilities, no App Store review delay, direct user relationship.
**Disadvantages:** No automatic updates (unless built-in), security responsibility, manual distribution.

### 1.2 Mac App Store Path
**Audience:** Mainstream users, discoverability priority.

**Characteristics:**
- Mandatory sandbox; entitlements-driven capability
- Apple Distribution certificate required
- No notarization (Apple handles codesigning verification)
- App Store review process; phased rollout support
- Automatic updates via App Store

**Advantages:** Automatic updates, discovery, trust signal, payment processing.
**Disadvantages:** Review delays, sandbox restrictions, revenue split (70/30).

### 1.3 Hybrid Approach: Maintain Both
```bash
# Build configurations in Xcode:
# - Release_DMG: Developer ID signing, no sandbox constraints
# - Release_AppStore: Apple Distribution, strict sandbox entitlements

# Scheme settings: different signing identities per configuration
# Post-build: DMG path diverges at export phase
```

---

## 2. Code Signing Architecture

### 2.1 Certificate Types & Provisioning
```
Developer ID Application Certificate
├─ Signing binaries for DMG distribution
├─ Valid for 5 years
└─ Tied to Team ID; revocation handled by Apple

Apple Distribution Certificate (App Store)
├─ Provisioning for App Store apps
├─ Valid for 1 year
└─ Requires in-house Apple Developer account

Mac Development Certificate
├─ For local development and internal testing
└─ Allows full disk access during testing

Ad Hoc Provisioning Profile (macOS)
├─ Internal enterprise distribution
├─ Limited to specific hardware (UUID-bound)
└─ No App Store review required
```

### 2.2 Code Signing Configuration
```swift
// Build Settings in Xcode or xcconfig:

// DMG Release Configuration
CODE_SIGN_IDENTITY[config=Release_DMG] = Developer ID Application: Company Name (TEAM123ABC)
PROVISIONING_PROFILE[config=Release_DMG] =
CODE_SIGN_STYLE = Manual  // Explicit control over signing

// App Store Release Configuration
CODE_SIGN_IDENTITY[config=Release_AppStore] = Apple Distribution (TEAM123ABC)
PROVISIONING_PROFILE[config=Release_AppStore] = Mac App Store Provisioning Profile
CODE_SIGN_STYLE = Automatic  // Or Manual for tighter control

// Both configurations
DEVELOPMENT_TEAM = TEAM123ABC
ENABLE_HARDENED_RUNTIME = YES
```

### 2.3 Multi-Target Signing Pattern
```bash
#!/bin/bash
# sign-all-targets.sh: Ensures consistent signing across framework + app

set -euo pipefail

TEAM_ID="TEAM123ABC"
DMG_IDENTITY="Developer ID Application: Company Name (${TEAM_ID})"
APPSTORE_IDENTITY="Apple Distribution (${TEAM_ID})"

function sign_framework() {
    local framework=$1
    local identity=$2
    echo "Signing framework: $framework with $identity"
    codesign --force --verify --verbose --sign "$identity" \
        --options=runtime \
        --timestamp \
        "$framework"
}

function sign_app() {
    local app=$1
    local identity=$2
    echo "Signing app: $app with $identity"

    # Sign nested frameworks first
    for fw in "$app/Contents/Frameworks"/*.framework; do
        sign_framework "$fw" "$identity"
    done

    # Sign main app
    codesign --force --verify --verbose --sign "$identity" \
        --options=runtime \
        --timestamp \
        --entitlements=entitlements.plist \
        "$app"
}

case "${1:-dmg}" in
    dmg)
        sign_app "build/Release_DMG/MyApp.app" "$DMG_IDENTITY"
        ;;
    appstore)
        sign_app "build/Release_AppStore/MyApp.app" "$APPSTORE_IDENTITY"
        ;;
esac
```

---

## 3. Sandboxing & Entitlements

### 3.1 Entitlements Configuration
App Store requires sandbox; DMG should adopt it for security.

```xml
<!-- entitlements-base.plist: Shared base -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Common entitlements -->
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <false/>
</dict>
</plist>

<!-- entitlements-dmg.plist: Developer ID extras (fewer restrictions) -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>  <!-- No sandbox for DMG if full capabilities needed -->
    <key>com.apple.security.device.usb</key>
    <true/>
    <key>com.apple.security.device.serial</key>
    <true/>
</dict>
</plist>

<!-- entitlements-appstore.plist: Strict sandbox for App Store -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.temporary-exception.mach-lookup.global-name</key>
    <array>
        <string>com.apple.bird</string>  <!-- Example: iCloud container access -->
    </array>
</dict>
</plist>
```

### 3.2 Security-Scoped Bookmarks (File Access)
```swift
// macOS sandboxed file access with persistent URLs

import Foundation

class FileAccessManager {
    static let shared = FileAccessManager()

    // Store security-scoped bookmark data in UserDefaults or Keychain
    private let bookmarkKey = "fileAccessBookmark"

    // Request file access (user picks file)
    func requestFileAccess() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        // Create security-scoped bookmark
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            // Persist bookmark
            UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
            return url
        } catch {
            print("Bookmark creation failed: \(error)")
            return nil
        }
    }

    // Retrieve file access with bookmark
    func resolveSecuredURL() -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) else {
            return nil
        }

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                // Refresh bookmark if stale
                let newBookmarkData = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                UserDefaults.standard.set(newBookmarkData, forKey: bookmarkKey)
            }

            // Start accessing the resource
            _ = url.startAccessingSecurityScopedResource()
            return url
        } catch {
            print("Bookmark resolution failed: \(error)")
            return nil
        }
    }
}
```

---

## 4. Notarization Workflow (macOS)

### 4.1 Notarization Build & Upload
```bash
#!/bin/bash
# notarize.sh: Complete notarization workflow

set -euo pipefail

APP_PATH="$1"
BUNDLE_ID="com.company.appname"
TEAM_ID="TEAM123ABC"
APPLE_ID="developer@company.com"
APP_PASSWORD="@keychain:AC_PASSWORD"  # App-specific password in keychain
PRIMARY_BUNDLE_ID="$BUNDLE_ID"

function log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log "Step 1: Create application archive"
zip -r -q "app-archive.zip" "$APP_PATH"

log "Step 2: Submit to notarization service"
NOTARIZE_RESULT=$(xcrun notarytool submit "app-archive.zip" \
    --apple-id "$APPLE_ID" \
    --password "$APP_PASSWORD" \
    --team-id "$TEAM_ID" \
    --wait \
    --output-format json)

SUBMISSION_ID=$(echo "$NOTARIZE_RESULT" | jq -r '.id')
STATUS=$(echo "$NOTARIZE_RESULT" | jq -r '.status')

log "Submission ID: $SUBMISSION_ID, Status: $STATUS"

if [ "$STATUS" != "Accepted" ]; then
    log "ERROR: Notarization failed. Full response:"
    echo "$NOTARIZE_RESULT" | jq '.'
    exit 1
fi

log "Step 3: Fetch notarization ticket"
xcrun notarytool log "$SUBMISSION_ID" \
    --apple-id "$APPLE_ID" \
    --password "$APP_PASSWORD" \
    --team-id "$TEAM_ID" \
    > notarization-log.json

log "Step 4: Staple ticket to app"
xcrun stapler staple "$APP_PATH"

log "Step 5: Verify staple"
xcrun stapler validate "$APP_PATH"

log "SUCCESS: App notarized and stapled"
```

### 4.2 Notarization via Xcode Build Settings
```bash
# Build post-processing in Xcode Run Script phase:

NOTARIZE_ARCHIVE_PATH="${BUILT_PRODUCTS_DIR}/${EXECUTABLE_NAME}-${MARKETING_VERSION}.zip"

if [ "$CONFIGURATION" = "Release_DMG" ]; then
    # Archive the app
    ditto -c -k --sequesterRsrc --keepParent \
        "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_NAME}.app" \
        "$NOTARIZE_ARCHIVE_PATH"

    # Notarize and wait (blocking)
    SUBMISSION_ID=$(xcrun notarytool submit "$NOTARIZE_ARCHIVE_PATH" \
        --apple-id "${APPLE_ID}" \
        --password "@keychain:APP_PASSWORD" \
        --team-id "${TEAM_ID}" \
        --wait \
        --output-format json | jq -r '.id')

    # Staple to app
    xcrun stapler staple "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_NAME}.app"
fi
```

---

## 5. DMG Creation & Distribution

### 5.1 hdiutil-Based DMG Creation
```bash
#!/bin/bash
# create-dmg.sh: Professional DMG creation with custom layout

set -euo pipefail

APP_NAME="MyApp"
APP_PATH="build/Release_DMG/${APP_NAME}.app"
DMG_PATH="dist/${APP_NAME}-${VERSION}.dmg"
DMG_VOLUME_NAME="${APP_NAME}"
DMG_BACKGROUND="assets/dmg-background.png"

# Create temporary directory
TEMP_DIR=$(mktemp -d)
DMG_TEMP_DIR="$TEMP_DIR/dmg"
mkdir -p "$DMG_TEMP_DIR"

# Copy app and create symlink to /Applications
cp -R "$APP_PATH" "$DMG_TEMP_DIR/"
ln -s /Applications "$DMG_TEMP_DIR/Applications"

# Create DMG with hdiutil
hdiutil create -volname "$DMG_VOLUME_NAME" \
    -srcfolder "$DMG_TEMP_DIR" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_PATH"

# Optional: Add custom background and layout via AppleScript
osascript <<EOF
tell application "Finder"
    tell disk "$DMG_VOLUME_NAME"
        open
        delay 1
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 600, 500}
        set opts to the icon view options of container window
        tell opts
            set icon size to 128
            set arrangement to not arranged
        end tell
        set background picture of opts to file ".background:dmg-background.png"

        -- Position icons
        set position of item "${APP_NAME}.app" of container window to {100, 300}
        set position of item "Applications" of container window to {400, 300}

        update without registering applications
        delay 2
        close
    end tell
end tell
EOF

# Compress for distribution
hdiutil convert "$DMG_PATH" \
    -format UDZO \
    -o "${DMG_PATH%.dmg}-final.dmg"

# Sign the DMG (optional but recommended)
codesign --sign "Developer ID Application: Company (TEAM123ABC)" \
    --timestamp \
    "${DMG_PATH%.dmg}-final.dmg"

echo "DMG created: ${DMG_PATH%.dmg}-final.dmg"
rm -rf "$TEMP_DIR"
```

### 5.2 create-dmg Node.js Alternative
```bash
# npm install create-dmg --save-dev

npx create-dmg \
    --identity="Developer ID Application: Company (TEAM123ABC)" \
    --sign-dmg \
    --overwrite \
    "build/Release_DMG/MyApp.app" \
    "dist/"
```

---

## 6. App Store Submission Pipeline

### 6.1 Export & Upload Automation
```bash
#!/bin/bash
# appstore-submit.sh: Build, export, and submit to App Store

set -euo pipefail

SCHEME="MyApp"
TEAM_ID="TEAM123ABC"
APPLE_ID="developer@company.com"
APP_PASSWORD="@keychain:APP_PASSWORD"
BUNDLE_ID="com.company.myapp"

VERSION=$(agvtool what-version -terse)
BUILD=$(agvtool what-build -terse)

echo "Building $SCHEME v$VERSION (build $BUILD)"

# Step 1: Build archive for App Store
xcodebuild -scheme "$SCHEME" \
    -configuration Release_AppStore \
    -archivePath "build/${SCHEME}.xcarchive" \
    archive

# Step 2: Export app using App Store export options
xcodebuild -exportArchive \
    -archivePath "build/${SCHEME}.xcarchive" \
    -exportOptionsPlist ExportOptions-AppStore.plist \
    -exportPath "build/AppStoreExport"

# Step 3: Upload using altool or Transporter
xcrun altool --upload-app \
    --file "build/AppStoreExport/${SCHEME}.ipa" \
    --type macos \
    --apple-id "$APPLE_ID" \
    --password "$APP_PASSWORD" \
    --team-id "$TEAM_ID" \
    --verbose

echo "Upload complete. Monitor at: https://appstoreconnect.apple.com"
```

### 6.2 Export Options Plist (App Store)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>teamID</key>
    <string>TEAM123ABC</string>
    <key>uploadSymbols</key>
    <true/>
    <key>uploadBitcode</key>
    <false/>  <!-- Deprecated for macOS -->
    <key>method</key>
    <string>app-store</string>
    <key>barcodeContentFileRequired</key>
    <false/>
    <key>destination</key>
    <string>export</string>
</dict>
</plist>
```

---

## 7. Multi-Platform Distribution

### 7.1 iOS App Store Only (with EU Sideloading)
```swift
// iOS: App Store is primary distribution
// EU: Support alternative app marketplace (Apple's requirement)

// In your app's distribution logic:
#if os(iOS)
    #if targetEnvironment(macCatalyst)
        // macOS via Catalyst: Support both App Store and DMG
    #else
        // Pure iOS: App Store only (EU sideloading handled by system)
    #endif
#endif
```

### 7.2 watchOS Bundled with iOS
```bash
#!/bin/bash
# Build watchOS app as embedded dependency of iOS app

# Step 1: Build watchOS app
xcodebuild -scheme "MyApp Watch" \
    -configuration Release \
    -sdk watchos \
    -derivedDataPath "build/watchos"

# Step 2: iOS build automatically includes WatchKit app
# (Configure in Xcode: General → Embedded Content)

# Step 3: Archive and export together
xcodebuild -scheme "MyApp" \
    -configuration Release \
    -archivePath "build/MyApp.xcarchive" \
    archive
```

### 7.3 Universal Purchase
```swift
// Enable cross-platform app purchases

import StoreKit

class UniversalPurchaseManager {
    func validatePurchaseAcrossApps() async {
        // SKReceiptRefreshRequest handles syncing across Apple ID
        let receipt = Bundle.main.appStoreReceiptURL

        // In App Store Connect: Set up Family Sharing or
        // Universal Purchase for automatic access across iOS/macOS
    }

    func restorePurchasesAcrossDevices() async {
        for await result in Transaction.all {
            if case .verified(let transaction) = result {
                // Update app state on all devices
                // via CloudKit or custom backend
                await updateAppState(for: transaction)
            }
        }
    }
}
```

---

## 8. TestFlight & Beta Distribution

### 8.1 TestFlight Internal & External Groups
```bash
#!/bin/bash
# Deploy build to TestFlight with group targeting

set -euo pipefail

APPLE_ID="developer@company.com"
APP_PASSWORD="@keychain:APP_PASSWORD"
TEAM_ID="TEAM123ABC"

# Build archive
xcodebuild -scheme "MyApp" \
    -configuration Release \
    -archivePath "build/MyApp.xcarchive" \
    archive

# Export for App Store (TestFlight)
xcodebuild -exportArchive \
    -archivePath "build/MyApp.xcarchive" \
    -exportOptionsPlist ExportOptions-AppStore.plist \
    -exportPath "build/TestFlightExport"

# Upload to TestFlight
xcrun altool --upload-app \
    --file "build/TestFlightExport/MyApp.ipa" \
    --type ios \
    --apple-id "$APPLE_ID" \
    --password "$APP_PASSWORD" \
    --team-id "$TEAM_ID"

echo "Build uploaded. Assign to testers in App Store Connect."
```

### 8.2 TestFlight Automation with Fastlane
```ruby
# fastlane/Fastfile: TestFlight distribution with feedback loop

default_platform(:ios)

platform :ios do
  desc "Build and upload to TestFlight"
  lane :beta do |options|
    build_number = options[:build] || increment_build_number

    build_app(
      workspace: "MyApp.xcworkspace",
      scheme: "MyApp",
      configuration: "Release",
      archive_path: "build/MyApp.xcarchive",
      export_method: "app-store",
      skip_package_ipa: true,
      upload_bitcode: false
    )

    upload_to_testflight(
      apple_id: ENV["APPLE_ID"],
      app_identifier: "com.company.myapp",
      team_id: ENV["TEAM_ID"],
      ipa: "MyApp.ipa",
      skip_waiting_for_build_processing: true,
      changelog: "Build #{build_number}: #{options[:changelog] || 'Internal testing'}"
    )

    # Notify testers
    slack(
      message: "TestFlight build #{build_number} available for internal testers",
      default_payloads: [:git_branch, :git_author]
    )
  end
end
```

---

## 9. Provisioning & Certificate Management

### 9.1 Certificate & Profile Renewal Automation
```bash
#!/bin/bash
# provision-renew.sh: Check expiry, renew if needed

set -euo pipefail

TEAM_ID="TEAM123ABC"
KEYCHAIN_PASSWORD="${KEYCHAIN_PASSWORD:-}"

function check_cert_expiry() {
    local cert_name=$1
    local days_threshold=30

    # Get certificate expiry from keychain
    security find-certificate -c "$cert_name" > /dev/null 2>&1 || {
        echo "Certificate '$cert_name' not found"
        return 1
    }

    local expiry=$(security find-certificate -c "$cert_name" \
        | grep -oP '(?<="expd"<blob>)[^<]+' | head -1)

    if [ -z "$expiry" ]; then
        echo "Could not determine expiry for '$cert_name'"
        return 1
    fi

    local days_until_expiry=$(( ($(date -d "$expiry" +%s) - $(date +%s)) / 86400 ))

    if [ "$days_until_expiry" -lt "$days_threshold" ]; then
        echo "Certificate '$cert_name' expires in $days_until_expiry days. RENEW REQUIRED."
        return 1
    fi

    echo "Certificate '$cert_name' valid for $days_until_expiry days."
    return 0
}

function sync_provisioning_profiles() {
    echo "Syncing provisioning profiles via Xcode..."
    xcode-select --install-build-components

    # Accounts & settings synced automatically in modern Xcode
    # Use Xcode Cloud for CI/CD to eliminate local cert management
}

check_cert_expiry "Developer ID Application" || echo "ACTION REQUIRED: Renew certificate"
sync_provisioning_profiles
```

### 9.2 Fastlane Match (Shared Certificate Management)
```ruby
# fastlane/Matchfile: Centralized certificate & profile management

git_url("git@github.com:company/certificates.git")
storage_mode("git")

type("appstore")
app_identifier(["com.company.myapp"])
username(ENV["APPLE_ID"])
team_id(ENV["TEAM_ID"])

git_branch("main")
shallow_clone(true)
clone_branch_locally(true)

# Sync certificates to team
lane :sync_certs do
  match(
    type: "appstore",
    readonly: ENV["CI"] == "true",
    force_for_new_devices: true
  )
end
```

---

## 10. CI/CD Pipelines

### 10.1 Xcode Cloud Workflow
```yaml
# workflows/release.yml: Xcode Cloud release workflow

name: Release to App Store
on:
  push:
    tags:
      - 'v*'

env:
  XCODE_VERSION: 15.2
  TEAM_ID: TEAM123ABC
  BUNDLE_ID: com.company.myapp

jobs:
  build-and-release:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v3

      - name: Set up environment
        run: |
          xcode-select --switch /Applications/Xcode_15.2.app

      - name: Increment build number
        run: agvtool next-version -all

      - name: Build archive for App Store
        run: |
          xcodebuild -scheme MyApp \
            -configuration Release \
            -archivePath build/MyApp.xcarchive \
            archive

      - name: Export for App Store
        run: |
          xcodebuild -exportArchive \
            -archivePath build/MyApp.xcarchive \
            -exportOptionsPlist ExportOptions-AppStore.plist \
            -exportPath build/AppStoreExport

      - name: Upload to App Store
        env:
          APPLE_ID: ${{ secrets.APPLE_ID }}
          APP_PASSWORD: ${{ secrets.APP_PASSWORD }}
        run: |
          xcrun altool --upload-app \
            --file build/AppStoreExport/MyApp.ipa \
            --type ios \
            --apple-id $APPLE_ID \
            --password $APP_PASSWORD \
            --team-id $TEAM_ID

      - name: Notify release
        run: |
          echo "Released MyApp v$(agvtool what-version -terse)"
```

### 10.2 GitHub Actions Multi-Platform Build
```yaml
# .github/workflows/build-all-platforms.yml

name: Build All Platforms

on:
  push:
    branches: [main, release/*]

jobs:
  build-matrix:
    runs-on: macos-14
    strategy:
      matrix:
        platform: [ios, macos, watchos, tvos]
        configuration: [Debug, Release]
    steps:
      - uses: actions/checkout@v3

      - name: Build ${{ matrix.platform }} (${{ matrix.configuration }})
        run: |
          xcodebuild -scheme MyApp \
            -configuration ${{ matrix.configuration }} \
            -sdk ${{ matrix.platform }} \
            -derivedDataPath build/${{ matrix.platform }}

      - name: Upload build artifacts
        uses: actions/upload-artifact@v3
        with:
          name: MyApp-${{ matrix.platform }}-${{ matrix.configuration }}
          path: build/${{ matrix.platform }}
```

### 10.3 Complete Fastlane Release Workflow
```ruby
# fastlane/Fastfile: Multi-platform release automation

default_platform(:ios)

platform :ios do
  lane :release do |options|
    ensure_git_branch(branch: 'main')
    ensure_git_status_clean

    # Increment version
    increment_version_number(
      bump_type: options[:version_type] || "patch"
    )
    new_version = get_version_number
    increment_build_number

    # Run tests
    scan(
      workspace: "MyApp.xcworkspace",
      scheme: "MyApp",
      configuration: "Release",
      clean: true
    )

    # Build for App Store
    build_app(
      workspace: "MyApp.xcworkspace",
      scheme: "MyApp",
      configuration: "Release",
      export_method: "app-store",
      skip_package_ipa: true
    )

    # Upload to TestFlight first
    upload_to_testflight(
      skip_waiting_for_build_processing: true,
      changelog: "Version #{new_version}"
    )

    # Create git tag
    add_git_tag(
      tag: "v#{new_version}"
    )

    push_to_git_remote

    # Create GitHub release
    set_github_release(
      repository_name: "company/MyApp",
      api_token: ENV["GITHUB_TOKEN"],
      name: "v#{new_version}",
      description: "Release notes here",
      tag_name: "v#{new_version}"
    )
  end

  lane :dmg_release do
    ensure_git_branch(branch: 'main')

    version = get_version_number
    build_number = get_build_number

    # Build for DMG
    build_app(
      workspace: "MyApp.xcworkspace",
      scheme: "MyApp",
      configuration: "Release_DMG",
      destination: "generic/platform=macOS"
    )

    # Create DMG with custom background
    sh("scripts/create-dmg.sh build/Release_DMG/MyApp.app dist/MyApp-#{version}.dmg")

    # Notarize
    sh("scripts/notarize.sh build/Release_DMG/MyApp.app")

    # Upload to release server or S3
    upload_file_to_s3(
      file: "dist/MyApp-#{version}.dmg",
      bucket: "releases.company.com",
      public: true
    )
  end
end
```

---

## 11. Version Management & Automation

### 11.1 Semantic Versioning with agvtool
```bash
#!/bin/bash
# version-bump.sh: Automated semantic versioning

set -euo pipefail

VERSION_PART="${1:-patch}"  # major, minor, patch

# Extract current version
CURRENT=$(agvtool what-version -terse)
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

case "$VERSION_PART" in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    patch)
        PATCH=$((PATCH + 1))
        ;;
    *)
        echo "Usage: $0 {major|minor|patch}"
        exit 1
        ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"

echo "Bumping version: $CURRENT → $NEW_VERSION"

agvtool new-version -all "$NEW_VERSION"
agvtool next-version -all

# Increment build number each time
agvtool new-build-number $(($(agvtool what-build -terse) + 1))

git add -A
git commit -m "Version bump: $NEW_VERSION"
git tag "v${NEW_VERSION}"

echo "Version bumped to $NEW_VERSION"
```

### 11.2 Changelog Generation from Git Log
```bash
#!/bin/bash
# generate-changelog.sh: Auto-generate changelog from commits

set -euo pipefail

PREVIOUS_TAG=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo "")
CURRENT_TAG=$(git describe --tags --abbrev=0 HEAD)

echo "## Release ${CURRENT_TAG#v}"
echo ""
echo "**Changes since $PREVIOUS_TAG:**"
echo ""

git log "${PREVIOUS_TAG}..${CURRENT_TAG}" --pretty=format:"- %s (%h)" | \
    grep -v "^-" | \
    sort | uniq

echo ""
echo "**Contributors:**"
git log "${PREVIOUS_TAG}..${CURRENT_TAG}" --pretty=format:"%an" | sort | uniq

echo ""
echo "**Build:** $(date +'%Y-%m-%d %H:%M:%S')"
```

---

## 12. Release Management Strategy

### 12.1 Phased Rollout Configuration
```swift
// App Store Connect: Phased Release (macOS/iOS)
// Configure via API or UI:

/*
Week 1: 25% of users
Week 2: 50% of users
Week 3: 75% of users
Week 4: 100% of users (full release)

Revert if crash rate > 5% or critical issues detected
*/

// SwiftUI feature flag pattern for gradual feature rollout
@main
struct MyApp: App {
    @State var featureFlags: FeatureFlags

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.featureFlags, featureFlags)
        }
        .onAppear {
            Task {
                featureFlags = await RemoteConfigManager.shared.fetchFlags()
            }
        }
    }
}

struct FeatureFlags: Codable {
    var newUI: Bool
    var advancedSearch: Bool
    var betaAnalytics: Bool
}
```

### 12.2 App Store Review Submission Checklist
```markdown
# Pre-Release Checklist

## Functional
- [ ] App runs without crashes on target OS version
- [ ] All IAP products active and prices correct
- [ ] External authentication (OAuth) working
- [ ] Push notifications tested (if applicable)
- [ ] Deep linking functional

## Compliance
- [ ] Privacy nutrition label complete
- [ ] Privacy manifest (.xcprivacy) configured
- [ ] Required reason APIs documented
- [ ] User tracking consent (ATT) implemented
- [ ] Age rating accurate
- [ ] GDPR/CCPA clauses in privacy policy

## Content
- [ ] App name matches intent
- [ ] Screenshots show actual app content
- [ ] Description accurate and up-to-date
- [ ] Keywords relevant and not misleading
- [ ] Support URL and privacy policy links valid

## Performance
- [ ] Launch time < 5 seconds
- [ ] No memory leaks detected
- [ ] Crash rate < 1% (via MetricKit)
- [ ] App size reasonable for category

## Build
- [ ] Bitcode disabled (macOS) or N/A
- [ ] All architectures included (arm64, x86_64)
- [ ] Symbols uploaded for crash reporting
- [ ] Build signed with App Store distribution certificate
```

---

## 13. Post-Release Monitoring

### 13.1 Crash Reporting Integration (Crashlytics)
```swift
import FirebaseCrashlytics

class CrashReportingManager {
    static let shared = CrashReportingManager()

    func setupCrashlytics() {
        #if !DEBUG
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        #endif
    }

    func logEvent(_ event: String, attributes: [String: String]? = nil) {
        var eventData = ["event": event]
        if let attributes = attributes {
            eventData.merge(attributes) { _, new in new }
        }
        Crashlytics.crashlytics().record(error: NSError(
            domain: "UserEvent",
            code: 0,
            userInfo: eventData
        ))
    }

    func setUserIdentifier(_ userId: String) {
        Crashlytics.crashlytics().setUserID(userId)
    }
}
```

### 13.2 Performance Monitoring (MetricKit)
```swift
import MetricKit

class PerformanceMonitor: NSObject, MXMetricManagerDelegate {
    static let shared = PerformanceMonitor()

    override init() {
        super.init()
        MXMetricManager.shared.add(self)
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            analyzeMetrics(payload)
        }
    }

    private func analyzeMetrics(_ payload: MXMetricPayload) {
        if let appLaunch = payload.applicationLaunchMetrics {
            let launchDuration = appLaunch.histogrammedTimeToFirstDraw.totalBucketSum
            print("Launch time: \(launchDuration)ms")

            if launchDuration > 5000 {
                // Alert: exceeds acceptable threshold
            }
        }

        if let memory = payload.memoryMetrics {
            let peakMemory = memory.peakMemoryUsage
            print("Peak memory: \(peakMemory / 1024 / 1024)MB")
        }
    }
}
```

### 13.3 App Store Analytics Dashboard
```swift
// Monitor via App Store Connect API or dashboard

class AppStoreAnalytics {
    // Track metrics automatically available via App Store Connect:
    // - Downloads (free/paid)
    // - Revenue
    // - Retention (day 1, 7, 28, 30)
    // - Crash rate
    // - Ratings & reviews
    // - Top-performing countries/regions

    // Custom analytics via App Store Connect server-to-server notifications

    static func setupNotificationTracking() {
        // Subscribe to App Store notifications:
        // SUBSCRIBED_PRICE_CHANGE, CANCEL, REFUND, etc.
    }
}
```

---

## 14. Privacy & Compliance Automation

### 14.1 Privacy Manifest Configuration
```xml
<!-- PrivacyInfo.xcprivacy: Required for App Store submission (iOS 17+, macOS 14+) -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>

    <key>NSPrivacyTrackingDomains</key>
    <array/>

    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryFileTimestampAPIs</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>DDA9.1</string>  <!-- Cache purging -->
            </array>
        </dict>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategorySystemBootTime</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>35F9.1</string>  <!-- Performance analysis -->
            </array>
        </dict>
    </array>
</dict>
</plist>
```

### 14.2 App Privacy Report (Nutrition Label)
```swift
// Configured via App Store Connect, not code:
// Categories:
// - Contact Info (name, email, phone, address)
// - Health & Fitness
// - Financial Info
// - Location
// - Sensitive Info
// - Contacts
// - Photos/Videos
// - Audio
// - Search History
// - User ID
// - Device ID

// For each category, declare:
// - Tracked (linked to user identity)
// - Not tracked
// - Linked to identity or not

// Example: Declare minimal data collection
```

---

## 15. Complete Build & Release Script Template

```bash
#!/bin/bash
# release-pipeline.sh: End-to-end build, sign, notarize, and upload

set -euo pipefail

VERSION="${1:-$(agvtool what-version -terse)}"
PLATFORM="${2:-macos}"  # macos, ios, all
DRY_RUN="${DRY_RUN:-false}"

TEAM_ID="TEAM123ABC"
APPLE_ID="developer@company.com"
BUILD_DIR="build"
DIST_DIR="dist"

function log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

function cleanup() {
    log "Cleaning up temporary files..."
    rm -rf "$BUILD_DIR/temp"
}

trap cleanup EXIT

log "Starting release pipeline for version $VERSION"

# === BUILD PHASE ===
if [[ "$PLATFORM" == "macos" || "$PLATFORM" == "all" ]]; then
    log "Building macOS DMG..."
    xcodebuild -scheme MyApp \
        -configuration Release_DMG \
        -archivePath "$BUILD_DIR/MyApp-DMG.xcarchive" \
        archive

    log "Exporting macOS app..."
    xcodebuild -exportArchive \
        -archivePath "$BUILD_DIR/MyApp-DMG.xcarchive" \
        -exportOptionsPlist ExportOptions-DMG.plist \
        -exportPath "$BUILD_DIR/DMGExport"

    log "Notarizing..."
    if [ "$DRY_RUN" = false ]; then
        bash scripts/notarize.sh "$BUILD_DIR/DMGExport/MyApp.app"
    fi

    log "Creating DMG..."
    bash scripts/create-dmg.sh "$BUILD_DIR/DMGExport/MyApp.app" \
        "$DIST_DIR/MyApp-${VERSION}.dmg"
fi

if [[ "$PLATFORM" == "ios" || "$PLATFORM" == "all" ]]; then
    log "Building iOS app for App Store..."
    xcodebuild -scheme MyApp \
        -configuration Release_AppStore \
        -archivePath "$BUILD_DIR/MyApp-iOS.xcarchive" \
        archive

    log "Exporting iOS app..."
    xcodebuild -exportArchive \
        -archivePath "$BUILD_DIR/MyApp-iOS.xcarchive" \
        -exportOptionsPlist ExportOptions-AppStore.plist \
        -exportPath "$BUILD_DIR/AppStoreExport"

    if [ "$DRY_RUN" = false ]; then
        log "Uploading to App Store..."
        xcrun altool --upload-app \
            --file "$BUILD_DIR/AppStoreExport/MyApp.ipa" \
            --type ios \
            --apple-id "$APPLE_ID" \
            --password "@keychain:APP_PASSWORD" \
            --team-id "$TEAM_ID"
    fi
fi

log "Release $VERSION complete!"
```

---

## Reference: Key Tools & Commands

| Tool | Purpose | Common Use |
|------|---------|-----------|
| `xcodebuild` | CLI build system | Archive, export, sign |
| `codesign` | Code signing | Manual signing of binaries |
| `notarytool` | Notarization | Staple timestamp to macOS apps |
| `stapler` | Notarization stapling | Attach notary ticket to app |
| `hdiutil` | Disk image creation | Create DMG distributions |
| `agvtool` | Version management | Auto-increment version/build |
| `altool` | App Store upload (deprecated, use Transporter) | Upload apps to App Store |
| `transporter` | App Store upload | New standard for App Store uploads |
| `fastlane` | Automation framework | End-to-end CI/CD orchestration |
| `xcrun` | Xcode utility runner | Execute Xcode tools |

---

**Last Updated:** March 2026 | For iOS 17+, macOS 14+, watchOS 10+, tvOS 17+, visionOS 1+

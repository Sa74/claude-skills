# Distribution: DMG + Mac App Store

## Table of Contents
- Dual Distribution Strategy
- Code Signing
- Sandboxing & Entitlements
- Notarization (DMG)
- DMG Creation
- App Store Submission
- Build Configuration

## Dual Distribution Strategy

Ship both DMG (direct download) and Mac App Store. Key differences:

**DMG (Developer ID):**
- Signed with Developer ID Application certificate.
- Notarized via Apple's notary service.
- No sandbox requirement (but recommended where feasible).
- Can use all system APIs including those restricted from App Store (Endpoint Security, some DriverKit, privileged helpers).
- Manual update mechanism needed (Sparkle or custom).

**Mac App Store:**
- Signed with Apple Distribution certificate.
- Sandboxed (mandatory).
- Must use only App Store-permitted APIs.
- System extensions must be approved for App Store distribution.
- Automatic updates via App Store.

**Shared codebase:** Use build configurations and compiler flags to conditionally compile distribution-specific code:
```swift
#if APPSTORE
    // App Store-specific code
#else
    // Direct distribution code
#endif
```

Define `APPSTORE` in the App Store target's build settings under `Swift Compiler - Custom Flags` → `Active Compilation Conditions`.

## Code Signing

**Certificates needed:**
- `Developer ID Application` — for DMG distribution.
- `Developer ID Installer` — if distributing as .pkg.
- `Apple Distribution` — for App Store.
- `3rd Party Mac Developer Installer` — for App Store .pkg upload.
- Separate signing identity per System Extension target.

**Signing configuration in Xcode:**
- App target: automatic signing for development, manual for release.
- System Extension targets: always manual signing with explicit provisioning profiles.
- Hardened Runtime: enabled for both distribution methods.

**Team ID consistency:** All targets (app + extensions) must use the same Team ID.

## Sandboxing & Entitlements

**App Store (mandatory sandbox):**
```xml
<key>com.apple.security.app-sandbox</key>
<true/>
```

Request only entitlements the app actively uses:
- `com.apple.security.files.user-selected.read-write` — file access via Open/Save panels.
- `com.apple.security.network.client` — outbound network.
- `com.apple.security.network.server` — inbound network (if needed).
- `com.apple.security.device.usb` — USB access.
- `com.apple.security.temporary-exception.*` — avoid these; App Review flags them.

**DMG (optional sandbox):**
- Sandbox if feasible for security posture.
- If the app requires unsandboxable APIs (raw disk access, certain IOKit, privileged helpers), skip sandbox but still enable Hardened Runtime.

**Hardened Runtime (both):**
```xml
<key>com.apple.security.cs.allow-unsigned-executable-memory</key>
<true/>  <!-- Only if genuinely needed, e.g. JIT -->
```

Avoid disabling protections unless required. Each exception weakens security and may cause App Review rejection.

**Entitlement files:** Maintain separate `.entitlements` files per target and per distribution:
```
App/
  App.entitlements              (development)
  App_AppStore.entitlements     (App Store)
  App_DirectDist.entitlements   (DMG)
SystemExtension/
  Extension.entitlements
```

## Notarization (DMG)

Required for all Developer ID-signed apps on macOS 10.15+.

**Automated via xcodebuild:**
```bash
# Archive
xcodebuild archive \
  -scheme "MyApp" \
  -archivePath build/MyApp.xcarchive

# Export with notarization
xcodebuild -exportArchive \
  -archivePath build/MyApp.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/export
```

**ExportOptions.plist for Developer ID with notarization:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
</dict>
</plist>
```

**Manual notarization (if needed):**
```bash
# Submit
xcrun notarytool submit MyApp.dmg \
  --apple-id "dev@example.com" \
  --team-id "TEAM_ID" \
  --password "@keychain:AC_PASSWORD" \
  --wait

# Staple
xcrun stapler staple MyApp.dmg
```

Store App Store Connect credentials in Keychain, never in scripts.

## DMG Creation

**Using create-dmg or hdiutil:**

```bash
# Simple approach with hdiutil
hdiutil create -volname "MyApp" \
  -srcfolder build/export/MyApp.app \
  -ov -format UDZO \
  build/MyApp.dmg
```

For branded DMGs with background image and Applications symlink, use `create-dmg` (installable via Homebrew) or a DMG canvas tool.

**Automate in CI:** Create a build script or Makefile target that archives, exports, creates DMG, notarizes, and staples in sequence.

## App Store Submission

**Upload via xcodebuild or Transporter:**
```bash
xcodebuild -exportArchive \
  -archivePath build/MyApp.xcarchive \
  -exportOptionsPlist AppStoreExportOptions.plist \
  -exportPath build/appstore

# Or upload with xcrun
xcrun altool --upload-app \
  -f build/appstore/MyApp.pkg \
  -t macos \
  -u "dev@example.com" \
  -p "@keychain:AC_PASSWORD"
```

**App Store review considerations:**
- All entitlements must be justified in App Review notes.
- System extensions require Apple's approval for App Store distribution.
- Network Extension and Endpoint Security entitlements are restricted — apply separately.
- Privacy descriptions in Info.plist for every permission used.
- Minimum deployment target should align with App Store guidelines.

## Build Configuration

**Xcode scheme structure:**
- `MyApp (Debug)` — development, automatic signing.
- `MyApp (App Store)` — App Store release, manual signing, `APPSTORE` flag.
- `MyApp (Direct)` — Developer ID release, manual signing.

**Per-configuration settings to differentiate:**
- `CODE_SIGN_IDENTITY`
- `PROVISIONING_PROFILE_SPECIFIER`
- `CODE_SIGN_ENTITLEMENTS` (point to distribution-specific entitlements file)
- `SWIFT_ACTIVE_COMPILATION_CONDITIONS` (add `APPSTORE` for App Store builds)
- `PRODUCT_BUNDLE_IDENTIFIER` (may differ if App Store and direct use different bundle IDs)

**SPM integration:** SPM packages are code-signed automatically when embedded in the app. No special configuration needed for SPM dependencies in either distribution method.

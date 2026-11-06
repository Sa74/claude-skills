# Kernel & System-Level Development

## Table of Contents
- System Extensions vs Kernel Extensions
- DriverKit
- IOKit (User-Space)
- Endpoint Security
- Network Extensions
- Privileged Helper Tools
- Debugging System-Level Code

## System Extensions vs Kernel Extensions

**KEXTs are deprecated.** Apple has been actively removing KEXT support since macOS 11. All new development must use System Extensions.

**System Extension types:**
- **DriverKit extensions** — Hardware drivers (USB, HID, Serial, PCIe, Audio, Block Storage, SCSI). Run in user space with crash isolation.
- **Network extensions** — Content filters, DNS proxies, packet tunnels, transparent proxies, app proxies. Require Network Extension entitlement from Apple.
- **Endpoint Security extensions** — Process monitoring, file access control, security event auditing. Require Endpoint Security entitlement from Apple.

**Activation flow:**
1. App bundles the `.systemextension` in `Contents/Library/SystemExtensions/`.
2. App calls `OSSystemExtensionManager.shared.submitRequest()` with an `OSSystemExtensionRequest`.
3. User approves in System Settings > Privacy & Security (first install only).
4. System extension runs as a separate process managed by `sysextd`.

**Key constraints:**
- System extensions must be code-signed with a valid Developer ID or distributed via App Store.
- Sandboxing rules differ between extension types — check entitlements per type.
- Extensions survive app quit but are removed when the app is deleted.
- Must handle `OSSystemExtensionRequestDelegate` callbacks: `requestNeedsUserApproval`, `requestCompleted`, `requestFailed`, `replacingExtension`.

## DriverKit

**When to use:** Hardware interaction — USB devices, HID devices, audio hardware, PCIe, serial ports, block storage, SCSI controllers, networking devices.

**Architecture:**
- Subclass `IOService` (DriverKit, not kernel IOKit).
- Runs in user space — crashes do not panic the kernel.
- Communicate with hardware through IOKit transport families (IOUSBHostDevice, IOHIDDevice, etc.).
- Use `IODispatchQueue` for work scheduling (not GCD).
- Memory shared with hardware via `IOMemoryDescriptor` / `IOBufferMemoryDescriptor`.

**Entitlements required:**
- `com.apple.developer.driverkit` — base entitlement.
- Transport-specific: `com.apple.developer.driverkit.transport.usb`, `.hid`, `.pci`, `.serial`, etc.
- Request via Apple developer portal. Approval is not instant.

**Info.plist matching:**
```xml
<key>IOKitPersonalities</key>
<dict>
    <key>MyDriver</key>
    <dict>
        <key>CFBundleIdentifierKernel</key>
        <string>com.apple.kpi.iokit</string>
        <key>IOClass</key>
        <string>IOUserService</string>
        <key>IOUserClass</key>
        <string>MyDriverClassName</string>
        <key>IOProviderClass</key>
        <string>IOUSBHostDevice</string>
        <key>idVendor</key>
        <integer>VENDOR_ID</integer>
        <key>idProduct</key>
        <integer>PRODUCT_ID</integer>
    </dict>
</dict>
```

**Lifecycle:** `Start()` → `Stop()` → `free()`. Override `Start()` to initialize, `Stop()` to clean up. Always call `super` implementations.

## IOKit (User-Space Client)

**When to use:** Communicating with drivers from your app (not writing the driver itself). Common for apps that need device info, power management, or hardware events.

**Key patterns:**
- `IOServiceMatching()` to find devices.
- `IOServiceGetMatchingService()` / `IOServiceGetMatchingServices()` to get device references.
- `IOServiceAddMatchingNotification()` for plug/unplug events.
- `IORegistryEntryCreateCFProperties()` to read device properties.
- `IOConnectCallMethod()` / `IOConnectCallStructMethod()` to call driver methods.
- Always `IOObjectRelease()` when done — IOKit objects are not ARC-managed.

**Swift bridging:** IOKit is C-based. Wrap calls in Swift extensions with proper error handling. Convert `kern_return_t` to Swift errors.

## Endpoint Security

**When to use:** Monitoring or controlling file access, process execution, network activity for security purposes. Requires explicit entitlement from Apple.

**Architecture:**
- Create `es_client_t` via `es_new_client()`.
- Subscribe to event types: `ES_EVENT_TYPE_AUTH_*` (blocking) or `ES_EVENT_TYPE_NOTIFY_*` (non-blocking).
- AUTH events require a response (`es_respond_auth_result`) within the deadline — failure causes system hang.
- NOTIFY events are fire-and-forget.

**Critical rules:**
- Never block the AUTH response handler. Offload heavy work to another thread/queue, but respond within the deadline.
- `es_mute_path()` / `es_mute_process()` to exclude known-safe paths/processes and reduce noise.
- The ES client runs as a system extension, not inside the main app process.
- Test with `eslogger` CLI tool during development.

**Entitlement:** `com.apple.developer.endpoint-security.client` — must be requested from Apple.

## Network Extensions

**Types:**
- **NEFilterDataProvider / NEFilterPacketProvider** — Content filtering (inspect/block network traffic).
- **NEDNSProxyProvider** — DNS proxy (intercept and handle DNS queries).
- **NEPacketTunnelProvider** — VPN / packet tunnel (full tunnel or split tunnel).
- **NETransparentProxyProvider** — Transparent TCP/UDP proxy.
- **NEAppProxyProvider** — Per-app proxy.

**Activation:** Configured via `NEFilterManager`, `NETunnelProviderManager`, or `NEDNSProxyManager` from the containing app. User must approve in System Settings.

**Key constraints:**
- Requires `com.apple.developer.networking.networkextension` entitlement from Apple (specify capabilities).
- Network extensions run in a sandboxed process with limited file system access.
- Use `NWConnection` / `NWListener` (Network framework) for socket-level work, not BSD sockets.
- Must handle `NEProvider` lifecycle: `startProxy`/`stopProxy` or `startFilter`/`stopFilter`.

## Privileged Helper Tools

**When to use:** Operations requiring root privileges that cannot be done via System Extensions (rare). Examples: modifying system network config, installing system-wide launch daemons.

**Approach:**
- `SMAppService.daemon(plistName:)` (macOS 13+) for registering privileged helpers.
- Legacy: `SMJobBless` for installing privileged helper tools (deprecated path, avoid for new code).
- Communicate between app and helper via XPC (`NSXPCConnection`).
- Helper runs as a LaunchDaemon with root privileges.
- Code-sign the helper and embed in the app bundle at `Contents/Library/LaunchDaemons/`.

## Debugging System-Level Code

- **System extensions:** Attach via `lldb` to the extension process. Use `systemextensionsctl list` to verify install state.
- **DriverKit:** Use `IORegistryExplorer.app` to inspect the IORegistry. Check `system.log` / `log show --predicate 'subsystem == "com.apple.iokit"'`.
- **Endpoint Security:** Use `eslogger` to verify events are firing. Check `log show --predicate 'subsystem == "com.apple.endpointsecurity"'`.
- **Network Extensions:** Use `log show --predicate 'subsystem == "com.apple.networkextension"'`. Check `scutil --nwi` for network interface state.
- **General:** `Console.app`, `log stream`, `log show` with predicate filters. SIP must often be partially disabled for debugging system extensions during development.

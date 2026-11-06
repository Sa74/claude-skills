# Principal Apple Engineer: macOS Platform Development

## System-Level Frameworks & Extensions

### System Extensions Architecture
System Extensions replace deprecated KEXTs. Three types: DriverKit, Network Extensions, Endpoint Security.

**Bundle Location (CRITICAL):**
System extensions MUST be bundled inside the app at this exact path:
```
YourApp.app/Contents/Library/SystemExtensions/com.yourcompany.yourextension.systemextension
```
The `.systemextension` is embedded at build time via Xcode's "Embed System Extensions" build phase.
If it's not at `Contents/Library/SystemExtensions/`, the system will not find it.

**Activation Flow:**
1. App bundles the `.systemextension` in `Contents/Library/SystemExtensions/`
2. App calls `OSSystemExtensionManager.shared.submitRequest()` with an `OSSystemExtensionRequest`
3. User approves in System Settings > Privacy & Security (first install only)
4. System extension runs as a separate process managed by `sysextd`

**Comparison: KEXTs vs System Extensions**
```swift
// KEXT (deprecated): kernel-space, unsafe, deprecated
// System Extensions: user-space, sandboxed, notarizable

// Enable in Info.plist:
// <key>NSSystemExtensionUsageDescription</key>
// <string>Required for system monitoring</string>
```

**Activation with OSSystemExtensionRequest (preferred over SMAppService for System Extensions):**
```swift
import SystemExtensions
import os.log

class SystemExtensionManager: NSObject, OSSystemExtensionRequestDelegate {
    private let logger = Logger(subsystem: "com.yourapp", category: "sysext")

    /// Extension bundle identifier — matches the .systemextension target
    private let extensionBundleIdentifier = "com.yourcompany.yourapp.extension"

    func activate() {
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: extensionBundleIdentifier,
            queue: .main
        )
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }

    func deactivate() {
        let request = OSSystemExtensionRequest.deactivationRequest(
            forExtensionWithIdentifier: extensionBundleIdentifier,
            queue: .main
        )
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }

    // MARK: - OSSystemExtensionRequestDelegate

    func request(_ request: OSSystemExtensionRequest,
                 didFinishWithResult result: OSSystemExtensionRequest.Result) {
        switch result {
        case .completed:
            logger.info("System extension activated successfully")
        case .willCompleteAfterReboot:
            logger.info("System extension will activate after reboot")
        @unknown default:
            logger.warning("Unknown result: \(String(describing: result))")
        }
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        logger.error("System extension failed: \(error.localizedDescription)")
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        logger.info("Waiting for user approval in System Settings")
    }

    func request(_ request: OSSystemExtensionRequest,
                 actionForReplacingExtension existing: OSSystemExtensionProperties,
                 withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        return .replace  // Replace existing version
    }
}
```

### DriverKit: User-Space IOService
Replace kernel IOKit drivers entirely. Runs in dedicated daemon process.

**Basic DriverKit Driver Structure**
```swift
import DriverKit

class MyUSBDevice: IOService {
    var provider: IOUSBDevice?

    override func Start(
        _ provider: IOService?
    ) -> Bool {
        self.provider = provider as? IOUSBDevice

        // Get device descriptor
        guard let device = self.provider else { return false }

        // Subscribe to device notifications
        device.RegisterService()
        return true
    }

    override func Stop(
        _ provider: IOService?
    ) -> Bool {
        self.provider = nil
        return true
    }
}
```

**IODispatchQueue for Async Operations**
```swift
class AsyncDevice: IOService {
    var queue: IODispatchQueue?
    var timer: IODispatchTimer?

    override func Start(
        _ provider: IOService?
    ) -> Bool {
        // Create dedicated queue
        queue = IODispatchQueue(
            "com.company.device.queue",
            QueuePriority.default.rawValue
        )

        // Create timer on queue
        timer = IODispatchTimer(
            IODispatchTimer.Attribute.relativeToPresentTime,
            queue: queue
        )

        timer?.setTimer(
            deadline: 100_000_000, // nanoseconds
            leeway: 1_000_000,
            handler: { [weak self] in
                self?.timerFired()
            }
        )

        return true
    }

    func timerFired() {
        // Handle periodic work
    }
}
```

**Entitlements & Matching**
```xml
<!-- DriverKit.entitlements -->
<key>com.apple.developer.driverkit</key>
<true/>
<key>com.apple.developer.driverkit.usb</key>
<true/>

<!-- Info.plist matching -->
<key>IOKitPersonalities</key>
<dict>
    <key>MyDevice</key>
    <dict>
        <key>IOClass</key>
        <string>MyUSBDevice</string>
        <key>IOProbeScore</key>
        <integer>5000</integer>
        <key>IOMatchCategory</key>
        <string>IODefaultMatchCategory</string>
        <key>idProduct</key>
        <integer>0x1234</integer>
        <key>idVendor</key>
        <integer>0x5678</integer>
    </dict>
</dict>
```

### IOKit User-Space Client APIs
Interact with IOKit drivers from user-space applications.

**Service Matching & Connection**
```swift
import IOKit

func findAndConnectToDevice() -> io_connect_t? {
    let matching = IOServiceMatching("MyUSBDevice")
    var iterator: io_iterator_t = 0

    guard IOServiceGetMatchingServices(
        kIOMasterPortDefault,
        matching,
        &iterator
    ) == KERN_SUCCESS else {
        return nil
    }

    defer { IOObjectRelease(iterator) }

    var service = IOIteratorNext(iterator)
    guard service != IO_OBJECT_NULL else { return nil }
    defer { IOObjectRelease(service) }

    var connection: io_connect_t = 0
    guard IOServiceOpen(
        service,
        mach_task_self_,
        0,
        &connection
    ) == KERN_SUCCESS else {
        return nil
    }

    return connection
}

func callDriver(_ connection: io_connect_t, command: UInt32) {
    var input: UInt64 = 0x1234
    var inputCount = 1
    var output: UInt64 = 0
    var outputCount: UInt32 = 1

    let result = IOConnectCallScalarMethod(
        connection,
        command,
        &input,
        inputCount,
        &output,
        &outputCount
    )

    if result == KERN_SUCCESS {
        print("Output: \(output)")
    }
}
```

**Swift Bridge for IOKit**
```swift
// Create Swift-friendly wrapper
class IOKitDevice {
    private let connection: io_connect_t

    init?(_ matching: [String: Any]) {
        guard let conn = Self.findDevice(matching) else { return nil }
        self.connection = conn
    }

    deinit {
        IOServiceClose(connection)
    }

    private static func findDevice(_ matching: [String: Any]) -> io_connect_t? {
        // Implementation as above
        return nil
    }

    func callMethod(_ selector: UInt32, input: [UInt64]) -> [UInt64]? {
        var scalars = input
        var output = Array(repeating: UInt64(0), count: 16)
        var outCount: UInt32 = UInt32(output.count)

        let result = IOConnectCallScalarMethod(
            connection,
            selector,
            &scalars,
            UInt32(scalars.count),
            &output,
            &outCount
        )

        return result == KERN_SUCCESS ? Array(output.prefix(Int(outCount))) : nil
    }
}
```

### Endpoint Security Framework
Monitor and control system events with fine-grained authorization.

**ES Client Initialization & Message Handling**
```swift
import EndpointSecurity

class SystemMonitor {
    private var client: es_client_t?
    private let queue = DispatchQueue(label: "com.company.es.handler")

    func start() throws {
        var client: es_client_t?

        let result = es_new_client(&client) { [weak self] client, message in
            self?.handleMessage(message)
        }

        guard result == ES_NEW_CLIENT_RESULT_SUCCESS else {
            throw NSError(domain: "ES", code: Int(result.rawValue))
        }

        self.client = client

        // Subscribe to events
        try subscribe(to: [
            ES_EVENT_TYPE_AUTH_PROCESS_FORK,
            ES_EVENT_TYPE_AUTH_EXEC,
            ES_EVENT_TYPE_NOTIFY_OPEN,
            ES_EVENT_TYPE_NOTIFY_WRITE
        ])
    }

    private func subscribe(to events: [es_event_type_t]) throws {
        guard let client = client else { return }

        var events = events
        let result = es_subscribe(client, &events, UInt32(events.count))

        guard result == ES_RETURN_SUCCESS else {
            throw NSError(domain: "ES", code: Int(result.rawValue))
        }
    }

    private func handleMessage(_ message: UnsafePointer<es_message_t>) {
        let msg = message.pointee

        switch msg.event_type {
        case ES_EVENT_TYPE_AUTH_EXEC:
            handleExec(message)
        case ES_EVENT_TYPE_AUTH_PROCESS_FORK:
            handleFork(message)
        case ES_EVENT_TYPE_NOTIFY_OPEN:
            handleOpen(message)
        default:
            break
        }
    }

    private func handleExec(_ message: UnsafePointer<es_message_t>) {
        let msg = message.pointee
        guard let event = msg.event.exec else { return }

        let path = String(bytesNoCopy: UnsafeMutableRawPointer(
            mutating: event.pointee.image.pointee.executable.path.data
        ), length: Int(event.pointee.image.pointee.executable.path.length),
        encoding: .utf8, freeWhenDone: false) ?? "unknown"

        print("Process exec: \(path), PID: \(msg.process.pointee.pid)")

        // AUTH events: respond with allow/deny before deadline
        es_respond_auth_result(
            client,
            message,
            ES_AUTH_RESULT_ALLOW,
            false
        )
    }

    private func handleFork(_ message: UnsafePointer<es_message_t>) {
        let msg = message.pointee
        print("Process fork: parent PID \(msg.process.pointee.pid)")

        es_respond_auth_result(client, message, ES_AUTH_RESULT_ALLOW, false)
    }

    private func handleOpen(_ message: UnsafePointer<es_message_t>) {
        // NOTIFY events: no response needed
    }
}

// Muting specific operations
func muteProcessTree() {
    // Mute path for optimization
    es_mute_path(client, "/usr/bin/python3")

    // Or mute all processes in a folder
    es_mute_path_prefix(client, "/usr/local/bin/")
}
```

**AUTH vs NOTIFY Events**
```swift
// AUTH (prefix): blocking, must respond before deadline
// - ES_EVENT_TYPE_AUTH_EXEC
// - ES_EVENT_TYPE_AUTH_PROCESS_FORK
// - ES_EVENT_TYPE_AUTH_OPEN
// Response deadline: typically 1-2 seconds

// NOTIFY (prefix): non-blocking, informational only
// - ES_EVENT_TYPE_NOTIFY_EXEC
// - ES_EVENT_TYPE_NOTIFY_OPEN
// - ES_EVENT_TYPE_NOTIFY_WRITE
// No response required

private func respondToAuthEvent(
    _ message: UnsafePointer<es_message_t>,
    allow: Bool
) {
    es_respond_auth_result(
        client,
        message,
        allow ? ES_AUTH_RESULT_ALLOW : ES_AUTH_RESULT_DENY,
        false // cache decision
    )
}
```

### Network Extensions
Deep packet inspection, DNS proxying, VPN tunneling.

**Packet Filter Provider**
```swift
import NetworkExtension

class PacketFilter: NEFilterDataProvider {
    override func startFilter(completionHandler: @escaping (Error?) -> Void) {
        print("Packet filter started")
        completionHandler(nil)
    }

    override func stopFilter(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        print("Packet filter stopped: \(reason)")
        completionHandler()
    }

    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        guard let tcpFlow = flow as? NEFilterBrowserFlow else {
            return .allow()
        }

        if let url = tcpFlow.url,
           url.host?.contains("blocked.example.com") == true {
            return .drop()
        }

        return .allow()
    }
}
```

**DNS Proxy Provider**
```swift
class DNSProxy: NEDNSProxyProvider {
    override func startProxy(options: [String: Any]?, completionHandler: @escaping (Error?) -> Void) {
        completionHandler(nil)
    }

    override func handleNewUDPFlow(
        _ flow: NEAppProxyUDPFlow,
        initialRemoteAddress remoteAddress: NWAddress
    ) -> Bool {
        // Intercept DNS queries (port 53)
        if remoteAddress.port == 53 {
            return true // Handle the flow
        }
        return false
    }
}
```

**VPN/Transparent Proxy**
```swift
class TunnelProvider: NEPacketTunnelProvider {
    override func startTunnel(options: [String: NSObject]?,
                            completionHandler: @escaping (Error?) -> Void) {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "198.51.100.1")

        let ipv4Settings = NEIPv4Settings()
        ipv4Settings.addresses = ["198.51.100.2"]
        ipv4Settings.subnetMasks = ["255.255.255.0"]
        settings.ipv4Settings = ipv4Settings

        let dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
        dnsSettings.matchDomains = [] // Match all
        settings.dnsSettings = dnsSettings

        setTunnelSettings(settings) { error in
            completionHandler(error)
        }
    }
}
```

### Privileged Helper Tools
Perform elevated operations via XPC.

**Helper Installation**
```swift
import ServiceManagement

func installPrivilegedHelper() -> Bool {
    var authRef: AuthorizationRef?
    var authStatus = AuthorizationCreate(
        nil,
        nil,
        [.defaults],
        &authRef
    )

    guard authStatus == errAuthorizationSuccess,
          let auth = authRef else { return false }

    defer { AuthorizationFree(auth, .destroyRights) }

    var error: Unmanaged<CFError>?
    let result = SMJobBless(
        kSMDomainSystemLaunchd,
        "com.company.helper" as CFString,
        auth,
        &error
    )

    if let error = error {
        print("SMJobBless failed: \(error.takeRetainedValue())")
        return false
    }

    return result
}
```

**XPC Communication**
```swift
class HelperClient {
    private let connection = NSXPCConnection(machServiceName: "com.company.helper")

    func request(command: String, reply: @escaping (String) -> Void) {
        connection.remoteObjectProxy {
            HelperProtocol in
            proxy.executeCommand(command) { result in
                reply(result)
            }
        }
    }
}

// Helper side
@objc protocol HelperProtocol {
    func executeCommand(_ cmd: String, reply: @escaping (String) -> Void)
}

class HelperService: NSObject, HelperProtocol {
    func executeCommand(_ cmd: String, reply: @escaping (String) -> Void) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/whoami")
        // Execute with elevated privileges
        reply("root")
    }
}
```

### Debugging System-Level Code

**LLDB for Driver Debugging**
```bash
# Attach to DriverKit daemon
sudo lldb -p $(pgrep -f "com.company.driver.dext")

# Set breakpoint in driver
(lldb) breakpoint set --name IOService::Start

# List IOKit services
(lldb) po [IOService allServices]

# Memory breakpoint on device register
(lldb) watchpoint set variable myDevice->registered
```

**IORegistryExplorer**
```bash
# Dump IOKit registry as XML
ioreg -l -p IODeviceTree > registry.xml

# Search for specific devices
ioreg -l | grep "USB Device"

# Monitor registry changes in real-time
ioreg -l -w 0
```

**Endpoint Security Logging**
```bash
# Real-time ES event logging
sudo log stream --level debug --predicate 'eventMessage contains "endpoint"'

# Custom ES event capture
eslogger --notifyOnly --json | jq '.event_type'

# Correlate with system calls
sudo dtrace -n 'syscall:::entry { printf("%s\n", execname); }'
```

---

## SwiftUI + AppKit Integration

### Embedding SwiftUI in AppKit
**NSHostingView for SwiftUI Views**
```swift
import AppKit
import SwiftUI

class PreferencesViewController: NSViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let swiftUIView = SettingsView()
        let hostingView = NSHostingView(rootView: swiftUIView)

        hostingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: view.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

struct SettingsView: View {
    @AppStorage("theme") var theme = "light"

    var body: some View {
        VStack(alignment: .leading) {
            Text("Preferences")
                .font(.headline)

            Picker("Theme", selection: $theme) {
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            .pickerStyle(.radioGroup)
        }
        .padding()
    }
}
```

**NSViewRepresentable: AppKit in SwiftUI**
```swift
struct NSTextFieldRepresentable: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.delegate = context.coordinator
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            self._text = text
        }

        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                text = textField.stringValue
            }
        }
    }
}
```

### NSWindow Management
**Custom Window Styles & Behavior**
```swift
class CustomWindow: NSWindow {
    override init(
        contentRect: NSRect,
        styleMask style: StyleMask,
        backing bufferingType: BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: bufferingType,
            defer: flag
        )

        // Transparent background, full-size content view
        self.styleMask.insert(.fullSizeContentView)
        self.backgroundColor = NSColor.clear
        self.isOpaque = false

        // Window level (above normal windows)
        self.level = .floating

        // Behavior
        self.collectionBehavior = [.managed, .participatesInCycle]
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
```

**NSToolbar Integration**
```swift
class MainWindowController: NSWindowController, NSToolbarDelegate {
    override func windowDidLoad() {
        super.windowDidLoad()

        let toolbar = NSToolbar(identifier: "MainToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        window?.toolbar = toolbar
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)

        switch itemIdentifier {
        case NSToolbarItem.Identifier("refresh"):
            item.label = "Refresh"
            item.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)
            item.action = #selector(refreshAction)
            return item
        default:
            return nil
        }
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.init("refresh"), .flexibleSpace, .init("search")]
    }

    @objc func refreshAction() {
        print("Refresh tapped")
    }
}
```

### Menu Bar Integration
**Status Items & MenuBarExtra**
```swift
@main
struct MenuBarApp: App {
    var body: some Scene {
        MenuBarExtra("Monitor", systemImage: "gear") {
            VStack {
                Button("Open Settings") { openSettings() }
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            .padding()
        }
        .menuBarExtraStyle(.window)
    }

    func openSettings() {
        NSApp.sendAction(#selector(NSApplication.orderFrontStandardAboutPanel(_:)), to: nil, from: nil)
    }
}
```

**Legacy NSStatusItem**
```swift
class StatusBarController {
    var statusItem: NSStatusItem?

    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: nil)
            button.action = #selector(togglePanel)
            button.target = self
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Status", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc func togglePanel() {
        print("Status item clicked")
    }
}
```

---

## macOS-Specific UI Patterns

### NSTableView & NSOutlineView
**High-Performance Reusable Cell Pattern**
```swift
class DataSource: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    var data: [String] = ["Item 1", "Item 2", "Item 3"]

    func numberOfRows(in tableView: NSTableView) -> Int {
        return data.count
    }

    func tableView(
        _ tableView: NSTableView,
        viewFor tableColumn: NSTableColumn?,
        row: Int
    ) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("DataCell")

        var cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = identifier
            let textField = NSTextField()
            textField.translatesAutoresizingMaskIntoConstraints = false
            cell?.addSubview(textField)
            cell?.textField = textField
        }

        cell?.textField?.stringValue = data[row]
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let tableView = notification.object as! NSTableView
        print("Selected row: \(tableView.selectedRow)")
    }
}
```

### NSSplitView Layouts
**Three-Pane Inspector Layout**
```swift
class InspectorViewController: NSViewController {
    let splitView = NSSplitView()

    override func viewDidLoad() {
        super.viewDidLoad()

        let sidebarView = NSView()
        let mainView = NSView()
        let inspectorView = NSView()

        splitView.addArrangedSubview(sidebarView)
        splitView.addArrangedSubview(mainView)
        splitView.addArrangedSubview(inspectorView)

        splitView.isVertical = true
        splitView.dividerStyle = .thick

        // Set proportional sizing
        splitView.setPosition(200, ofDividerAt: 0)
        sidebarView.widthAnchor.constraint(equalToConstant: 200).isActive = true
        inspectorView.widthAnchor.constraint(equalToConstant: 250).isActive = true

        view = splitView
    }
}
```

### NSPanel for Floating Windows
**Utility Window Pattern**
```swift
class FloatingPanelController: NSWindowController {
    init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 100, y: 100, width: 300, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        panel.title = "Inspector"
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.isFloatingPanel = true

        super.init(window: panel)

        // Content view controller
        let vc = NSViewController()
        self.contentViewController = vc
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
```

### Drag & Drop with NSDraggingDestination
```swift
class DragDropView: NSView {
    override func awakeFromNib() {
        super.awakeFromNib()
        registerForDraggedTypes([.fileURL, .string])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard
        if pasteboard.availableType(from: [.fileURL]) != nil {
            return .copy
        }
        return .operation()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] {
            for url in urls {
                print("Dropped file: \(url.path)")
            }
            return true
        }

        return false
    }
}
```

### NSPasteboard: Copy/Paste Operations
```swift
class PasteboardHelper {
    static func copyText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    static func pasteText() -> String? {
        let pasteboard = NSPasteboard.general
        return pasteboard.string(forType: .string)
    }

    static func copyFiles(_ urls: [URL]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(urls as [NSPasteboardWriting])
    }

    static func pasteFiles() -> [URL]? {
        let pasteboard = NSPasteboard.general
        return pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL]
    }
}
```

---

## macOS Security Model

### Sandboxing & Entitlements
**Sandbox Entitlements Profile**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>

    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>

    <key>com.apple.security.network.client</key>
    <true/>

    <key>com.apple.security.device.camera</key>
    <true/>

    <key>com.apple.security.personal-information.location</key>
    <true/>

    <!-- Hardened Runtime -->
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
</dict>
</plist>
```

**Security-Scoped Bookmarks**
```swift
func saveSecurityScopedBookmark(for url: URL) throws {
    let bookmark = try url.bookmarkData(
        options: .withSecurityScope,
        includingResourceValuesForKeys: nil,
        relativeTo: nil
    )
    UserDefaults.standard.set(bookmark, forKey: "secure_bookmark")
}

func accessSecureFile() throws -> URL {
    guard let data = UserDefaults.standard.data(forKey: "secure_bookmark") else {
        throw NSError(domain: "", code: -1)
    }

    var stale = false
    let url = try URL(
        resolvingBookmarkData: data,
        options: .withSecurityScope,
        relativeTo: nil,
        bookmarkDataIsStale: &stale
    )

    defer { try? url.stopAccessingSecurityScopedResource() }
    url.startAccessingSecurityScopedResource()

    // Use file at url
    return url
}
```

### XPC Services
**Mach Service Definition**
```xml
<!-- LaunchServices.plist -->
<key>MachServices</key>
<dict>
    <key>com.company.service</key>
    <dict>
        <key>HideStandardUserDefaults</key>
        <false/>
    </dict>
</dict>
```

**Named XPC Connection**
```swift
class XPCServer {
    func startListener() {
        let listener = NSXPCListener(machServiceName: "com.company.service")
        listener.delegate = self
        listener.resume()
    }
}

extension XPCServer: NSXPCListenerDelegate {
    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        let interface = NSXPCInterface(with: ServiceProtocol.self)
        newConnection.exportedInterface = interface
        newConnection.exportedObject = ServiceImplementation()
        newConnection.resume()
        return true
    }
}

@objc protocol ServiceProtocol {
    func performTask(_ input: String, reply: @escaping (String) -> Void)
}

class ServiceImplementation: NSObject, ServiceProtocol {
    func performTask(_ input: String, reply: @escaping (String) -> Void) {
        reply("Processed: \(input)")
    }
}
```

**Anonymous XPC Connection**
```swift
class AnonymousXPCConnection {
    private let connection: NSXPCConnection

    init() {
        self.connection = NSXPCConnection(
            listenerEndpoint: /* from parent process */
        )
        self.connection.remoteObjectInterface = NSXPCInterface(with: ParentProtocol.self)
        self.connection.resume()
    }

    func communicateWithParent(data: String) {
        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            print("XPC error: \(error)")
        } as! ParentProtocol

        proxy.receiveData(data)
    }
}
```

### Authorization Framework
**AuthorizationCreate for Privilege Escalation**
```swift
func requestPrivilegeEscalation(for command: String) -> Bool {
    var authRef: AuthorizationRef?

    // Create authorization
    var result = AuthorizationCreate(nil, nil, [.defaults], &authRef)
    guard result == errAuthorizationSuccess, let auth = authRef else {
        return false
    }

    defer { AuthorizationFree(auth, .destroyRights) }

    // Request specific right
    var rights = AuthorizationItem(
        name: kAuthorizationRightExecute,
        valueLength: 0,
        value: UnsafeMutableRawPointer(mutating: command),
        flags: 0
    )

    var rightsSet = AuthorizationRights(
        count: 1,
        items: &rights
    )

    result = AuthorizationCopyRights(
        auth,
        &rightsSet,
        nil,
        [.defaults, .interactionAllowed, .preAuthorize],
        nil
    )

    return result == errAuthorizationSuccess
}
```

### Keychain Storage
**Secure Credential Storage**
```swift
class KeychainManager {
    static func store(_ password: String, for account: String, service: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecValueData as String: password.data(using: .utf8)!
        ]

        SecItemDelete(query as CFDictionary)
        let result = SecItemAdd(query as CFDictionary, nil)
        guard result == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(result))
        }
    }

    static func retrieve(account: String, service: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }

        return String(data: data, encoding: .utf8) ?? ""
    }
}
```

---

## System Integration & Automation

### Login Items & Background Services
**SMAppService Registration**
```swift
import ServiceManagement

func registerLoginItem() throws {
    try SMAppService.mainApp.register()
}

func registerBackgroundService() throws {
    try SMAppService.daemon.register(at: helperBundleURL)
}

func checkLoginStatus() -> SMAppService.Status {
    return SMAppService.mainApp.status
}
```

### Launch Agent/Daemon Configuration
**LaunchAgent (User-Level) plist**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.company.monitor</string>

    <key>ProgramArguments</key>
    <array>
        <string>/Library/LaunchAgents/com.company.monitor/Contents/MacOS/monitor</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>

    <key>StandardOutPath</key>
    <string>/tmp/monitor.out</string>

    <key>StandardErrorPath</key>
    <string>/tmp/monitor.err</string>
</dict>
</plist>
```

**LaunchDaemon (System-Level) plist**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.company.system-service</string>

    <key>ProgramArguments</key>
    <array>
        <string>/Library/LaunchDaemons/com.company.system-service</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>UserName</key>
    <string>_service</string>

    <key>GroupName</key>
    <string>_service</string>

    <key>SessionCreate</key>
    <true/>
</dict>
</plist>
```

### File System Monitoring
**FSEvents with DispatchSourceFileSystemObject**
```swift
class FileSystemMonitor {
    var source: DispatchSourceFileSystemObject?

    func startMonitoring(path: String) {
        let fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor != -1 else { return }

        let queue = DispatchQueue(label: "com.company.fsmon")
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.all],
            queue: queue
        )

        source?.setEventHandler { [weak self] in
            self?.handleFileSystemEvent()
        }

        source?.setCancelHandler {
            close(fileDescriptor)
        }

        source?.resume()
    }

    func handleFileSystemEvent() {
        print("File system change detected")
    }
}
```

**Core Spotlight Indexing**
```swift
import CoreSpotlight

func indexDocument(at url: URL, title: String, content: String) throws {
    let item = CSSearchableItem(
        uniqueIdentifier: url.path,
        domainIdentifier: "com.company.documents",
        attributeSet: CSSearchableItemAttributeSet(itemContentType: "com.apple.package")
    )

    item.attributeSet?.title = title
    item.attributeSet?.contentDescription = content
    item.attributeSet?.relatedUniqueIdentifier = url.path

    try CSSearchableIndex.default().indexSearchableItems([item]) { error in
        if let error = error {
            print("Spotlight indexing error: \(error)")
        }
    }
}
```

---

## Performance Optimization

### Grand Central Dispatch Patterns
**Custom Concurrent Queue with Quality of Service**
```swift
let computeQueue = DispatchQueue(
    label: "com.company.compute",
    qos: .userInitiated,
    attributes: .concurrent
)

computeQueue.async(group: nil, qos: .userInitiated, flags: .assignCurrentContext) {
    let result = expensiveComputation()
    DispatchQueue.main.async {
        updateUI(with: result)
    }
}
```

**Async/Await Pattern**
```swift
func loadData() async throws -> [String] {
    let url = URL(string: "https://api.example.com/data")!
    let (data, _) = try await URLSession.shared.data(from: url)
    let decoded = try JSONDecoder().decode([String].self, from: data)
    return decoded
}

Task {
    do {
        let data = try await loadData()
        print("Data: \(data)")
    } catch {
        print("Error: \(error)")
    }
}
```

### Memory Pressure Handling
**Monitor System Memory Status**
```swift
class MemoryMonitor {
    var source: DispatchSourceMemoryPressure?

    func startMonitoring() {
        let queue = DispatchQueue(label: "com.company.memory-monitor")
        source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.normal, .warning, .critical],
            queue: queue
        )

        source?.setEventHandler { [weak self] in
            self?.handleMemoryPressure()
        }

        source?.resume()
    }

    func handleMemoryPressure() {
        let pressure = ProcessInfo.processInfo.physicalMemory
        print("Memory pressure event, available: \(pressure) bytes")

        // Clear caches, reduce memory footprint
    }
}
```

### Thermal State Management
**Respond to Thermal Conditions**
```swift
let processInfo = ProcessInfo.processInfo

// Check thermal state
if processInfo.thermalState == .nominal {
    print("Normal operation")
} else if processInfo.thermalState == .serious {
    print("Reduce performance")
} else if processInfo.thermalState == .critical {
    print("Minimal operation")
}

// Monitor changes
NotificationCenter.default.addObserver(
    forName: ProcessInfo.thermalStateDidChangeNotification,
    object: nil,
    queue: .main
) { _ in
    print("Thermal state changed to: \(processInfo.thermalState)")
}
```

### Power Management
**Prevent App Nap & Sleep**
```swift
var powerAssertion: IOPMAssertionID = 0

func preventSleep() {
    IOPMAssertionCreateWithName(
        kIOPMAssertionTypeNoDisplaySleep as CFString,
        IOPMAssertionLevel(rawValue: 255),
        "Long-running operation" as CFString,
        &powerAssertion
    )
}

func allowSleep() {
    IOPMAssertionRelease(powerAssertion)
    powerAssertion = 0
}
```

### Metal for GPU Acceleration
**Basic GPU Compute**
```swift
import Metal

class GPUCompute {
    let device = MTLCreateSystemDefaultDevice()!
    let commandQueue: MTLCommandQueue
    let pipeline: MTLComputePipelineState

    init?() {
        commandQueue = device.makeCommandQueue()!

        guard let library = device.makeDefaultLibrary(),
              let function = library.makeFunction(name: "compute_kernel"),
              let pipeline = try? device.makeComputePipelineState(function: function) else {
            return nil
        }

        self.pipeline = pipeline
    }

    func compute(input: [Float]) -> [Float] {
        let buffer = device.makeBuffer(bytes: input, length: MemoryLayout<Float>.size * input.count)!

        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(buffer, offset: 0, index: 0)

        let threadGroupSize = MTLSizeMake(256, 1, 1)
        let threadGroups = MTLSizeMake((input.count + 255) / 256, 1, 1)
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        let result = buffer.contents().assumingMemoryBound(to: Float.self)
        return Array(UnsafeBufferPointer(start: result, count: input.count))
    }
}
```

---

## Reference Links

- **Apple Developer**: https://developer.apple.com/documentation/
- **DriverKit**: https://developer.apple.com/documentation/driverkit
- **Endpoint Security**: https://developer.apple.com/documentation/endpointsecurity
- **Network Extensions**: https://developer.apple.com/documentation/networkextension
- **ServiceManagement**: https://developer.apple.com/documentation/servicemanagement
- **macOS Security**: https://developer.apple.com/documentation/security

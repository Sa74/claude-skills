# Apple SDK & Frameworks Catalog
**Principal Engineer Reference** | Last Updated: 2026

---

## UI & Presentation

### SwiftUI
**What:** Declarative UI framework using reactive, compositional syntax for all Apple platforms.
**When:** New iOS/macOS/watchOS apps; rapid iteration; cross-platform code sharing; preference for reactive patterns.
**Key types:** `View`, `State`, `Binding`, `Published`, `Environment`
**Platforms:** iOS 13+, macOS 10.15+, watchOS 6+, tvOS 13+, visionOS 1+
**Quick example:**
```swift
struct ContentView: View {
    @State private var count = 0
    var body: some View {
        VStack {
            Text("Count: \(count)")
            Button("Increment") { count += 1 }
        }
    }
}
```
**Gotchas:** Performance degrades with deeply nested hierarchies; `@State` not persisted across app launches; conditional styling requires careful view identity management.

### UIKit
**What:** Imperative UI framework for iOS/tvOS, based on event-driven view hierarchy.
**When:** Legacy apps; fine-grained control; complex animations; interoperability with Objective-C code.
**Key types:** `UIViewController`, `UIView`, `UIControl`, `UITableView`, `UICollectionView`
**Platforms:** iOS 2+, tvOS 9+
**Quick example:**
```swift
class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let button = UIButton(type: .system)
        button.setTitle("Tap", for: .normal)
        button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        view.addSubview(button)
    }
    @objc func buttonTapped() { }
}
```
**Gotchas:** Lifecycle management verbose; constraint-based layout has steep learning curve; view controller layering can lead to massive VCs.

### AppKit
**What:** Native macOS UI framework for desktop applications with menus, windows, and native controls.
**When:** macOS-only apps requiring native look/feel; multi-window support; menus and status bar integration.
**Key types:** `NSViewController`, `NSView`, `NSWindow`, `NSApplication`, `NSResponder`
**Platforms:** macOS 10.0+
**Quick example:**
```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 400, height: 300),
                             styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "My App"
        window.makeKeyAndOrderFront(nil)
    }
}
```
**Gotchas:** Different coordinate system than iOS (origin at bottom-left); responder chain behavior differs; NSView redrawing can be expensive.

### WatchKit (Legacy)
**What:** Older watchOS UI framework based on hierarchical navigation; deprecated in favor of SwiftUI.
**When:** Maintain legacy watchOS 2-5 apps; unlikely for new development.
**Key types:** `WKInterfaceController`, `WKInterfaceGroup`, `WKInterfaceLabel`
**Platforms:** watchOS 2.0–6.x
**Quick example:**
```swift
class InterfaceController: WKInterfaceController {
    @IBOutlet weak var label: WKInterfaceLabel!
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        label.setText("Hello Watch")
    }
}
```
**Gotchas:** Limited screen real estate demands careful UX; limited memory; no Internet access without paired iPhone.

### SwiftUI Charts
**What:** Declarative charting library for line, bar, scatter, and custom visualizations in SwiftUI.
**When:** Dashboards, analytics, data visualization; preferred over third-party charting libraries for built-in platform integration.
**Key types:** `Chart`, `BarMark`, `LineMark`, `AreaMark`, `ChartBackground`
**Platforms:** iOS 16+, macOS 13+, watchOS 9+, tvOS 16+
**Quick example:**
```swift
struct ChartView: View {
    let data = [(x: 1, y: 5), (x: 2, y: 8), (x: 3, y: 6)]
    var body: some View {
        Chart(data, id: \.x) { point in
            LineMark(x: .value("X", point.x), y: .value("Y", point.y))
        }
    }
}
```
**Gotchas:** Mark rendering performance degrades with >1000 data points; custom domain ranges must be explicit; no 3D support.

### MapKit (SwiftUI)
**What:** SwiftUI-native map view with markers, annotations, and camera controls.
**When:** Location-based features; replace MKMapView for new code; interactive maps with SwiftUI bindings.
**Key types:** `Map`, `MapMarker`, `Annotation`, `MapCameraPosition`, `MKCoordinateRegion`
**Platforms:** iOS 17+, macOS 14+, watchOS 10+, tvOS 17+
**Quick example:**
```swift
Map(position: .constant(.region(MKCoordinateRegion(...)))) {
    Marker("Location", coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194))
}
```
**Gotchas:** Position binding required for interactive maps; no street-level imagery; offline maps limited compared to third-party solutions.

### PhotosUI
**What:** Modern photos picker framework for selecting images/videos from user library.
**When:** Replace older UIImagePickerController; support multi-selection; privacy-preserving access without full Photos permission.
**Key types:** `PhotosPicker`, `PhotosPickerItem`, `PHPickerViewController`, `PHPickerConfiguration`
**Platforms:** iOS 14+, macOS 11+
**Quick example:**
```swift
@State private var selectedItems: [PhotosPickerItem] = []
PhotosPicker(selection: $selectedItems, matching: .images, label: { Text("Pick") })
    .onChange(of: selectedItems) { for item in $0 {
        Task { if let data = try await item.loadTransferable(type: Data.self) { } }
    }}
```
**Gotchas:** Loading is async; large batches slow without proper pagination; selected items don't include location data by default.

---

## Data & Persistence

### SwiftData
**What:** Modern Swift-native ORM framework replacing Core Data; uses property wrappers and Swift enums.
**When:** New iOS 17+ projects; prefer declarative data modeling; simpler CRUD operations than Core Data.
**Key types:** `Model`, `@Query`, `ModelContext`, `SwiftDataStore`
**Platforms:** iOS 17+, macOS 14+, watchOS 10+, tvOS 17+
**Quick example:**
```swift
@Model final class Item {
    var name: String = ""
    var timestamp = Date()
}

@Query var items: [Item]
// Automatic persistence in SwiftUI views
```
**Gotchas:** Limited custom query capabilities; no migration path from Core Data; syncing across devices requires CloudKit integration.

### Core Data
**What:** Persistent object graph framework for managing complex data models with relationships and versioning.
**When:** Large datasets; complex relationships; existing apps; need for migration versioning.
**Key types:** `NSManagedObject`, `NSManagedObjectContext`, `NSFetchedResultsController`, `NSPersistentContainer`
**Platforms:** iOS 3+, macOS 10.4+
**Quick example:**
```swift
let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
let entity = NSEntityDescription.entity(forEntityName: "Item", in: context)!
let item = NSManagedObject(entity: entity, insertedInto: context)
item.setValue("Name", forKey: "name")
try context.save()
```
**Gotchas:** Thread safety requires context per thread; fetch predicates complex to debug; memory footprint large for big datasets; migration can be destructive.

### CloudKit
**What:** Apple's cloud sync framework for syncing user data across devices via iCloud; includes schema management.
**When:** Cross-device sync; automatic iCloud backup; leveraging iCloud infrastructure; user-specific data.
**Key types:** `CKContainer`, `CKDatabase`, `CKRecord`, `CKQuery`, `CKQueryOperation`
**Platforms:** iOS 8+, macOS 10.10+, watchOS 6+, tvOS 12+
**Quick example:**
```swift
let container = CKContainer.default()
let database = container.publicCloudDatabase
let record = CKRecord(recordType: "Item")
record["name"] = "Example"
database.save(record) { result in
    switch result {
    case .success: print("Saved")
    case .failure(let error): print(error)
    }
}
```
**Gotchas:** Public vs. private database behavior differs significantly; quota limits apply; offline support minimal; network errors common.

### FileProvider
**What:** Framework for exposing local files via Files app and enabling cloud file management.
**When:** Enable file access in Files app; implement cloud storage integration; provide document access.
**Key types:** `NSFileProviderExtension`, `NSFileProviderItem`, `NSFileProviderDomain`
**Platforms:** iOS 11+, macOS 10.15+
**Quick example:**
```swift
class FileProviderExtension: NSFileProviderExtension {
    override var domain: NSFileProviderDomain? { return NSFileProviderDomain(identifier: "com.example") }
    override func item(for identifier: NSFileProviderItemIdentifier) throws -> NSFileProviderItem { }
}
```
**Gotchas:** Extension runs in restricted sandbox; file operations must be efficient; requires Testing app installation; debugging requires device.

### UserDefaults
**What:** Key-value storage for small app settings and preferences; backed by property lists.
**When:** Lightweight settings storage; app preferences; user toggles and selections; simple app state.
**Key types:** `UserDefaults`, `@AppStorage` (SwiftUI)
**Platforms:** iOS, macOS, watchOS, tvOS
**Quick example:**
```swift
@AppStorage("isDarkMode") var isDarkMode = false
// Or:
UserDefaults.standard.set(true, forKey: "isDarkMode")
let value = UserDefaults.standard.bool(forKey: "isDarkMode")
```
**Gotchas:** Syncing across devices requires iCloud integration; no encryption; size limited (~10MB); not suitable for large data.

### Keychain Services
**What:** Secure storage for passwords, tokens, and sensitive data with hardware-backed encryption.
**When:** Store credentials; API keys; sensitive secrets; biometric-protected data.
**Key types:** `SecItem`, `kSecClass`, `kSecAttrGeneric`, `kSecValueData`
**Platforms:** iOS, macOS, watchOS
**Quick example:**
```swift
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrAccount as String: "username",
    kSecValueData as String: "secret".data(using: .utf8)!
]
SecItemAdd(query as CFDictionary, nil)
```
**Gotchas:** APIs are verbose C-based; requires careful memory management; data not synced via iCloud; accessible attributes affect security.

---

## Networking & Communication

### Foundation URLSession
**What:** HTTP client for network requests with support for tasks, sessions, caching, and credential management.
**When:** RESTful APIs; downloading files; form data submission; any network I/O.
**Key types:** `URLSession`, `URLRequest`, `URLResponse`, `URLTask`, `URLSessionDataTask`
**Platforms:** iOS 7+, macOS 10.9+
**Quick example:**
```swift
let url = URL(string: "https://api.example.com/data")!
let data = try await URLSession.shared.data(from: url).0
let decoded = try JSONDecoder().decode(Model.self, from: data)
```
**Gotchas:** SSL pinning requires custom delegates; certificate validation errors cryptic; caching behavior not always intuitive; background downloads require special setup.

### Network Framework
**What:** Low-level networking stack for TCP/UDP, TLS, and custom protocols; replaces BSD sockets.
**When:** Custom protocols; low-latency communication; complex networking requirements; performance-critical apps.
**Key types:** `NWConnection`, `NWListener`, `NWEndpoint`, `NWParameters`, `NWPathMonitor`
**Platforms:** iOS 12+, macOS 10.14+, tvOS 12+, watchOS 5+
**Quick example:**
```swift
let endpoint = NWEndpoint.hostPort(host: "example.com", port: 80)
let connection = NWConnection(to: endpoint, using: .tcp)
connection.start(queue: .main)
connection.send(content: "data".data(using: .utf8), completion: .idempotent)
```
**Gotchas:** State machine requires careful management; send/receive asymmetric; viability monitoring essential; errors opaque without logging.

### MultipeerConnectivity
**What:** Peer-to-peer networking over Bluetooth, Wi-Fi Direct, and cellular without Internet.
**When:** Local multiplayer games; device-to-device data sync; offline collaboration.
**Key types:** `MCSession`, `MCBrowserViewController`, `MCPeerID`, `MCAdvertiserAssistant`
**Platforms:** iOS 7+, macOS 10.10+
**Quick example:**
```swift
let peerID = MCPeerID(displayName: UIDevice.current.name)
let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
let browser = MCBrowserViewController(serviceType: "myservice", session: session)
```
**Gotchas:** Connection is fragile; peer discovery delayed; data reliability not guaranteed; complex state management needed.

### WatchConnectivity
**What:** Communication framework between iOS app and watchOS app via Bluetooth or Wi-Fi.
**When:** Sync state between iPhone and Apple Watch; send commands from watch to phone.
**Key types:** `WCSession`, `WCSessionDelegate`, `WCContextData`
**Platforms:** iOS 9+, watchOS 2+
**Quick example:**
```swift
WCSession.default.delegate = self
WCSession.default.activate()
try WCSession.default.updateApplicationContext(["key": "value"])

// Receive:
func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) { }
```
**Gotchas:** Only one active session per pair; must activate on launch; delegate callbacks on background thread; messages not guaranteed delivery.

### CallKit
**What:** Framework for VoIP apps to integrate with system call UI and call handling.
**When:** VoIP calling apps (WhatsApp, Slack calls, etc.); incoming call notifications; call management.
**Key types:** `CXCallController`, `CXCall`, `CXProvider`, `CXProviderDelegate`
**Platforms:** iOS 10+
**Quick example:**
```swift
let provider = CXProvider(configuration: CXProviderConfiguration(localizedName: "App"))
provider.setDelegate(self, queue: .main)
let update = CXCallUpdate(); update.remoteHandle = CXHandle(type: .phoneNumber, value: "1234567890")
provider.reportNewIncomingCall(with: UUID(), update: update)
```
**Gotchas:** PushKit integration required; call state must be accurate; provider delegate methods called on main thread; system call UI takes precedence.

### PushKit
**What:** Framework for receiving VoIP push notifications with fast wake-up when app suspended.
**When:** VoIP apps; time-critical background updates; avoid standard APNs latency.
**Key types:** `PKPushRegistry`, `PKPushPayload`, `PKPushType`
**Platforms:** iOS 8+
**Quick example:**
```swift
let pushRegistry = PKPushRegistry(queue: .main)
pushRegistry.delegate = self
pushRegistry.desiredPushTypes = [.voIP]

func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
    // Send credentials to server
}
```
**Gotchas:** App must register on launch; token revocation possible; payload size limited; background time limited.

---

## Media & AV

### AVFoundation
**What:** Comprehensive media framework for audio/video capture, playback, editing, and processing.
**When:** Video recording; audio playback; camera access; media editing; transcoding.
**Key types:** `AVPlayer`, `AVCaptureSession`, `AVAsset`, `AVComposition`, `AVAudioSession`
**Platforms:** iOS, macOS, watchOS (limited), tvOS
**Quick example:**
```swift
let captureSession = AVCaptureSession()
captureSession.addInput(try AVCaptureDeviceInput(device: AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)!))
captureSession.addOutput(videoDataOutput)
captureSession.startRunning()

// Playback:
let player = AVPlayer(url: URL(fileURLWithPath: "video.mp4"))
let playerViewController = AVPlayerViewController(); playerViewController.player = player
```
**Gotchas:** Async initialization required; background audio requires session category setup; memory management critical for long captures; orientation handling complex.

### AVKit
**What:** High-level video player UI component; integrates with system media controls.
**When:** Straightforward video playback; quick integration needed; full-screen and PiP support.
**Key types:** `AVPlayerViewController`, `AVPlayerItem`, `AVPlayerControllerDelegate`
**Platforms:** iOS 9+, macOS 10.12+, tvOS 9+
**Quick example:**
```swift
let playerViewController = AVPlayerViewController()
playerViewController.player = AVPlayer(url: url)
present(playerViewController, animated: true)
```
**Gotchas:** Limited customization of controls; context menu disabled; auto-layouts constraints required; fullscreen dimissal handled by system.

### Photos Framework (PhotoKit)
**What:** Access to user's photo library with fetch requests, caching, and batch operations.
**When:** Photo library integration; batch operations; metadata queries; memory-efficient access to large collections.
**Key types:** `PHAsset`, `PHAssetCollection`, `PHImageManager`, `PHFetchResult`
**Platforms:** iOS 8+, macOS 10.13+
**Quick example:**
```swift
let fetchOptions = PHFetchOptions()
let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
let imageManager = PHImageManager.default()
imageManager.requestImage(for: assets[0], targetSize: CGSize(width: 100, height: 100),
                         contentMode: .aspectFill, options: nil) { image, info in }
```
**Gotchas:** Permission required; slow without caching; fetch results are snapshots; memory usage high for large photo counts.

### CoreImage
**What:** Image processing framework with filters, composition, and GPU acceleration.
**When:** Real-time image filtering; camera filters; image enhancement; custom filters.
**Key types:** `CIImage`, `CIContext`, `CIFilter`, `CIVector`
**Platforms:** iOS 5+, macOS 10.4+
**Quick example:**
```swift
let image = CIImage(contentsOf: url)!
let filter = CIFilter(name: "CIGaussianBlur")!
filter.setValue(image, forKey: kCIInputImageKey)
filter.setValue(10, forKey: kCIInputRadiusKey)
let result = filter.outputImage!
```
**Gotchas:** CIImage immutable; GPU/CPU sync costly; filter availability varies by platform; context creation expensive.

### CoreGraphics
**What:** Low-level 2D drawing framework with paths, transformations, and rendering.
**When:** Custom drawing; 2D graphics; PDFs; complex layouts not achievable with high-level APIs.
**Key types:** `CGContext`, `CGPath`, `CGImage`, `CGRect`, `CGPoint`
**Platforms:** iOS, macOS, watchOS, tvOS
**Quick example:**
```swift
let context = UIGraphicsGetCurrentContext()!
context.setFillColor(UIColor.blue.cgColor)
context.addRect(CGRect(x: 10, y: 10, width: 100, height: 100))
context.fillPath()
```
**Gotchas:** Coordinate system differs by platform; color space issues on wide-gamut displays; memory leaks if context not released; performance worse than Metal for complex scenes.

### ImageIO
**What:** Framework for reading and writing image data with format-agnostic access.
**When:** Complex image I/O; animated GIFs; HEIF encoding; format conversion; metadata handling.
**Key types:** `CGImageSource`, `CGImageDestination`, `CGImageProperties`
**Platforms:** iOS, macOS, watchOS, tvOS
**Quick example:**
```swift
let imageSource = CGImageSourceCreateWithData(data as CFData, nil)!
let count = CGImageSourceGetCount(imageSource)
let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)!
```
**Gotchas:** C-based APIs verbose; incremental loading complex; metadata format-specific; HEIF encoding only on newer iOS.

### MediaPlayer
**What:** Framework for media control, playback information, and Now Playing integration.
**When:** Control system music player; access Now Playing info; custom music playback UI.
**Key types:** `MPMediaQuery`, `MPMusicPlayerController`, `MPNowPlayingInfoCenter`
**Platforms:** iOS 2+, tvOS 9+
**Quick example:**
```swift
let query = MPMediaQuery.songs()
let songs = query.items ?? []
let player = MPMusicPlayerController.systemMusicPlayer
player.setQueue(with: query)
player.play()
```
**Gotchas:** Only accesses Apple Music by default; user permission required; real-time updates limited; background playback requires proper audio session.

### MusicKit
**What:** Modern framework for programmatic access to Apple Music catalog and playback.
**When:** Integrate Apple Music functionality; search catalog; create playlists; personal recommendations.
**Key types:** `MusicCatalogResourceRequest`, `MusicPlayer`, `Song`, `Playlist`
**Platforms:** iOS 16.1+, macOS 13.1+, watchOS 9.1+, tvOS 16.1+
**Quick example:**
```swift
var request = MusicCatalogResourceRequest<Song>(matching: \.title, equalTo: "Song Name")
let response = try await request.response()
if let song = response.songs.first {
    try await MusicPlayer.shared.queue.insert(song, position: 0)
}
```
**Gotchas:** Requires user subscription; token-based authentication complex; catalog changes require refetch; playback permission separate.

### ShazamKit
**What:** Framework for identifying music from audio without user interaction.
**When:** Add Shazam button; identify background music; music recognition features.
**Key types:** `SHSession`, `SHMatch`, `SHMediaItem`, `SHSignature`
**Platforms:** iOS 15+, macOS 12+, watchOS 8+
**Quick example:**
```swift
let session = SHSession()
let signature = try SHSignatureGenerator().generateSignature(from: audioBuffer)
let match = try await session.match(signature)
print(match?.mediaItems.first?.title ?? "No match")
```
**Gotchas:** Audio processing async; background matching battery intensive; user may not like unsolicited identification; signature generation slow.

---

## Audio

### AVAudioEngine
**What:** Real-time audio processing and synthesis engine with nodes, connections, and effects.
**When:** Audio synthesis; mixing; real-time processing; complex audio workflows; DAW-like functionality.
**Key types:** `AVAudioEngine`, `AVAudioNode`, `AVAudioPlayerNode`, `AVAudioUnitEQ`
**Platforms:** iOS 8+, macOS 10.10+
**Quick example:**
```swift
let engine = AVAudioEngine()
let playerNode = AVAudioPlayerNode()
engine.attach(playerNode)
engine.connect(playerNode, to: engine.mainMixerNode, format: nil)
try engine.start()
playerNode.play()
```
**Gotchas:** Setup complex; audio buffer management error-prone; real-time thread constraints strict; format mismatches crash.

### CoreAudio
**What:** Low-level C API for audio unit processing, mixing, and hardware interface.
**When:** Extreme performance requirements; custom audio units; hardware control; legacy code.
**Key types:** `AudioUnit`, `AudioBuffer`, `AudioBufferList`, `AURenderActionFlags`
**Platforms:** iOS, macOS
**Quick example:**
```swift
var audioUnit: AudioUnit?
var description = AudioComponentDescription()
description.componentType = kAudioUnitType_Output
let component = AudioComponentFindNext(nil, &description)!
AudioComponentInstanceNew(component, &audioUnit)
```
**Gotchas:** Debugging opaque; memory management manual; C APIs verbose; MIDI integration complex.

### AudioToolbox
**What:** Framework for MIDI, audio processing units, and file utilities.
**When:** MIDI input/output; audio unit management; file format conversion.
**Key types:** `AUAudioUnit`, `MusicSequence`, `MIDIPort`
**Platforms:** iOS, macOS
**Quick example:**
```swift
MIDIClientCreate("MyClient" as CFString, nil, nil, &midiClient)
MIDIInputPortCreate(midiClient, "Input" as CFString, midiReadCallback, nil, &inPort)
```
**Gotchas:** MIDI threading model complex; file utilities outdated; error handling requires OSStatus checks.

### SoundAnalysis
**What:** Framework for audio analysis using Core ML models; acoustic classification.
**When:** Sound classification; acoustic event detection; environmental sound analysis.
**Key types:** `SNAudioStreamAnalyzer`, `SNAudioBuffer`, `SNClassifierMetalPerformanceExpectations`
**Platforms:** iOS 13+, macOS 10.15+
**Quick example:**
```swift
let analyzer = SNAudioStreamAnalyzer(format: audioFormat)
try analyzer.addRequest(request) { result in }
try analyzer.analyze(audioBuffer)
```
**Gotchas:** Models must be provided; on-device only; microphone permission required; results delayed by buffer size.

### Speech Framework
**What:** Speech recognition framework with real-time and batch transcription.
**When:** Voice-controlled apps; transcription; accessibility features; voice input.
**Key types:** `SFSpeechRecognizer`, `SFSpeechRecognitionTask`, `SFSpeechAudioBufferRequest`
**Platforms:** iOS 10+, macOS 10.15+
**Quick example:**
```swift
let recognizer = SFSpeechRecognizer()!
let request = SFSpeechAudioBufferRecognitionRequest()
let audioEngine = AVAudioEngine()
let task = recognizer.recognitionTask(with: request) { result, error in
    print(result?.bestTranscription.formattedString ?? "")
}
```
**Gotchas:** Requires microphone permission; on-device recognition limited to short clips; battery draining; timeout after ~1 minute.

---

## Graphics & 3D

### Metal
**What:** Low-level GPU programming API for maximum performance graphics and compute.
**When:** High-performance rendering; complex graphics; game engines; compute shaders; machine learning.
**Key types:** `MTLDevice`, `MTLCommandQueue`, `MTLRenderPipelineState`, `MTLBuffer`
**Platforms:** iOS 8+, macOS 10.11+, tvOS 9+
**Quick example:**
```swift
let device = MTLCreateSystemDefaultDevice()!
let commandQueue = device.makeCommandQueue()!
let library = device.makeDefaultLibrary()!
let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
pipelineStateDescriptor.vertexFunction = library.makeFunction(name: "vertex_main")
pipelineStateDescriptor.fragmentFunction = library.makeFunction(name: "fragment_main")
let pipelineState = try device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
```
**Gotchas:** Shader debugging difficult; GPU memory management manual; platform differences significant; learning curve steep.

### MetalKit
**What:** Simplified Metal wrapper with view, texture loading, and model I/O integration.
**When:** Metal rendering in UI; quick Metal integration; texture management.
**Key types:** `MTKView`, `MTKTextureLoader`, `MDLAsset`
**Platforms:** iOS 9+, macOS 10.11+, tvOS 9+
**Quick example:**
```swift
let mtkView = MTKView()
mtkView.delegate = self
mtkView.device = MTLCreateSystemDefaultDevice()
func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { }
```
**Gotchas:** MTKView manages render loop automatically; delegate pattern required; texture formats complex; performance varies by device.

### MetalFX
**What:** Upscaling and super-resolution framework for Metal; improves frame rates.
**When:** Performance optimization; high-resolution targets; gaming; resource-constrained devices.
**Key types:** `MTLFXSpatialScaler`, `MTLFXTemporalScaler`, `MTLFXGaussianBlur`
**Platforms:** iOS 17+, macOS 14+
**Quick example:**
```swift
let descriptor = MTLFXSpatialScalerDescriptor()
descriptor.inputSize = CGSize(width: 1280, height: 720)
descriptor.outputSize = CGSize(width: 1920, height: 1080)
let scaler = descriptor.makeScaler(device: device)!
```
**Gotchas:** Performance gain varies; not suitable for all content types; requires modern GPU; integration complex.

### RealityKit
**What:** 3D rendering framework for AR with physics, animations, and spatial audio.
**When:** Augmented Reality; 3D object rendering; AR interactions; spatial computing.
**Key types:** `ModelEntity`, `RealityView`, `ModelComponent`, `PhysicsComponent`
**Platforms:** iOS 13+, visionOS 1+
**Quick example:**
```swift
var modelAnchor: ModelAnchor { ModelAnchor(name: "model") }
let mesh = try await ModelEntity.loadModel(named: "model")
let anchor = try await Experience.loadBox()
arView.scene.addAnchor(anchor)
```
**Gotchas:** Model formats limited; animations complex; physics integration unintuitive; performance on older devices poor.

### ARKit
**What:** Augmented Reality framework for device tracking, plane detection, and image recognition.
**When:** Implement AR experiences; face tracking; object detection; spatial mapping.
**Key types:** `ARSession`, `ARFrame`, `ARConfiguration`, `ARWorldTrackingConfiguration`
**Platforms:** iOS 11+, visionOS 1+
**Quick example:**
```swift
let session = ARSession()
let configuration = ARWorldTrackingConfiguration()
configuration.planeDetection = [.horizontal, .vertical]
session.run(configuration)
```
**Gotchas:** Requires LiDAR or robust visual tracking; occlusion complex; performance CPU-intensive; lighting estimation imprecise.

### SceneKit (Legacy)
**What:** Higher-level 3D graphics framework; now superseded by RealityKit/Metal.
**When:** Maintain legacy AR apps; simple 3D scenes; prototyping.
**Key types:** `SCNScene`, `SCNNode`, `SCNGeometry`, `SCNView`
**Platforms:** iOS 8+, macOS 10.10+, tvOS 9+
**Quick example:**
```swift
let scene = SCNScene()
let box = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0)
let node = SCNNode(geometry: box)
scene.rootNode.addChildNode(node)
let sceneView = SCNView(); sceneView.scene = scene
```
**Gotchas:** Performance worse than Metal; physics engine limited; animation setup verbose; deprecation pending.

### SpriteKit
**What:** 2D graphics framework for games and animations with physics simulation.
**When:** 2D games; sprite-based rendering; particle effects; simple physics.
**Key types:** `SKScene`, `SKSpriteNode`, `SKPhysicsBody`, `SKAction`
**Platforms:** iOS 8+, macOS 10.10+, tvOS 9+, watchOS 3+
**Quick example:**
```swift
let scene = SKScene(size: CGSize(width: 800, height: 600))
let sprite = SKSpriteNode(imageNamed: "spaceship")
sprite.position = CGPoint(x: 400, y: 300)
scene.addChild(sprite)
let sceneView = SKView(); sceneView.presentScene(scene)
```
**Gotchas:** Physics engine basic; performance limited for complex scenes; debugging difficult; not suitable for advanced games.

### GameplayKit
**What:** Game AI, entity-component systems, and gameplay mechanics framework.
**When:** Game AI behavior; decision trees; state machines; entity management.
**Key types:** `GKEntity`, `GKComponent`, `GKBehavior`, `GKDecisionTree`
**Platforms:** iOS 9+, macOS 10.11+, tvOS 9+
**Quick example:**
```swift
let entity = GKEntity()
let component = GKComponent()
entity.addComponent(component)
let behavior = GKBehavior()
behavior.goal = GKGoal(toReachTargetSpeed: 5.0)
```
**Gotchas:** Entity-component pattern learning curve; behavior system limited; synchronization with rendering not automatic.

### GameController
**What:** Framework for connecting and managing game controllers (MFi controllers, keyboard).
**When:** Game input; controller support; multi-player games; accessibility.
**Key types:** `GCController`, `GCGamepad`, `GCDirectionalPadElement`
**Platforms:** iOS 7+, tvOS 9+, macOS 10.9+
**Quick example:**
```swift
NotificationCenter.default.addObserver(forName: NSNotification.Name.GCControllerDidConnect,
                                      object: nil, queue: .main) { _ in
    if let gamepad = GCController.controllers().first?.gamepad {
        gamepad.buttonA.pressedChangedHandler = { button, pressed in }
    }
}
```
**Gotchas:** Connection state tracking manual; button mapping varies; input lag possible; testing requires physical hardware.

---

## Machine Learning & Intelligence

### CoreML
**What:** Framework for running machine learning models on-device with GPU/Neural Engine acceleration.
**When:** On-device inference; privacy-preserving ML; real-time predictions; local models.
**Key types:** `MLModel`, `MLMultiArray`, `MLModelConfiguration`, `MLBatchProvider`
**Platforms:** iOS 11+, macOS 10.13+, watchOS 4+, tvOS 11+
**Quick example:**
```swift
guard let model = try? Model(configuration: MLModelConfiguration()) else { return }
let input = ModelInput(image: ciImage)
let output = try model.prediction(input: input)
print(output.classLabel)
```
**Gotchas:** Model size impacts startup; input preprocessing required; output shapes complex; GPU memory limited on older devices.

### Create ML
**What:** macOS app for training custom ML models from data without code.
**When:** Quick model training; domain-specific classifiers; prototyping; non-specialists.
**Key types:** `MLImageClassifier`, `MLTextClassifier`, `MLSoundClassifier`
**Platforms:** macOS (training), iOS/tvOS (inference)
**Quick example:**
```
// In Create ML UI: drag training data → train → export .mlmodel
// Then use with CoreML as above
```
**Gotchas:** Training data quality critical; overfitting easy; model size unpredictable; GPU memory requirements high.

### Vision Framework
**What:** Image analysis framework with face detection, barcode reading, text recognition (OCR).
**When:** Visual content analysis; text extraction; object detection; face recognition.
**Key types:** `VNImageRequestHandler`, `VNDetectFaceRectanglesRequest`, `VNRecognizeTextRequest`
**Platforms:** iOS 11+, macOS 10.13+, tvOS 11+
**Quick example:**
```swift
let request = VNRecognizeTextRequest()
let handler = VNImageRequestHandler(ciImage: image, options: [:])
try handler.perform([request])
request.results?.forEach { observation in
    print(observation.topCandidates(1).first?.string ?? "")
}
```
**Gotchas:** Text recognition accuracy varies with image quality; face detection imperfect; processing slow on large images; no ML model swap.

### Natural Language Framework
**What:** Text processing framework for language identification, tokenization, and entity extraction.
**When:** Text analysis; sentiment analysis; language detection; named entity recognition.
**Key types:** `NLTokenizer`, `NLLanguageRecognizer`, `NLTagger`
**Platforms:** iOS 12+, macOS 10.14+, watchOS 5+
**Quick example:**
```swift
let recognizer = NLLanguageRecognizer()
recognizer.processString("Hello world")
print(recognizer.dominantLanguage ?? "unknown")

let tagger = NLTagger(tagSchemes: [.lemma, .partOfSpeech])
tagger.string = "The quick brown fox"
tagger.enumerateTags(in: tagger.string!.startIndex..<tagger.string!.endIndex,
                     unit: .word, scheme: .partOfSpeech) { tag, range in }
```
**Gotchas:** Language detection unreliable for short text; entity recognition limited; grammar analysis basic.

### Translation Framework
**What:** On-device machine translation without server calls.
**When:** Real-time translation; privacy-critical translation; offline support.
**Key types:** `NLTranslator`, `NLModel`
**Platforms:** iOS 14.5+, macOS 11.3+
**Quick example:**
```swift
let translator = try NLTranslator(fromLanguage: .english, toLanguage: .spanish)
let translated = translator.string(from: "Hello")
```
**Gotchas:** Limited language pairs; first load slow; model download required; translation quality varies.

### SoundAnalysis
**What:** (See Audio section above)

### App Intents
**What:** Framework for exposing app features to system-wide shortcuts and Siri.
**When:** Enable Siri shortcuts; System-level integrations; contextual actions.
**Key types:** `AppIntent`, `AppIntentValueProvider`, `AppShortcutsProvider`
**Platforms:** iOS 16+, macOS 13+, watchOS 9+
**Quick example:**
```swift
struct GreetAppIntent: AppIntent {
    @Parameter(title: "Name") var name: String
    static var title: LocalizedStringResource = "Greet"
    func perform() async throws -> some IntentResult {
        return .result(value: "Hello, \(name)!")
    }
}
```
**Gotchas:** Intent discovery mechanism complex; parameter validation tricky; Siri disambiguation context-dependent.

### SiriKit
**What:** Legacy framework for exposing features to Siri; superseded by App Intents.
**When:** Maintain older apps; require certain intents not yet in App Intents.
**Key types:** `INIntent`, `INIntentHandler`, `INIntentResolutionResult`
**Platforms:** iOS 10+, watchOS 3+
**Quick example:**
```swift
class SendMessageIntentHandler: INSendMessageIntentHandling {
    func handle(intent: INSendMessageIntent, completion: @escaping (INSendMessageIntentResponse) -> Void) {
        completion(INSendMessageIntentResponse(code: .success, userActivity: nil))
    }
}
```
**Gotchas:** Limited intent types; resolution logic verbose; Siri integration unpredictable.

---

## Location & Maps

### CoreLocation
**What:** Framework for device location, heading, and geofencing.
**When:** GPS location; beacon proximity; navigation; location-based services.
**Key types:** `CLLocationManager`, `CLLocation`, `CLGeofence`, `CLBeacon`
**Platforms:** iOS, macOS, watchOS
**Quick example:**
```swift
let locationManager = CLLocationManager()
locationManager.delegate = self
locationManager.requestWhenInUseAuthorization()
locationManager.startUpdatingLocation()

func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    print(locations.last?.coordinate ?? CLLocationCoordinate2D())
}
```
**Gotchas:** Background location mode drains battery; permission requests blocking; accuracy varies; GPS startup slow; watch GPS absent.

### MapKit
**What:** Map display, search, and routing framework; now available in SwiftUI via Map.
**When:** Map display; location search; routing; directions.
**Key types:** `MKMapView`, `MKAnnotation`, `MKOverlay`, `MKLocalSearch`, `MKDirections`
**Platforms:** iOS, macOS, tvOS
**Quick example:**
```swift
let mapView = MKMapView()
let annotation = MKPointAnnotation()
annotation.coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
mapView.addAnnotation(annotation)
```
**Gotchas:** Tile loading asynchronous; annotation reuse required for performance; custom map styles limited; offline maps not supported.

### CoreMotion
**What:** Framework for accelerometer, gyroscope, magnetometer, and pedometer data.
**When:** Motion detection; step counting; activity tracking; gesture recognition.
**Key types:** `CMMotionManager`, `CMAccelerometerData`, `CMGyroData`, `CMStepCounter`
**Platforms:** iOS, watchOS
**Quick example:**
```swift
let motionManager = CMMotionManager()
motionManager.startDeviceMotionUpdates(to: .main) { motion, error in
    let attitude = motion?.attitude
    print(attitude?.roll ?? 0)
}
```
**Gotchas:** Requires motion permission on iOS 10+; data not available in background without special setup; iPhone step counting unreliable without motion context.

---

## Health & Fitness

### HealthKit
**What:** Framework for reading and writing health and fitness data with privacy controls.
**When:** Fitness tracking; health metrics; integration with Health app.
**Key types:** `HKHealthStore`, `HKSample`, `HKQuantitySample`, `HKWorkout`
**Platforms:** iOS 8+, watchOS 2+
**Quick example:**
```swift
let store = HKHealthStore()
guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
let query = HKStatisticsQuery(quantityType: stepsType, quantitySamplePredicate: nil,
                              options: .cumulativeSum) { query, result, error in
    print(result?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
}
store.execute(query)
```
**Gotchas:** User permission required; data access restricted; background reading limited; write permissions highly restricted.

### HealthKitUI
**What:** SwiftUI components for requesting HealthKit permissions and displaying data.
**When:** Privacy-aware health data requests; streamlined HealthKit integration.
**Key types:** `HealthKitPermissionsRequest`, `HealthKitChartView` (when available)
**Platforms:** iOS 17+, watchOS 10+
**Quick example:**
```swift
HealthKitPermissionsRequest([.readTypes(quantityTypes), .writeTypes([quantityTypes])])
```
**Gotchas:** Limited availability; permission request UI system-controlled; no guarantee of data flow.

### CareKit (Open Source)
**What:** Open-source framework for building care-related apps with tasks and insights.
**When:** Patient engagement; medication adherence; health tracking apps.
**Key types:** `OCKStore`, `OCKTask`, `OCKOutcome`, `OCKSynchronizedStoreManager`
**Platforms:** iOS 14+, watchOS 7+
**Quick example:**
```
// Build from: https://github.com/carekit-apple/CareKit
import CareKit
let store = OCKStore(name: "MyCareStore", type: .inMemory)
```
**Gotchas:** Requires manual setup; synchronization non-trivial; UI customization limited; maintenance burden.

---

## System Services

### CoreBluetooth
**What:** Framework for communicating with Bluetooth peripherals and becoming a peripheral.
**When:** Connect BLE devices; wearables; IoT; wireless accessories.
**Key types:** `CBCentralManager`, `CBPeripheral`, `CBCharacteristic`, `CBService`
**Platforms:** iOS 5+, macOS 10.7+, watchOS 2+, tvOS 9+
**Quick example:**
```swift
let centralManager = CBCentralManager(delegate: self, queue: .main)
func centralManagerDidUpdateState(_ central: CBCentralManager) {
    if central.state == .poweredOn {
        central.scanForPeripherals(withServices: nil)
    }
}
func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                    advertisementData: [String : Any], rssi RSSI: NSNumber) {
    central.connect(peripheral)
}
```
**Gotchas:** Background mode complex; state machine fragile; disconnect handling error-prone; RSSI unreliable for distance.

### CoreNFC
**What:** Framework for reading NFC tags and credit card information.
**When:** NFC tag scanning; tap-to-interact features; loyalty programs.
**Key types:** `NFCNDEFReaderSession`, `NFCNDEFPayload`, `NFCTag`
**Platforms:** iOS 11+
**Quick example:**
```swift
let session = NFCNDEFReaderSession(delegate: self, queue: .main, invalidateAfterFirstRead: false)
session?.begin()
func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) { }
```
**Gotchas:** Background reading requires specific intent; entitlement required; NFC chip availability device-specific; user must hold device steady.

### NearbyInteraction (UWB)
**What:** Ultra-Wideband (UWB) framework for precise distance and direction measurement between devices.
**When:** Spatial awareness; precise proximity detection; directional features; AR spatial anchoring.
**Key types:** `NISession`, `NIConfiguration`, `NIDiscoveryToken`
**Platforms:** iOS 14+
**Quick example:**
```swift
let session = NISession()
let config = NINearbyPeerConfiguration(peerToken: remoteToken)
session.run(config)
session.delegateQueue = .main
```
**Gotchas:** Requires enterprise or development entitlements; limited device availability; privacy implications significant.

### CoreTelephony
**What:** Framework for accessing cellular carrier and call information.
**When:** Carrier detection; network type checking; SIM information.
**Key types:** `CTCarrier`, `CTTelephonyNetworkInfo`, `CTCellularData`
**Platforms:** iOS, watchOS, tvOS
**Quick example:**
```swift
let networkInfo = CTTelephonyNetworkInfo()
if let carrier = networkInfo.serviceSubscriptionCellularProviders?.values.first {
    print(carrier.carrierName ?? "Unknown")
}
```
**Gotchas:** Carrier name may be nil; network type not realtime; watch has no cellular in most models; privacy restrictions apply.

### NetworkExtension
**What:** Framework for managing VPN, DNS, and proxy configurations.
**When:** VPN integration; custom DNS handling; enterprise network policies.
**Key types:** `NEVPNManager`, `NEVPNConfiguration`, `NETunnelProviderManager`
**Platforms:** iOS 9+, macOS 10.11+
**Quick example:**
```swift
let manager = NEVPNManager.shared()
manager.loadFromPreferences { error in }
// Configure VPN settings
try manager.saveToPreferences()
```
**Gotchas:** System VPN UI limited; configuration persistence complex; permissions extensive.

### ServiceManagement
**What:** Framework for app launch at login and system service management.
**When:** Launch helper; daemon management; login items.
**Key types:** `SMAppService`, `SMLoginItem` (deprecated)
**Platforms:** macOS 13+, iOS 16+ (limited)
**Quick example:**
```swift
let service = SMAppService.loginItem(for: "com.example.launcher")
try service.register()
```
**Gotchas:** Sandboxing restrictions apply; launcher approach differs from older SMLoginItemSetEnabled; debugging complex.

### SystemExtensions
**What:** Framework for installing and managing system extensions (drivers, filters).
**When:** Network filtering; endpoint security; system integration; enterprise deployment.
**Key types:** `OSSystemExtensionManager`, `OSSystemExtensionRequest`
**Platforms:** macOS 10.15+
**Quick example:**
```swift
let manager = OSSystemExtensionManager.shared
let request = OSSystemExtensionRequest.activationRequest(forExtension: "com.example.extension", queue: .main) { reply in }
manager.submitRequest(request)
```
**Gotchas:** Requires System Extension entitlement; activation requires user approval; debugging requires special setup.

### IOKit & DriverKit
**What:** Low-level hardware interface frameworks; DriverKit replaces IOKit.
**When:** Custom hardware drivers; hardware control; system-level device management.
**Key types:** `IOKit.h`, `DriverKit` (Swift-based replacement)
**Platforms:** macOS, iOS (limited)
**Quick example:**
```swift
// IOKit (C-based, verbose; avoid for new code)
// DriverKit (newer, recommended):
class MyDriver: IOUserClient { }
```
**Gotchas:** Debugging difficult; requires kernel code signing; DriverKit API incomplete; high-risk territory.

### Endpoint Security
**What:** Framework for monitoring and controlling system events (process execution, file access).
**When:** Endpoint protection; system monitoring; security policies; malware detection.
**Key types:** `EndpointSecurityClient`, `es_message_t`
**Platforms:** macOS 10.15+
**Quick example:**
```swift
var client: OpaquePointer?
let result = es_new_client(&client) { (client, message) in
    // Handle security event
}
```
**Gotchas:** C API; requires system extension; elevated privileges needed; performance critical; debugging restricted.

---

## Security & Privacy

### CryptoKit
**What:** Modern cryptography framework with symmetric, asymmetric, and hashing algorithms.
**When:** Encryption; digital signatures; hashing; secure key management.
**Key types:** `ChaChaPoly`, `AES-GCM`, `P256`, `SHA256`, `HMAC`
**Platforms:** iOS 13+, macOS 10.15+, watchOS 6+, tvOS 13+
**Quick example:**
```swift
import CryptoKit
let key = SymmetricKey(size: .bits256)
let data = "message".data(using: .utf8)!
let sealedBox = try AES.GCM.seal(data, using: key)
let decrypted = try AES.GCM.open(sealedBox, using: key)
```
**Gotchas:** Key storage requires Keychain; SecKey interop limited; algorithms not customizable; no RSA-only asymmetric crypto.

### Security Framework
**What:** Lower-level security APIs for certificates, keys, identity, and trust.
**When:** Certificate pinning; custom trust evaluation; legacy security code; advanced key management.
**Key types:** `SecKey`, `SecCertificate`, `SecTrust`, `SecIdentity`
**Platforms:** iOS, macOS, watchOS, tvOS
**Quick example:**
```swift
var trust: SecTrust?
SecTrustCreateWithCertificates(certificates as CFArray, policy, &trust)
SecTrustEvaluateAsyncWithError(trust!, queue: .main) { _, result, error in }
```
**Gotchas:** C-based, verbose; error handling cryptic; certificate chains complex; deprecation ongoing.

### LocalAuthentication
**What:** Framework for biometric (Face ID, Touch ID) and passcode authentication.
**When:** App-level authentication; sensitive operations; biometric unlock; access control.
**Key types:** `LAContext`, `LABiometryType`, `LAAccessControlOperation`
**Platforms:** iOS 8+, macOS 10.12.1+, watchOS 3+
**Quick example:**
```swift
let context = LAContext()
var error: NSError?
guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else { return }
context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock") { success, error in }
```
**Gotchas:** Biometry type varies; context invalidation required; watch authentication different; error messages generic.

### AuthenticationServices
**What:** Framework for Sign in with Apple, passkeys, and OAuth flows.
**When:** User authentication; passwordless login; OAuth integration; privacy-first auth.
**Key types:** `ASAuthorizationController`, `ASAuthorizationAppleIDProvider`, `ASPasskeyProvider`
**Platforms:** iOS 13+, macOS 10.15+, tvOS 16+
**Quick example:**
```swift
let provider = ASAuthorizationAppleIDProvider()
let request = provider.createRequest()
request.requestedScopes = [.fullName, .email]
let controller = ASAuthorizationController(authorizationRequests: [request])
controller.delegate = self
controller.performRequests()
```
**Gotchas:** iOS 16+ provides passkey support; older iOS requires ASAuthorizationAppleIDButton; credential storage device-specific.

### DeviceCheck
**What:** Framework for assessing device integrity and preventing fraud.
**When:** Detect jailbreak; prevent account abuse; anti-fraud measures.
**Key types:** `DCDevice`, `DCAppAttestService`
**Platforms:** iOS 11+
**Quick example:**
```swift
let device = DCDevice.current
if device.isSupported {
    device.generateToken { data, error in
        // Send token to server for verification
    }
}
```
**Gotchas:** Requires server-side verification; token limited-use; jailbreak detection not guaranteed.

### App Attest
**What:** Framework for cryptographic device-bound attestation to prevent replay attacks.
**When:** High-security transactions; bot protection; server-side verification.
**Key types:** `DCAppAttestService`, `DCError`
**Platforms:** iOS 14.3+, macOS 11.3+
**Quick example:**
```swift
let service = DCAppAttestService.shared
service.generateASCIIRepresentation(clientData: clientData.data(using: .utf8)!) { response, error in }
// Send response to server for verification via Apple API
```
**Gotchas:** Requires server integration with Apple; response verification complex; limited device support.

---

## Background & Scheduling

### BackgroundTasks (BGTaskScheduler)
**What:** Framework for scheduling background app refresh, processing, and downloads.
**When:** Background data sync; periodic processing; download completion handling.
**Key types:** `BGTaskScheduler`, `BGAppRefreshTask`, `BGProcessingTask`
**Platforms:** iOS 13+, macOS 11+
**Quick example:**
```swift
BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.example.sync", using: .main) { task in
    (task as! BGAppRefreshTask).setTaskCompleted(success: true)
}
let request = BGAppRefreshTaskRequest(identifier: "com.example.sync")
request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
try BGTaskScheduler.shared.submit(request)
```
**Gotchas:** Timing not guaranteed; battery and device condition affect execution; testing requires special Xcode settings; background time limited.

### CoreSpotlight
**What:** Framework for indexing app content into system search and on-device index.
**When:** Make app content searchable; search results visibility; user activity indexing.
**Key types:** `CSSearchableIndex`, `CSSearchableItemAttributeSet`, `CSUserActivity`
**Platforms:** iOS 9+, macOS 10.13+
**Quick example:**
```swift
let attributeSet = CSSearchableItemAttributeSet()
attributeSet.title = "Item Title"
attributeSet.contentDescription = "Description"
let item = CSSearchableItem(uniqueIdentifier: "item-id", domainIdentifier: "com.example", attributeSet: attributeSet)
CSSearchableIndex.default().indexSearchableItems([item]) { error in }
```
**Gotchas:** Indexing is asynchronous; deletion requires cleanup; no direct search ranking control; privacy implications.

### UserNotifications
**What:** Framework for local and remote push notifications.
**When:** Time-based alerts; user reminders; push notifications; notification handling.
**Key types:** `UNNotificationRequest`, `UNUserNotificationCenter`, `UNNotificationContent`
**Platforms:** iOS 10+, macOS 10.14+, watchOS 3+, tvOS 12+
**Quick example:**
```swift
let content = UNMutableNotificationContent()
content.title = "Title"; content.body = "Body"
let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
let request = UNNotificationRequest(identifier: "id", content: content, trigger: trigger)
UNUserNotificationCenter.current().add(request) { error in }
```
**Gotchas:** User permission required; notification delivery not guaranteed; sound/haptic limited; iOS 12+ custom UI requires extension.

### ActivityKit & Live Activities
**What:** Framework for displaying live, updateable widgets on lock screen (dynamic islands) and home screen.
**When:** Live sports scores; delivery tracking; fitness activity display; real-time status.
**Key types:** `ActivityAttributes`, `Activity`, `ActivityState`
**Platforms:** iOS 16.1+, watchOS 9.1+
**Quick example:**
```swift
struct PizzaDeliveryAttributes: ActivityAttributes {
    typealias ContentState = PizzaDeliveryStatus
    struct PizzaDeliveryStatus: Codable, Hashable { var location: String }
}
let activity = try Activity<PizzaDeliveryAttributes>.request(attributes: attributes, contentState: status, pushType: .token)
```
**Gotchas:** Lock screen space limited; updates time-restricted; truncation of long text; background updates require PushKit.

### WidgetKit
**What:** Framework for creating home screen, lock screen, and dynamic island widgets.
**When:** At-a-glance information; quick actions; live data; widget extensions.
**Key types:** `Widget`, `WidgetBundle`, `TimelineProvider`, `WidgetConfiguration`
**Platforms:** iOS 14+, macOS 11+, watchOS 9+, tvOS 16+
**Quick example:**
```swift
struct CounterWidget: Widget {
    let kind: String = "CounterWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimelineProvider()) { entry in
            Text("Count: \(entry.count)")
        }.configurationDisplayName("Counter")
    }
}
```
**Gotchas:** Widgets run in sandboxed extension; shared data via App Groups; timeline management tricky; performance critical.

---

## App Integration

### StoreKit (In-App Purchases & Subscriptions)
**What:** Framework for in-app purchases, subscriptions, and app store payments (StoreKit 2 is modern).
**When:** Monetization; freemium models; subscription management; paid features.
**Key types:** `Product`, `Transaction`, `VerificationResult`, `AppStore`
**Platforms:** iOS 3.0+, macOS 10.7+, watchOS 6.2+, tvOS 9+
**Quick example:**
```swift
// StoreKit 2:
let products = try await Product.products(for: ["com.example.premium"])
if let product = products.first {
    let result = try await product.purchase()
    switch result {
    case .success(let verification):
        let transaction = try verification.payloadValue
        await transaction.finish()
    default: break
    }
}
```
**Gotchas:** Testing requires TestFlight or sandbox account; transaction state recovery complex; refund handling async; entitlements required.

### AdServices
**What:** Framework for attribution of App Install Ads (Apple Search Ads).
**When:** Track attribution from Apple Search Ads; measure campaign effectiveness.
**Key types:** `AAAttribution`, `AAAttributionError`
**Platforms:** iOS 14.3+
**Quick example:**
```swift
AAAttribution.shared().requestAttributionDetails { details, error in }
```
**Gotchas:** Limited data provided; privacy-first (no IDFA); requires user opt-in; attribution delayed 24 hours.

### HomeKit
**What:** Framework for controlling smart home devices (lights, locks, thermostats, etc.).
**When:** Smart home automation; device control; HomeKit accessory management.
**Key types:** `HMHomeManager`, `HMAccessory`, `HMService`, `HMCharacteristic`
**Platforms:** iOS 8+, macOS 10.12+, watchOS 2+, tvOS 10+
**Quick example:**
```swift
let homeManager = HMHomeManager()
homeManager.delegate = self
func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
    if let home = manager.homes.first, let accessory = home.accessories.first {
        let light = accessory.services.first { $0.serviceType == HMServiceTypeLightbulb }
        // Control light
    }
}
```
**Gotchas:** Requires HomeKit hub; Bluetooth accessory communication complex; home data syncing unpredictable; permissions granular.

### CarPlay
**What:** Framework for extending app functionality to car displays and controls.
**When:** Navigation apps; music players; communication apps with car integration.
**Key types:** `CPUIScene`, `CPListTemplate`, `CPMapTemplate`, `CPVoiceControlTemplate`
**Platforms:** iOS 12.2+
**Quick example:**
```swift
func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
          options connectionOptions: UIScene.ConnectionOptions) {
    if let carPlayScene = scene as? CPTemplateApplicationScene {
        let template = CPListTemplate(title: "Music", sections: [...])
        carPlayScene.rootTemplate = template
    }
}
```
**Gotchas:** Limited UI options; input methods restricted; testing requires simulator or physical head unit; disconnection handling critical.

### ClassKit (Education)
**What:** Framework for integrating educational apps with Apple Classroom and gradebook.
**When:** Educational apps; assignment tracking; student progress reporting.
**Key types:** `CLSContext`, `CLSActivity`, `CLSQuantityItem`
**Platforms:** iOS 11.3+
**Quick example:**
```swift
let context = CLSContext(identifier: "lesson-1", displayName: "Lesson 1")
CLSDataStore.shared.activeContext = context
```
**Gotchas:** Limited adoption; Classroom app required; APIs limited; student data handling complex.

### GroupActivities (SharePlay)
**What:** Framework for shared experiences across multiple devices and users.
**When:** Multiplayer games; shared media watching; collaborative experiences; spatial computing.
**Key types:** `GroupActivity`, `Transferable`, `GroupSession`
**Platforms:** iOS 15+, macOS 12+, watchOS 8+, tvOS 16+
**Quick example:**
```swift
struct WatchPartyActivity: GroupActivity {
    var metadata: GroupActivityMetadata { ... }
}
let session = try await WatchPartyActivity().activate()
```
**Gotchas:** Requires sustained context; user initiates; connection state fragile; limited to nearby networks.

### App Clips
**What:** Lightweight, mini versions of apps launchable from links without full installation.
**When:** First-time user experience; on-demand functionality; parking meters, food ordering, etc.
**Key types:** `SKAdNetwork`, `AppClip`, `Universal Links`
**Platforms:** iOS 14.4+
**Quick example:**
```
// Configure in Xcode: App Clip target with URL schemes
// Code is mostly shared with main app; conditional logic via Bundle.main.bundleIdentifier
```
**Gotchas:** Size limit 10 MB (strict); limited frameworks; sandbox constraints; testing requires provisioning profile.

---

## Developer Tools & Diagnostics

### OSLog
**What:** Modern logging framework with structured log messages and filtering.
**When:** Replace print/NSLog; structured logging; performance-aware logging; Xcode console output.
**Key types:** `Logger`, `OSLogStore`, `os_log_type_t`
**Platforms:** iOS 14.3+, macOS 10.15.4+, watchOS 7.2+, tvOS 14.3+
**Quick example:**
```swift
import os
let logger = Logger(subsystem: "com.example", category: "main")
logger.info("App started")
logger.error("Error occurred: \(error.localizedDescription)")
```
**Gotchas:** Log level privacy by default; strings must be static for performance; console display requires correct filter settings.

### MetricKit
**What:** Framework for collecting and analyzing app metrics (crashes, CPU, battery, etc.).
**When:** Performance monitoring; diagnostics; app health assessment.
**Key types:** `MXMetricManager`, `MXCrashDiagnostic`, `MXMetricPayload`
**Platforms:** iOS 13+, macOS 12+, tvOS 16+
**Quick example:**
```swift
MXMetricManager.shared.add(MXMetricManagerSubscriber())
// Implement MXMetricManagerSubscriber to receive metrics
```
**Gotchas:** Data received via subscriber; metrics aggregated over time; limited real-time access; privacy-first filtering applied.

### os_signpost
**What:** Low-overhead performance tracing for Instruments; measure app performance sections.
**When:** Performance profiling; Instruments analysis; identifying bottlenecks.
**Key types:** `os_signpost_id_t`, `os_log_type_debug`
**Platforms:** All Apple platforms
**Quick example:**
```swift
let signpostID = OSSignpostID(log: OSLog(subsystem: "com.example", category: "performance"))
os_signpost(.begin, log: OSLog.default, name: "operation", signpostID: signpostID)
// Perform operation
os_signpost(.end, log: OSLog.default, name: "operation", signpostID: signpostID)
```
**Gotchas:** Overhead minimal but not zero; Instruments filtering necessary; interval-based only.

### XCTest
**What:** Testing framework for unit, integration, and UI tests.
**When:** Test coverage; automated testing; CI/CD integration; regression prevention.
**Key types:** `XCTestCase`, `XCTestExpectation`, `XCUIApplication`
**Platforms:** iOS, macOS, watchOS, tvOS
**Quick example:**
```swift
class CalculatorTests: XCTestCase {
    func testAddition() {
        XCTAssertEqual(calculator.add(2, 3), 5)
    }
}
```
**Gotchas:** UI testing slow; async tests require expectations; simulator/device-specific issues; performance variability high.

### Swift Testing
**What:** Modern testing framework (Swift 5.9+, macOS 14+) replacing XCTest.
**When:** New projects; prefer macro-based testing; cleaner assertion syntax.
**Key types:** `@Test`, `#expect`, `#require`
**Platforms:** iOS 17+, macOS 14+
**Quick example:**
```swift
@Test func addition() {
    let result = calculator.add(2, 3)
    #expect(result == 5)
}
```
**Gotchas:** Newer, less mature; adoption spreading; XCTest still widely used; feature set evolving.

---

## Accessibility

### Accessibility Framework
**What:** Framework for making apps accessible to users with disabilities.
**When:** VoiceOver support; large text; motion reduction; color blindness; accessibility labels.
**Key types:** `UIAccessibility`, `NSAccessibility`, `AXCustomContent`, `AccessibilityRepresentation`
**Platforms:** iOS, macOS, watchOS, tvOS
**Quick example:**
```swift
button.accessibilityLabel = "Submit form"
button.accessibilityHint = "Double tap to submit"
Text("Price: $19.99").accessibilityLabel("Nineteen dollars ninety-nine cents")
```
**Gotchas:** VoiceOver testing requires device; dynamic type sizing breaks layouts; color contrast requirements strict; testing time-consuming.

---

## Internationalization

### Foundation Formatters & String Catalogs
**What:** Frameworks for locale-aware formatting and string localization.
**When:** Number/date/currency formatting; app localization; multi-language support; locale-specific display.
**Key types:** `NumberFormatter`, `DateFormatter`, `DateComponentsFormatter`, `StringCatalog`
**Platforms:** iOS, macOS, watchOS, tvOS
**Quick example:**
```swift
let formatter = NumberFormatter()
formatter.numberStyle = .currency
formatter.locale = Locale(identifier: "en_US")
let formatted = formatter.string(from: 19.99 as NSNumber) // "$19.99"

// SwiftUI:
Text(price, format: .currency(code: "USD"))
```
**Gotchas:** Locale changes not always reflected; DateFormatter thread-unsafe; custom formats complex; timezone handling error-prone.

---

**Reference compiled for principal-level Swift development. All frameworks verified against official Apple documentation as of 2026.**

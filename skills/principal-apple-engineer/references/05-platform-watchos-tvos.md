# watchOS and tvOS Platform Development

## watchOS Development

### App Architecture

#### SwiftUI-Only Modern Stack

watchOS 9+ eliminated WatchKit in favor of pure SwiftUI. Apps run directly on the watch without requiring a companion iPhone app.

```swift
import SwiftUI
import WatchKit

@main
struct YourWatchApp: App {
    @WKApplicationDelegateAdaptor var delegate: WatchAppDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidBecomeActive() {
        print("App became active")
    }

    func applicationWillResignActive() {
        print("App will resign active")
    }

    func applicationDidEnterBackground() {
        print("App entered background")
    }

    func applicationWillEnterForeground() {
        print("App will enter foreground")
    }
}
```

#### App Lifecycle States

watchOS has four primary states:

- **Foreground**: User interacting with app. Max ~5 seconds for network operations.
- **Background**: App suspended but may be granted runtime. Up to 30 seconds via WKExtendedRuntimeSession.
- **Suspended**: Paused, minimal CPU. Quick resume required.
- **Terminated**: Memory reclaimed. Must restore state on relaunch.

#### Extended Runtime Sessions

For background tasks exceeding normal limits:

```swift
import WatchKit

@Observable
class BackgroundTaskManager: NSObject {
    var isRunning = false
    var runtimeSession: WKExtendedRuntimeSession?

    func startBackgroundTask(duration: TimeInterval = 30) {
        let session = WKExtendedRuntimeSession()
        self.runtimeSession = session

        session.delegate = self
        session.start(expirationHandler: {
            print("Background session expired")
            self.isRunning = false
        })

        isRunning = true
    }

    func endBackgroundTask() {
        runtimeSession?.invalidate()
        isRunning = false
    }
}

extension BackgroundTaskManager: WKExtendedRuntimeSessionDelegate {
    func extendedRuntimeSessionDidStartExpirationTimer(_ session: WKExtendedRuntimeSession) {
        print("Session will expire soon")
    }

    func extendedRuntimeSessionWillExpire(_ session: WKExtendedRuntimeSession) {
        endBackgroundTask()
    }
}
```

#### Always On Display with TimelineView

watchOS enables Always On Display where the watch face shows a low-power version of your app:

```swift
struct DigitalClockView: View {
    @State private var now = Date()

    var body: some View {
        TimelineView(.everyMinute) { context in
            VStack(spacing: 4) {
                Text(context.date, style: .time)
                    .font(.system(size: 32, weight: .semibold, design: .monospaced))
                    .opacity(context.cadence == .low ? 0.5 : 1.0)

                if context.cadence == .normal {
                    Text("Step Count")
                        .font(.caption)
                }
            }
            .contentTransition(.numericText())
        }
    }
}
```

### Complications & Widgets

#### WidgetKit on watchOS 10+

Modern complication approach using WidgetKit:

```swift
import WidgetKit
import SwiftUI

struct StepCountProvider: TimelineProvider {
    typealias Entry = StepCountEntry

    func placeholder(in context: Context) -> StepCountEntry {
        StepCountEntry(date: Date(), steps: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (StepCountEntry) -> Void) {
        let entry = StepCountEntry(date: Date(), steps: 0)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let currentDate = Date()
        var entries: [StepCountEntry] = []

        for offset in 0..<6 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: offset * 5, to: currentDate)!
            let entry = StepCountEntry(date: entryDate, steps: Int.random(in: 100...500))
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct StepCountEntry: TimelineEntry {
    let date: Date
    let steps: Int
}

struct StepCountWidget: Widget {
    let kind: String = "StepCountWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StepCountProvider()) { entry in
            VStack(alignment: .center, spacing: 4) {
                Image(systemName: "figure.walk")
                    .font(.title2)
                Text("\(entry.steps)")
                    .font(.headline)
                Text("steps")
                    .font(.caption)
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Step Count")
        .description("Track your daily steps")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}
```

#### Legacy ClockKit Migration

For apps supporting watchOS 9:

```swift
import ClockKit

class ComplicationController: NSObject, CLKComplicationDataSource {
    func getLocalizableSampleTemplate(
        for complication: CLKComplication,
        withHandler handler: @escaping (CLKComplicationTemplate?) -> Void
    ) {
        let template: CLKComplicationTemplate?

        switch complication.family {
        case .circularSmall:
            let textProvider = CLKSimpleTextProvider(text: "42")
            template = CLKComplicationTemplateCircularSmallSimpleText(textProvider: textProvider)

        case .rectangularLarge:
            let bodyTextProvider = CLKTextProvider(format: "Steps: %d", 8_234)
            let template1 = CLKComplicationTemplateRectangularLargeStandardBody(
                headerTextProvider: CLKSimpleTextProvider(text: "Activity"),
                bodyTextProvider: bodyTextProvider
            )
            template = template1

        default:
            template = nil
        }

        handler(template)
    }

    func getTimelineEntries(
        for complication: CLKComplication,
        after date: Date,
        limit: Int,
        withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void
    ) {
        var entries: [CLKComplicationTimelineEntry] = []

        for offset in 0..<limit {
            let entryDate = Calendar.current.date(byAdding: .hour, value: offset, to: date)!
            let template = getTemplate(for: complication.family)
            let entry = CLKComplicationTimelineEntry(date: entryDate, complicationTemplate: template)
            entries.append(entry)
        }

        handler(entries)
    }

    func getTimelineStartDate(
        for complication: CLKComplication,
        withHandler handler: @escaping (Date?) -> Void
    ) {
        handler(Date())
    }

    func getTimelineEndDate(
        for complication: CLKComplication,
        withHandler handler: @escaping (Date?) -> Void
    ) {
        let endDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        handler(endDate)
    }

    func getNextRequestedUpdateDate(
        for complication: CLKComplication,
        withHandler handler: @escaping (Date?) -> Void
    ) {
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())
        handler(nextUpdate)
    }

    private func getTemplate(for family: CLKComplicationFamily) -> CLKComplicationTemplate {
        let textProvider = CLKSimpleTextProvider(text: "42")
        return CLKComplicationTemplateCircularSmallSimpleText(textProvider: textProvider)
    }
}
```

### Health & Fitness

#### HealthKit Integration

```swift
import HealthKit

@Observable
class HealthKitManager: NSObject {
    var stepCount: Double = 0
    var heartRate: Double = 0
    var activeEnergy: Double = 0

    let healthStore = HKHealthStore()

    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, NSError(domain: "HealthKit", code: -1, userInfo: nil))
            return
        }

        // NEVER force-unwrap HKQuantityType — use guard let
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount),
              let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate),
              let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            completion(false, NSError(domain: "HealthKit", code: -2,
                                      userInfo: [NSLocalizedDescriptionKey: "Unknown quantity type"]))
            return
        }
        let readTypes: Set<HKObjectType> = [stepType, heartRateType, energyType]

        healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
            completion(success, error)
        }
    }

    func fetchTodaySteps(completion: @escaping (Double) -> Void) {
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: Date(),
            options: .strictStartDate
        )

        let query = HKStatisticsQuery(
            quantityType: stepsType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, _ in
            guard let sum = result?.sumQuantity() else {
                completion(0)
                return
            }
            let steps = sum.doubleValue(for: HKUnit.count())
            DispatchQueue.main.async {
                self.stepCount = steps
                completion(steps)
            }
        }

        healthStore.execute(query)
    }

    func startHeartRateQuery() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        guard let oneMinuteAgo = Calendar.current.date(byAdding: .minute, value: -1, to: Date()) else { return }
        let predicate = HKQuery.predicateForSamples(
            withStart: oneMinuteAgo,
            end: Date(),
            options: .strictEndDate
        )

        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, error in
            guard let samples = samples as? [HKQuantitySample] else { return }

            if let latest = samples.last {
                let bpm = latest.quantity.doubleValue(for: HKUnit(fromString: "count/min"))
                DispatchQueue.main.async {
                    self?.heartRate = bpm
                }
            }
        }

        healthStore.execute(query)
    }
}
```

#### Workout Session Management

```swift
@Observable
class WorkoutManager: NSObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    var workoutSession: HKWorkoutSession?
    var builder: HKLiveWorkoutBuilder?
    var distance: Double = 0
    var heartRate: Double = 0
    var activeEnergy: Double = 0

    let healthStore = HKHealthStore()

    func startWorkout(activityType: HKWorkoutActivityType) {
        let workoutConfig = HKWorkoutConfiguration()
        workoutConfig.activityType = activityType
        workoutConfig.locationType = .outdoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: workoutConfig)
            self.workoutSession = session

            let builder = HKLiveWorkoutBuilder(healthStore: healthStore, configuration: workoutConfig, device: .local())
            self.builder = builder

            session.delegate = self
            builder.delegate = self

            builder.beginCollection(withStartDate: Date()) { success, error in
                if success {
                    DispatchQueue.main.async {
                        session.startActivity(with: Date())
                    }
                }
            }
        } catch {
            print("Failed to create workout session: \(error)")
        }
    }

    func pauseWorkout() {
        workoutSession?.pause()
    }

    func resumeWorkout() {
        workoutSession?.resume()
    }

    func endWorkout() {
        builder?.endCollection(withEndDate: Date()) { [weak self] success, error in
            if success {
                self?.builder?.finishWorkout { workout, error in
                    DispatchQueue.main.async {
                        self?.workoutSession?.end()
                    }
                }
            }
        }
    }

    // MARK: - HKWorkoutSessionDelegate

    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeToState toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        print("Workout state changed: \(toState.rawValue)")
    }

    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        print("Workout session failed: \(error)")
    }

    // MARK: - HKLiveWorkoutBuilderDelegate

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Task { @MainActor in
            // NEVER force-unwrap HKQuantityType — always guard let
            if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
                let statistics = workoutBuilder.statistics(for: distanceType)
                let distanceMeters = statistics?.sumQuantity()?.doubleValue(for: .meter()) ?? 0
                self.distance = distanceMeters / 1000 // Convert to km
            }

            if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                let energyStats = workoutBuilder.statistics(for: energyType)
                let energy = energyStats?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                self.activeEnergy = energy
            }
        }
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
```

### Connectivity

#### WatchConnectivity Framework

```swift
import WatchConnectivity

@Observable
class WatchConnectivityManager: NSObject, WCSessionDelegate {
    var isReachable = false
    var receivedMessage: [String: Any]?

    static let shared = WatchConnectivityManager()

    override init() {
        super.init()
        setupSession()
    }

    func setupSession() {
        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - Message Transfer (Real-time, small payloads)

    func sendMessage(_ message: [String: Any], replyHandler: ((([String: Any]) -> Void)? = nil) {
        WCSession.default.sendMessage(message, replyHandler: { response in
            DispatchQueue.main.async {
                replyHandler?(response)
            }
        }, errorHandler: { error in
            print("Message send failed: \(error)")
        })
    }

    func sendHeartRateData(_ heartRate: Double) {
        let message: [String: Any] = [
            "type": "heartRate",
            "value": heartRate,
            "timestamp": Date().timeIntervalSince1970
        ]

        sendMessage(message) { response in
            print("Phone received heart rate: \(response)")
        }
    }

    // MARK: - Application Context (Background sync)

    func updateApplicationContext(_ context: [String: Any]) {
        do {
            try WCSession.default.updateApplicationContext(context)
        } catch {
            print("Failed to update app context: \(error)")
        }
    }

    func syncUserDefaults() {
        let defaults = UserDefaults.standard
        let context: [String: Any] = [
            "lastSyncTime": Date().timeIntervalSince1970,
            "userSettings": defaults.dictionary(forKey: "userSettings") ?? [:]
        ]
        updateApplicationContext(context)
    }

    // MARK: - File Transfer (Large data, background)

    func transferFile(_ fileURL: URL, metadata: [String: Any]? = nil) {
        WCSession.default.transferFile(fileURL, metadata: metadata)
    }

    func transferWorkoutData(_ data: Data) {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("workout_\(UUID().uuidString).dat")

        do {
            try data.write(to: tempURL)
            transferFile(tempURL, metadata: ["type": "workoutData"])
        } catch {
            print("Failed to transfer file: \(error)")
        }
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = false
        }
    }

    func sessionDidDeactivate(_ session: WCSession) {}

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            self.receivedMessage = message
        }
    }

    func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        DispatchQueue.main.async {
            self.receivedMessage = applicationContext
        }
    }

    func session(
        _ session: WCSession,
        didReceive file: WCSessionFile
    ) {
        print("Received file: \(file.fileURL.lastPathComponent)")
        // Handle file reception
    }
}
```

### Constraints & Best Practices

#### Memory and Performance Management

watchOS devices are memory-constrained. Typical limits: ~30-50MB for app memory.

```swift
class MemoryEfficientDataManager {
    // Use lightweight data structures
    var cachedData: [String: String] = [:]

    func cacheData(_ data: [String: String]) {
        // Implement LRU cache with size limits
        let maxSize = 100
        if cachedData.count >= maxSize {
            if let firstKey = cachedData.keys.first {
                cachedData.removeValue(forKey: firstKey)
            }
        }
        cachedData.merge(data) { _, new in new }
    }

    // Avoid large image caches
    func loadImages(_ urls: [URL]) async {
        for url in urls {
            guard let data = try? Data(contentsOf: url) else { continue }
            guard let image = UIImage(data: data) else { continue }

            // Process immediately and release
            let resized = image.resized(to: CGSize(width: 100, height: 100))

            // Use or cache minimally
            DispatchQueue.main.async {
                // Update UI
            }
        }
    }
}
```

#### Digital Crown Navigation

```swift
struct DigitalCrownView: View {
    @State private var scrollValue: Double = 0
    @State private var items: [String] = Array(1...50).map { "Item \($0)" }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .padding(8)
                        .background(Color.blue.opacity(0.3))
                        .cornerRadius(4)
                }
            }
            .padding(4)
        }
        .digitalCrownRotation($scrollValue)
        .onChange(of: scrollValue) { oldValue, newValue in
            let delta = newValue - oldValue
            print("Crown rotated: \(delta)")
        }
    }
}
```

#### Haptic Feedback

```swift
import WatchKit

class HapticFeedbackManager {
    func playLight() {
        WKInterfaceDevice.current().play(.notification)
    }

    func playMedium() {
        WKInterfaceDevice.current().play(.success)
    }

    func playHeavy() {
        WKInterfaceDevice.current().play(.failure)
    }

    func playCustom(count: Int = 3) {
        for _ in 0..<count {
            WKInterfaceDevice.current().play(.click)
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
    }
}
```

#### Navigation Patterns

```swift
struct MainNavigationView: View {
    var body: some View {
        // Flat navigation (recommended for small screens)
        NavigationStack {
            List {
                NavigationLink("Activity", value: "activity")
                NavigationLink("Heart Rate", value: "heart_rate")
                NavigationLink("Settings", value: "settings")
            }
            .navigationDestination(for: String.self) { destination in
                switch destination {
                case "activity":
                    ActivityDetailView()
                case "heart_rate":
                    HeartRateView()
                case "settings":
                    SettingsView()
                default:
                    EmptyView()
                }
            }
        }
    }
}

struct TabBasedNavigationView: View {
    @State private var selectedTab = 0

    var body: some View {
        // Paged navigation (good for distinct sections)
        TabView(selection: $selectedTab) {
            ActivityView()
                .tag(0)

            HealthView()
                .tag(1)

            SettingsView()
                .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
}
```

---

## tvOS Development

### Focus Engine

#### Focus System Fundamentals

tvOS lacks touch input. All interaction flows through the focus system: a user moves focus between focusable elements using the Siri Remote.

```swift
struct FocusExampleView: View {
    @State private var focusedButton: String?

    var body: some View {
        VStack(spacing: 20) {
            Button("First") {
                print("First tapped")
            }
            .focused($focusedButton, equals: "first")
            .scaleEffect(focusedButton == "first" ? 1.1 : 1.0)

            Button("Second") {
                print("Second tapped")
            }
            .focused($focusedButton, equals: "second")
            .scaleEffect(focusedButton == "second" ? 1.1 : 1.0)

            Button("Third") {
                print("Third tapped")
            }
            .focused($focusedButton, equals: "third")
            .scaleEffect(focusedButton == "third" ? 1.1 : 1.0)
        }
        .onMoveCommand { direction in
            print("Moved: \(direction)")
        }
    }
}
```

#### Advanced Focus Control

```swift
struct AdvancedFocusView: View {
    @State private var focusedItem: String?
    @State private var items: [String] = ["A", "B", "C", "D", "E"]

    var body: some View {
        VStack {
            ForEach(items, id: \.self) { item in
                FocusableCard(item: item)
                    .focused($focusedItem, equals: item)
            }
        }
        .prefersDefaultFocus(in: NamedFocusScopes.mainScope)
        .onMoveCommand { direction in
            handleDirectionalInput(direction)
        }
    }

    private func handleDirectionalInput(_ direction: MoveCommandDirection) {
        guard let current = focusedItem,
              let currentIndex = items.firstIndex(of: current) else { return }

        let newIndex: Int
        switch direction {
        case .up:
            newIndex = max(0, currentIndex - 1)
        case .down:
            newIndex = min(items.count - 1, currentIndex + 1)
        case .left:
            newIndex = 0
        case .right:
            newIndex = items.count - 1
        @unknown default:
            return
        }

        focusedItem = items[newIndex]
    }
}

struct FocusableCard: View {
    let item: String
    @Environment(\.isFocused) var isFocused

    var body: some View {
        HStack {
            Image(systemName: "star.fill")
            Text(item)
            Spacer()
        }
        .padding(20)
        .background(isFocused ? Color.blue : Color.gray)
        .cornerRadius(12)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

enum NamedFocusScopes {
    struct mainScope: PreferenceKey {
        static let defaultValue: Void = ()
    }
}
```

#### Focus Sections for Grouping

```swift
struct FocusSectionView: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 30) {
            // Tab selection section
            FocusSection {
                HStack(spacing: 15) {
                    ForEach(0..<3, id: \.self) { index in
                        Button("Tab \(index + 1)") {
                            selectedTab = index
                        }
                        .padding(12)
                        .background(selectedTab == index ? Color.blue : Color.gray)
                        .cornerRadius(8)
                    }
                }
            }
            .focusSection()

            // Content section
            FocusSection {
                VStack(spacing: 15) {
                    ForEach(0..<5, id: \.self) { index in
                        ContentCard(title: "Item \(index + 1)")
                    }
                }
            }
            .focusSection()
        }
        .padding(40)
    }
}

struct ContentCard: View {
    let title: String
    @Environment(\.isFocused) var isFocused

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text("This is a content card")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(isFocused ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2))
        .cornerRadius(10)
    }
}
```

### UI Patterns

#### Large Screen Design

tvOS devices are viewed from 10+ feet away. Text and touches must be appropriately sized.

```swift
struct TVSafeAreaView: View {
    var body: some View {
        ZStack {
            // Background (extends to overscan)
            Color.black.ignoresSafeArea()

            VStack(spacing: 40) {
                Text("Welcome to tvOS")
                    .font(.system(size: 54, weight: .bold))

                Text("This content is inside the safe area")
                    .font(.system(size: 28))

                HStack(spacing: 20) {
                    Button("Primary") { }
                        .buttonStyle(TVButtonStyle())

                    Button("Secondary") { }
                        .buttonStyle(TVSecondaryButtonStyle())
                }
            }
            .padding(60) // Overscan padding
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        }
    }
}

struct TVButtonStyle: ButtonStyle {
    @Environment(\.isFocused) var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 24, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(isFocused ? Color.blue : Color.blue.opacity(0.7))
            .foregroundColor(.white)
            .cornerRadius(12)
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .shadow(radius: isFocused ? 8 : 0)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

struct TVSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isFocused) var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 22, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(18)
            .background(isFocused ? Color.white.opacity(0.3) : Color.white.opacity(0.1))
            .foregroundColor(.white)
            .cornerRadius(10)
            .border(isFocused ? Color.white : Color.gray, width: 2)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}
```

#### Parallax and Layered Images

Parallax creates depth by moving background layers at different speeds.

```swift
struct ParallaxView: View {
    @State private var parallaxOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // Background layer (slowest)
            Image("background")
                .resizable()
                .ignoresSafeArea()
                .offset(y: parallaxOffset * 0.3)

            // Mid layer
            Image("midground")
                .resizable()
                .opacity(0.8)
                .offset(y: parallaxOffset * 0.6)

            // Foreground layer (fastest)
            Image("foreground")
                .resizable()
                .offset(y: parallaxOffset * 1.0)

            // Content
            VStack {
                Spacer()
                Text("Parallax Effect")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }
        }
        .onMoveCommand { direction in
            withAnimation(.easeOut(duration: 0.3)) {
                switch direction {
                case .up:
                    parallaxOffset = min(100, parallaxOffset + 20)
                case .down:
                    parallaxOffset = max(-100, parallaxOffset - 20)
                default:
                    break
                }
            }
        }
    }
}
```

#### Lockup Pattern for Media

Media apps use "lockups": a combining image, title, and metadata.

```swift
struct MediaLockup: View {
    let title: String
    let subtitle: String
    let imageName: String
    let isHighlighted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Poster image
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 280, height: 420)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isHighlighted ? Color.white : Color.clear, lineWidth: 4)
                )
                .scaleEffect(isHighlighted ? 1.05 : 1.0)

            // Title
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .lineLimit(2)

            // Subtitle
            Text(subtitle)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(width: 280)
        .animation(.easeInOut(duration: 0.3), value: isHighlighted)
    }
}

struct MediaBrowserView: View {
    let movies = ["Movie A", "Movie B", "Movie C", "Movie D"]
    @State private var focusedIndex: Int?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 30) {
                ForEach(movies.indices, id: \.self) { index in
                    MediaLockup(
                        title: movies[index],
                        subtitle: "2024",
                        imageName: "placeholder",
                        isHighlighted: focusedIndex == index
                    )
                    .focused($focusedIndex, equals: index)
                }
            }
            .padding(60)
        }
    }
}
```

### Top Shelf

#### WidgetKit for Top Shelf (tvOS 18+)

The Top Shelf is the premium content area on Apple TV's main screen.

```swift
import WidgetKit
import SwiftUI

struct TopShelfEntry: TimelineEntry {
    let date: Date
    let shows: [ShowItem]
}

struct ShowItem: Identifiable {
    let id = UUID()
    let title: String
    let image: String
    let isNew: Bool
}

struct TopShelfProvider: TimelineProvider {
    typealias Entry = TopShelfEntry

    func placeholder(in context: Context) -> TopShelfEntry {
        TopShelfEntry(date: Date(), shows: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (TopShelfEntry) -> Void) {
        let shows = [
            ShowItem(title: "Show 1", image: "show1", isNew: true),
            ShowItem(title: "Show 2", image: "show2", isNew: false)
        ]
        let entry = TopShelfEntry(date: Date(), shows: shows)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let shows = [
            ShowItem(title: "Featured 1", image: "featured1", isNew: true),
            ShowItem(title: "Featured 2", image: "featured2", isNew: false),
            ShowItem(title: "Featured 3", image: "featured3", isNew: true)
        ]

        let entry = TopShelfEntry(date: Date(), shows: shows)
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct TopShelfWidget: Widget {
    let kind: String = "com.example.topshelf"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TopShelfProvider()) { entry in
            TopShelfView(entry: entry)
        }
        .configurationDisplayName("Top Shelf")
        .description("Featured content on Apple TV home")
        .supportedFamilies([.tvTopShelf])
    }
}

struct TopShelfView: View {
    let entry: TopShelfEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Featured for You")
                .font(.system(size: 32, weight: .bold))
                .padding(.leading, 60)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(entry.shows) { show in
                        VStack(alignment: .leading) {
                            Image(show.image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 300, height: 450)
                                .cornerRadius(12)

                            HStack(spacing: 8) {
                                Text(show.title)
                                    .font(.system(size: 18, weight: .semibold))

                                if show.isNew {
                                    Text("NEW")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.red.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }
                            .padding(.horizontal, 8)
                        }
                        .frame(width: 300)
                    }
                }
                .padding(.horizontal, 60)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black)
    }
}

#Preview(as: .tvTopShelf) {
    TopShelfWidget()
} using: {
    let entry = TopShelfEntry(
        date: Date(),
        shows: [
            ShowItem(title: "Show 1", image: "show1", isNew: true),
            ShowItem(title: "Show 2", image: "show2", isNew: false)
        ]
    )
}
```

### Media Playback

#### AVPlayerViewController Integration

```swift
import AVKit
import SwiftUI

struct VideoPlayerView: UIViewControllerRepresentable {
    let videoURL: URL
    var completion: (() -> Void)?

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        let player = AVPlayer(url: videoURL)

        controller.player = player
        controller.allowsPictureInPicturePlayback = true
        controller.showsPlaybackControls = true

        // Custom transport bar
        controller.transportBarCustomizations = [
            .includeDefaultAirPlayButton,
            .includeDefaultMediaAirPlayButton,
            .includeDefaultSubtitlesButton
        ]

        // Listen for playback completion
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            completion?()
        }

        player.play()
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // Update if needed
    }
}

struct MediaPlaybackView: View {
    @State private var isPlaying = false
    let videoURL = URL(string: "https://example.com/video.mp4")!

    var body: some View {
        if isPlaying {
            VideoPlayerView(videoURL: videoURL) {
                isPlaying = false
            }
            .ignoresSafeArea()
        } else {
            VStack(spacing: 20) {
                Button("Play Video") {
                    isPlaying = true
                }
                .buttonStyle(TVButtonStyle())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        }
    }
}
```

#### Ads and Interstitials

```swift
class AdManager {
    static let shared = AdManager()

    func playInterstitialAd(duration: TimeInterval = 15) async -> Bool {
        // Load ad content
        let adURL = URL(string: "https://example.com/ads/interstitial.mp4")!

        // Show ad with countdown
        return await withCheckedContinuation { continuation in
            let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
                let remaining = duration - timer.timeInterval * Double(timer.fireCount)
                if remaining <= 0 {
                    timer.invalidate()
                    continuation.resume(returning: true)
                }
            }
        }
    }

    func insertBumperAds(between videos: [URL]) -> [URL] {
        var sequence: [URL] = []
        let bumperURL = URL(string: "https://example.com/bumpers/default.mp4")!

        for (index, video) in videos.enumerated() {
            sequence.append(video)
            if index < videos.count - 1 {
                sequence.append(bumperURL)
            }
        }

        return sequence
    }
}
```

### Game Controller

#### GameController Framework

```swift
import GameController

@Observable
class GameControllerManager: NSObject {
    var gamepad: GCExtendedGamepad?
    var siriRemote: GCMicroGamepad?

    override init() {
        super.init()
        setupControllerNotifications()
    }

    private func setupControllerNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidConnect),
            name: NSNotification.Name.GCControllerDidConnect,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidDisconnect),
            name: NSNotification.Name.GCControllerDidDisconnect,
            object: nil
        )
    }

    @objc func controllerDidConnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }

        if let gamepad = controller.extendedGamepad {
            self.gamepad = gamepad
            setupGamepadInput(gamepad)
        } else if let remote = controller.microGamepad {
            self.siriRemote = remote
            setupRemoteInput(remote)
        }

        print("Controller connected: \(controller.vendorName ?? "Unknown")")
    }

    @objc func controllerDidDisconnect(_ notification: Notification) {
        gamepad = nil
        siriRemote = nil
        print("Controller disconnected")
    }

    private func setupGamepadInput(_ gamepad: GCExtendedGamepad) {
        // Button inputs
        gamepad.buttonA.valueChangedHandler = { button, value, pressed in
            if pressed {
                print("Button A pressed")
            }
        }

        gamepad.buttonB.valueChangedHandler = { button, value, pressed in
            if pressed {
                print("Button B pressed")
            }
        }

        // Analog sticks
        gamepad.leftThumbstick.valueChangedHandler = { element, xValue, yValue in
            print("Left stick: (\(xValue), \(yValue))")
        }

        gamepad.rightThumbstick.valueChangedHandler = { element, xValue, yValue in
            print("Right stick: (\(xValue), \(yValue))")
        }

        // Triggers
        gamepad.leftTrigger.valueChangedHandler = { element, value, pressed in
            print("Left trigger: \(value)")
        }

        gamepad.rightTrigger.valueChangedHandler = { element, value, pressed in
            print("Right trigger: \(value)")
        }

        // Shoulder buttons
        gamepad.leftShoulder.valueChangedHandler = { button, value, pressed in
            if pressed {
                print("Left shoulder pressed")
            }
        }
    }

    private func setupRemoteInput(_ remote: GCMicroGamepad) {
        // Siri Remote trackpad and button
        remote.dpad.valueChangedHandler = { element, xValue, yValue in
            print("Trackpad: (\(xValue), \(yValue))")
        }

        remote.buttonA.valueChangedHandler = { button, value, pressed in
            if pressed {
                print("Select button pressed")
            }
        }

        remote.buttonMenu.valueChangedHandler = { button, value, pressed in
            if pressed {
                print("Menu button pressed")
            }
        }
    }

    func getActiveController() -> GCController? {
        return GCController.controllers().first
    }
}
```

#### Game Input Handling in SwiftUI

```swift
struct GameView: View {
    @StateObject private var controllerManager = GameControllerManager()
    @State private var playerPosition: CGPoint = CGPoint(x: 0, y: 0)
    @State private var playerVelocity: CGVector = .zero

    var body: some View {
        ZStack {
            // Game world
            Color.black.ignoresSafeArea()

            // Player sprite
            Circle()
                .fill(Color.blue)
                .frame(width: 50, height: 50)
                .position(playerPosition)

            // HUD
            VStack(alignment: .leading, spacing: 10) {
                Text("Position: \(Int(playerPosition.x)), \(Int(playerPosition.y))")
                Text("Velocity: \(String(format: "%.2f", playerVelocity.dx)), \(String(format: "%.2f", playerVelocity.dy))")
                Text("Controller: \(controllerManager.gamepad != nil ? "Gamepad" : controllerManager.siriRemote != nil ? "Remote" : "None")")
                Spacer()
            }
            .padding(20)
            .foregroundColor(.white)
            .font(.system(size: 14, design: .monospaced))
        }
        .onReceive(Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()) { _ in
            updateGameState()
        }
    }

    private func updateGameState() {
        guard let gamepad = controllerManager.gamepad else { return }

        // Read analog stick
        let dxInput = CGFloat(gamepad.leftThumbstick.xAxis)
        let dyInput = CGFloat(gamepad.leftThumbstick.yAxis)

        // Apply acceleration
        playerVelocity.dx = dxInput * 300
        playerVelocity.dy = -dyInput * 300

        // Update position
        playerPosition.x += playerVelocity.dx * 0.016
        playerPosition.y += playerVelocity.dy * 0.016

        // Clamp to screen bounds
        playerPosition.x = max(25, min(playerPosition.x, 800))
        playerPosition.y = max(25, min(playerPosition.y, 400))
    }
}
```

#### Multi-User Support

```swift
class MultiUserGameManager: NSObject {
    @Published var players: [GCController] = []

    func initializeMultiplayer() {
        let controllers = GCController.controllers()
        players = Array(controllers.prefix(4)) // Support up to 4 players

        print("Players joined: \(players.count)")
    }

    func getPlayerInput(playerIndex: Int) -> PlayerInput? {
        guard playerIndex < players.count else { return nil }

        let controller = players[playerIndex]
        guard let gamepad = controller.extendedGamepad else { return nil }

        let input = PlayerInput(
            moveX: CGFloat(gamepad.leftThumbstick.xAxis),
            moveY: CGFloat(gamepad.leftThumbstick.yAxis),
            actionPressed: gamepad.buttonA.isPressed
        )

        return input
    }
}

struct PlayerInput {
    let moveX: CGFloat
    let moveY: CGFloat
    let actionPressed: Bool
}
```

### Best Practices Summary

**tvOS Design Principles:**
- Assume 10+ feet viewing distance: 44pt minimum touch targets, 24pt+ fonts
- Focus-driven interaction: smooth, responsive focus changes
- On-demand resources: use App Thinning for large assets
- Passive design: avoid persistent navigation UI
- Multi-user support: enable fast-user switching via GCGameController

**Performance Considerations:**
- Profile with Instruments: focus on Main Thread performance
- Batch UI updates: avoid excessive view hierarchy
- Use CADisplayLink for smooth animations
- Manage memory: Apple TV 4K has ~3GB available
- Network efficiently: tvOS may go into sleep states

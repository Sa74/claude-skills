# Principal Apple Engineer: Testing Strategy Reference

## Overview

Comprehensive testing strategy across Apple platforms. Covers Swift Testing Framework, architecture patterns, advanced techniques, and CI/CD integration. Code examples target iOS 18+, macOS 15+, and Swift 6.0+.

---

## Testing Pyramid & Architecture

**Distribution (ideal)**
- Unit tests: 70% — isolated, fast, deterministic
- Integration tests: 20% — component interactions, in-memory backends
- UI/E2E tests: 10% — critical user workflows only

**What to Test**
- Business logic, data transformations, state management
- Error handling and edge cases
- Protocol conformance and contract verification
- System interactions through mocked boundaries

**What NOT to Test**
- SwiftUI view bodies (use previews, visual inspection)
- Third-party library internals
- Framework-provided functionality (Apple frameworks tested by Apple)
- Pure rendering logic without side effects

---

## Swift Testing Framework Fundamentals

### Basic Structure

```swift
import Testing

@Suite("User Authentication")
struct AuthenticationTests {
    var authService: AuthService
    var mockCredentialStore: MockCredentialStore

    init() {
        mockCredentialStore = MockCredentialStore()
        authService = AuthService(credentialStore: mockCredentialStore)
    }

    @Test("Login with valid credentials succeeds")
    func loginSuccess() async throws {
        mockCredentialStore.setStoredCredential(.sample)

        let result = try await authService.login(email: "user@example.com", password: "password123")

        #expect(result.isAuthenticated == true)
        #expect(authService.currentUser?.email == "user@example.com")
    }

    @Test("Login with invalid credentials fails", .tags(.authentication))
    func loginFailure() async throws {
        #expect(throws: AuthError.invalidCredentials) {
            try await authService.login(email: "user@example.com", password: "wrong")
        }
    }
}
```

### Test Organization & Naming

```swift
// Mirror source structure: Sources/Features/Auth → Tests/Features/AuthTests
// File: Tests/Features/Auth/AuthServiceTests.swift

@Suite("Auth Service", .serialized) // Run sequentially if state-dependent
struct AuthServiceTests {

    // Naming: describe_action_expectedResult
    @Test("validateEmail_withValidFormat_returnsTrue")
    func testValidEmailFormat() {
        let isValid = AuthService.validateEmail("user@company.com")
        #expect(isValid)
    }

    @Test("authenticateUser_withExpiredToken_throwsTokenExpiredError")
    func testExpiredToken() async throws {
        #expect(throws: AuthError.tokenExpired) {
            try await authService.authenticate(token: expiredToken)
        }
    }
}
```

### Tags & Filtering

```swift
@Suite("Payment Processing")
struct PaymentTests {

    @Test("Process payment with valid card", .tags(.payment, .network))
    func processPayment() async throws { /* ... */ }

    @Test("Handle payment decline", .tags(.payment, .error))
    func handleDecline() async throws { /* ... */ }

    @Test("Retry failed payment", .tags(.payment, .integration))
    func retryPayment() async throws { /* ... */ }
}

// Run: swift test --filter PaymentTests.processPayment
// Run: swift test --tags payment,network
// Run: swift test --skip-tags integration
```

---

## Parameterized Tests

### Multiple Arguments

```swift
@Suite("String Validation")
struct ValidationTests {

    @Test(
        "Validate password strength",
        arguments: [
            ("short", false),
            ("ValidPass123!", true),
            ("toolong" + String(repeating: "a", count: 100), false),
            ("NoNumbers", false),
        ]
    )
    func passwordStrength(_ password: String, expectedValid: Bool) {
        let validator = PasswordValidator()
        let isValid = validator.isStrong(password)
        #expect(isValid == expectedValid)
    }
}
```

### Custom Argument Sources

```swift
struct EmailCase: Codable, Equatable {
    let email: String
    let isValid: Bool
    let reason: String
}

@Suite("Email Validation")
struct EmailTests {

    @Test(
        "Validate various email formats",
        arguments: [
            EmailCase(email: "user@example.com", isValid: true, reason: "standard"),
            EmailCase(email: "user+tag@example.co.uk", isValid: true, reason: "plus addressing"),
            EmailCase(email: "invalid..email@test.com", isValid: false, reason: "consecutive dots"),
            EmailCase(email: "@example.com", isValid: false, reason: "missing local part"),
        ]
    )
    func validateEmail(_ testCase: EmailCase) {
        let result = EmailValidator.validate(testCase.email)
        #expect(result == testCase.isValid)
    }
}
```

---

## Async Testing & Concurrency

### Basic Async Tests

```swift
@Suite("Data Repository")
struct DataRepositoryTests {
    var repository: DataRepository
    var mockNetworkClient: MockNetworkClient

    init() {
        mockNetworkClient = MockNetworkClient()
        repository = DataRepository(networkClient: mockNetworkClient)
    }

    @Test("Fetch user data from network")
    async throws {
        mockNetworkClient.mockResponse = User.sample

        let user = try await repository.fetchUser(id: "123")

        #expect(user.id == "123")
        #expect(mockNetworkClient.lastRequestURL?.path.contains("/users/123") == true)
    }

    @Test("Timeout handling", .timeLimit(.seconds(5)))
    async throws {
        mockNetworkClient.delay = 10

        #expect(throws: RepositoryError.timeout) {
            try await repository.fetchUser(id: "123")
        }
    }
}
```

### Testing Actors & Isolation

```swift
actor UserCache {
    private var cache: [String: User] = [:]

    func set(_ user: User) {
        cache[user.id] = user
    }

    func get(_ id: String) -> User? {
        cache[id]
    }
}

@Suite("User Cache")
struct UserCacheTests {

    @Test("Cache operations are isolated")
    async throws {
        let cache = UserCache()

        let user = User(id: "1", name: "Alice")
        await cache.set(user)

        let cached = await cache.get("1")
        #expect(cached?.name == "Alice")
    }

    @Test("Concurrent writes are serialized")
    async throws {
        let cache = UserCache()

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    await cache.set(User(id: "\(i)", name: "User \(i)"))
                }
            }
        }

        let user = await cache.get("50")
        #expect(user != nil)
    }
}
```

### Confirmation for Async Callbacks

```swift
@Suite("Event Publishing")
struct EventPublisherTests {

    @Test("Publisher emits events")
    async throws {
        let publisher = EventPublisher()
        var receivedEvents: [String] = []

        let confirmation = Confirmation(expectedCount: 3)

        await publisher.subscribe { event in
            receivedEvents.append(event)
            await confirmation.confirm()
        }

        await publisher.emit("event1")
        await publisher.emit("event2")
        await publisher.emit("event3")

        await confirmation.fulfill()
        #expect(receivedEvents.count == 3)
    }
}
```

### Testing Async Sequences

```swift
@Suite("Async Sequences")
struct AsyncSequenceTests {

    @Test("Stream emits multiple values")
    async throws {
        let stream = AsyncIntStream(count: 5)
        var values: [Int] = []

        for try await value in stream {
            values.append(value)
        }

        #expect(values == [0, 1, 2, 3, 4])
    }

    @Test("Cancellation stops stream")
    async throws {
        let stream = AsyncIntStream(count: 1000)
        var values: [Int] = []

        let task = Task {
            for try await value in stream {
                values.append(value)
                if values.count == 10 {
                    throw CancellationError()
                }
            }
        }

        try await task.value
        #expect(values.count == 10)
    }
}
```

---

## Test Doubles & Dependency Injection

### Protocol-Based Mocking

```swift
protocol NetworkClient {
    func request<T: Decodable>(_ endpoint: String) async throws -> T
}

class RealNetworkClient: NetworkClient {
    func request<T: Decodable>(_ endpoint: String) async throws -> T {
        let url = URL(string: endpoint)!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

class MockNetworkClient: NetworkClient {
    var mockResponses: [String: Decodable] = [:]
    var lastRequestedEndpoint: String?

    func request<T: Decodable>(_ endpoint: String) async throws -> T {
        lastRequestedEndpoint = endpoint
        guard let response = mockResponses[endpoint] as? T else {
            throw NetworkError.notFound
        }
        return response
    }
}

// Usage
class UserRepository {
    let networkClient: NetworkClient

    init(networkClient: NetworkClient = RealNetworkClient()) {
        self.networkClient = networkClient
    }

    func fetchUser(id: String) async throws -> User {
        try await networkClient.request("/users/\(id)")
    }
}

@Suite("User Repository")
struct UserRepositoryTests {

    @Test("Fetch user")
    async throws {
        let mockClient = MockNetworkClient()
        mockClient.mockResponses["/users/123"] = User(id: "123", name: "Alice")

        let repository = UserRepository(networkClient: mockClient)
        let user = try await repository.fetchUser(id: "123")

        #expect(user.name == "Alice")
        #expect(mockClient.lastRequestedEndpoint == "/users/123")
    }
}
```

### Spy Pattern

```swift
class SpyAnalyticsService: AnalyticsService {
    var capturedEvents: [String] = []
    var capturedProperties: [[String: Any]] = []

    override func track(event: String, properties: [String: Any]?) {
        capturedEvents.append(event)
        if let properties = properties {
            capturedProperties.append(properties)
        }
    }
}

@Suite("Event Tracking")
struct EventTrackingTests {

    @Test("Track purchase event with properties")
    func trackPurchase() {
        let analyticsService = SpyAnalyticsService()
        let viewModel = PurchaseViewModel(analytics: analyticsService)

        viewModel.completePurchase(amount: 99.99, productId: "pro-plan")

        #expect(analyticsService.capturedEvents == ["purchase"])
        #expect(analyticsService.capturedProperties[0]["amount"] as? Double == 99.99)
    }
}
```

### Stub Pattern

```swift
class StubLocationManager: CLLocationManager {
    var stubbedLocation: CLLocationCoordinate2D?

    override var location: CLLocation? {
        guard let coords = stubbedLocation else { return nil }
        return CLLocation(latitude: coords.latitude, longitude: coords.longitude)
    }
}

@Suite("Location Features")
struct LocationTests {

    @Test("Use stubbed location")
    func testLocationStub() {
        let stub = StubLocationManager()
        stub.stubbedLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

        let location = stub.location
        #expect(location?.coordinate.latitude == 37.7749)
    }
}
```

---

## Test Traits & Lifecycle Control

### Conditional Execution

```swift
@Suite("Platform-Specific Features")
struct PlatformTests {

    @Test("iOS-only feature", .enabled(if: ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 18))
    func iosFeature() {
        // iOS 18+ only
    }

    @Test("Skip slow test", .disabled("Temporarily disabled due to timeout issues"))
    func slowTest() async throws {
        // Skipped
    }

    @Test("Known issue", .bug("JIRA-4521", "Race condition under load"))
    func knownIssue() {
        // Marked as known failing
    }
}
```

### Custom Traits

```swift
struct SlowTrait: TestTrait {
    static let id = "slow"
}

extension TestTrait where Self == SlowTrait {
    static var slow: Self { SlowTrait() }
}

@Suite("Performance-Heavy Tests")
struct PerformanceTests {

    @Test("Large dataset processing", .slow)
    func processLargeDataset() async throws {
        let data = Array(0..<1_000_000)
        // Process data
    }
}
```

### Lifecycle Management

```swift
@Suite("Database Operations")
struct DatabaseTests {
    var database: InMemoryDatabase

    init() {
        database = InMemoryDatabase()
        database.setup()
    }

    deinit {
        database.tearDown()
    }

    @Test("Query returns results")
    func queryResults() throws {
        try database.insert(User(id: "1", name: "Alice"))
        let users = try database.query(User.self)
        #expect(users.count == 1)
    }
}
```

### withKnownIssue for Expected Failures

```swift
@Test("Known flaky test")
func flakyTest() {
    withKnownIssue("SR-12345: Intermittent failure under high load") {
        #expect(1 == 2) // Fails, but recorded as known issue
    }
}
```

---

## Integration Testing

### In-Memory Backends

```swift
protocol DataStore {
    func save(_ user: User) async throws
    func fetch(id: String) async throws -> User
}

class InMemoryDataStore: DataStore {
    private var storage: [String: User] = [:]

    func save(_ user: User) async throws {
        storage[user.id] = user
    }

    func fetch(id: String) async throws -> User {
        guard let user = storage[id] else {
            throw DataStoreError.notFound
        }
        return user
    }
}

@Suite("User Management Integration", .tags(.integration))
struct UserManagementTests {
    var dataStore: InMemoryDataStore
    var userService: UserService

    init() {
        dataStore = InMemoryDataStore()
        userService = UserService(dataStore: dataStore)
    }

    @Test("Create and retrieve user")
    async throws {
        let newUser = User(id: "456", name: "Bob", email: "bob@example.com")
        try await userService.createUser(newUser)

        let retrieved = try await userService.getUser(id: "456")
        #expect(retrieved.name == "Bob")
    }
}
```

### System-Level Protocol Mocking

```swift
// For testing IOKit/system-level interactions
protocol SystemService {
    func getSystemInfo() throws -> SystemInfo
    func setProperty(_ key: String, value: Any) throws
}

class MockSystemService: SystemService {
    var properties: [String: Any] = [:]
    var systemInfo: SystemInfo = .default

    func getSystemInfo() throws -> SystemInfo {
        systemInfo
    }

    func setProperty(_ key: String, value: Any) throws {
        properties[key] = value
    }
}

@Suite("System Integration", .tags(.integration))
struct SystemTests {

    @Test("System property updates")
    func testPropertyUpdate() throws {
        let mockService = MockSystemService()
        mockService.systemInfo = SystemInfo(cpuCount: 8, memoryGB: 16)

        try mockService.setProperty("verbose", value: true)

        #expect(mockService.properties["verbose"] as? Bool == true)
    }
}
```

---

## UI Testing with XCUITest

```swift
// Tests/UI/LoginFlowUITests.swift
import XCTest

final class LoginFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false

        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "true"]
        app.launch()
    }

    func testLoginFlow() throws {
        let app = XCUIApplication()

        // Use accessibility identifiers
        let emailField = app.textFields["emailInput"]
        let passwordField = app.secureTextFields["passwordInput"]
        let loginButton = app.buttons["loginButton"]

        emailField.tap()
        emailField.typeText("user@example.com")

        passwordField.tap()
        passwordField.typeText("password123")

        loginButton.tap()

        let homeScreen = app.navigationBars["Home"]
        XCTAssertTrue(homeScreen.waitForExistence(timeout: 5))
    }

    func testErrorMessage() throws {
        let app = XCUIApplication()

        app.buttons["loginButton"].tap()

        let errorAlert = app.alerts.firstMatch
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 2))
    }
}
```

### Accessibility Identifiers in SwiftUI

```swift
@main
struct LoginApp: App {
    var body: some Scene {
        WindowGroup {
            LoginView()
        }
    }
}

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var showError = false

    var body: some View {
        VStack {
            TextField("Email", text: $email)
                .accessibilityIdentifier("emailInput")

            SecureField("Password", text: $password)
                .accessibilityIdentifier("passwordInput")

            Button("Login") {
                // Login logic
            }
            .accessibilityIdentifier("loginButton")
        }
    }
}
```

---

## Performance Testing

### XCTMetric

```swift
@Suite("Performance Metrics")
struct PerformanceMetricsTests {

    @Test("Measure array sort performance")
    func sortPerformance() throws {
        var data = (0..<10000).map { _ in Int.random(in: 0...1000000) }

        measure(options: .init(invocationsPerIteration: 1, iterations: 5)) {
            data.sort()
        }
    }

    @Test("Track CPU usage")
    func cpuMetric() throws {
        let options = XCTMeasureOptions()
        options.invocationsPerIteration = 10

        self.measure(options: options) {
            let numbers = (0..<1000).map { _ in Int.random(in: 0...1000000) }
            let sorted = numbers.sorted()
        }
    }
}
```

### Instruments Integration

```swift
func testWithInstruments() {
    signpostBegin(log: .default, name: "ExpensiveOperation")

    // Expensive operation
    let result = performComplexCalculation()

    signpostEnd(log: .default, name: "ExpensiveOperation")
}

import os.signpost

let subsystem = Bundle.main.bundleIdentifier!
let log = OSLog(subsystem: subsystem, category: "Performance")

signpostBegin(log: log, name: "DataProcessing", signpostID: 1)
processData()
signpostEnd(log: log, name: "DataProcessing", signpostID: 1)
```

---

## Network Testing

### URLProtocol-Based Mocking

```swift
class MockURLProtocol: URLProtocol {
    static var mockResponses: [String: (data: Data, response: URLResponse)] = [:]

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url?.absoluteString,
              let (data, response) = Self.mockResponses[url] else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite("Network Requests")
struct NetworkTests {
    var session: URLSession

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
    }

    @Test("Fetch data with mocked response")
    async throws {
        let mockData = "{'name': 'Test'}".data(using: .utf8)!
        let mockResponse = HTTPURLResponse(url: URL(string: "https://api.example.com/data")!,
                                         statusCode: 200, httpVersion: nil, headerFields: nil)!

        MockURLProtocol.mockResponses["https://api.example.com/data"] = (mockData, mockResponse)

        let (data, _) = try await session.data(from: URL(string: "https://api.example.com/data")!)
        #expect(data == mockData)
    }
}
```

---

## Snapshot Testing

### Point-Free SnapshotTesting

```swift
import SnapshotTesting

@Suite("Snapshot Tests")
struct SnapshotTests {

    @Test("LoginView snapshot")
    func loginViewSnapshot() {
        let view = LoginView(viewModel: .mock)
        assertSnapshot(of: view, as: .image)
    }

    @Test("Multi-device snapshots")
    func multiDeviceSnapshot() {
        let view = ProductCard(product: .sample)

        assertSnapshot(of: view, as: .image(traits: .iPhoneSe))
        assertSnapshot(of: view, as: .image(traits: .iPhone15))
        assertSnapshot(of: view, as: .image(traits: .iPad))
    }

    @Test("Snapshot with precision for CI")
    func snapshotWithPrecision() {
        let view = AnimatedView()
        assertSnapshot(of: view, as: .image(precision: 0.95))
    }
}
```

---

## CI/CD Integration

### xcodebuild Test Commands

```bash
# Run all tests
xcodebuild test -scheme MyApp -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test class
xcodebuild test -scheme MyApp -testPlan UnitTests \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing MyAppTests/AuthServiceTests

# Run with code coverage
xcodebuild test -scheme MyApp \
  -enableCodeCoverage YES \
  -derivedDataPath build

# Parallel testing across simulators
xcodebuild test -scheme MyApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro Max' \
  -parallel-testing-enabled YES

# Collect test results
xcodebuild test -scheme MyApp \
  -resultBundlePath TestResults.xcresult \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

### GitHub Actions Workflow

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    strategy:
      matrix:
        device: ['iPhone 15', 'iPhone SE', 'iPad Pro (12.9-inch)']
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-xcode@v1
        with:
          xcode-version: '16'

      - name: Run Tests
        run: |
          xcodebuild test \
            -scheme MyApp \
            -destination "platform=iOS Simulator,name=${{ matrix.device }}" \
            -enableCodeCoverage YES \
            -resultBundlePath TestResults.xcresult

      - name: Upload Coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./TestResults.xcresult/coverage.txt
```

### Test Result Parsing

```swift
import Foundation

struct TestResultParser {
    static func parseXCResult(path: String) throws -> TestSummary {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["xcresulttool", "formatresultsummary", path]

        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return try JSONDecoder().decode(TestSummary.self, from: data)
    }
}

struct TestSummary: Codable {
    let testsPassed: Int
    let testsFailed: Int
    let testsSkipped: Int
}
```

---

## Platform-Specific Testing

### iOS/iPadOS Testing

```swift
@Suite("iPad Specific Features", .enabled(if: UIDevice.current.userInterfaceIdiom == .pad))
struct iPadTests {
    @Test("Split view functionality")
    func splitViewTest() {
        // iPad-specific test
    }
}
```

### watchOS Testing Constraints

```swift
@Suite("watchOS Features")
struct WatchOSTests {

    @Test("Complication update", .enabled(if: #available(watchOS 9, *)))
    func complicationUpdate() async throws {
        let complication = ComplicationProvider()
        let timeline = try await complication.timeline()
        #expect(timeline.entries.count > 0)
    }

    @Test("Memory efficient processing")
    func memoryConstrainedTest() {
        // watchOS has ~30MB limit for background tasks
        let data = Array(0..<100) // Small datasets
        let processed = processWatchData(data)
        #expect(processed.count == 100)
    }
}
```

### visionOS Spatial Testing

```swift
@Suite("visionOS Spatial Features")
struct VisionOSTests {

    @Test("3D model loading")
    async throws {
        let modelLoader = ModelLoader()
        let model = try await modelLoader.load(named: "chair")

        #expect(model.meshes.count > 0)
    }

    @Test("Hand tracking accuracy")
    func handTrackingTest() {
        let tracker = HandTracker()
        tracker.startTracking()

        let position = tracker.palmPosition
        #expect(position != .zero)
    }
}
```

---

## Known Issues & Best Practices

**Parallel Testing Considerations**
- Use `.serialized` trait for state-dependent tests
- Avoid shared mutable state across test suites
- Reset test doubles in `init()`

**Performance**
- Mock network calls; don't hit real APIs
- Use in-memory databases instead of on-disk
- Keep timeouts reasonable (3-5 seconds)

**Flakiness Prevention**
- Don't depend on exact timing
- Use `confirmation` instead of `XCTNSPredicate`
- Seed random number generators in tests

**Documentation**
- Comment complex test logic
- Use descriptive names that explain intent
- Link to related issues/bugs in trait descriptions


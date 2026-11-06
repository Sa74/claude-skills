# Testing Patterns

## Table of Contents
- Swift Testing Framework Basics
- Test Organization
- Parameterized Tests
- Async Testing
- Integration Tests
- UI Tests
- Testing System-Level Code

## Swift Testing Framework Basics

Use `import Testing` exclusively. Do NOT use XCTest for new tests.

**Test declaration:**
```swift
import Testing

@Test("Descriptive name of what is being tested")
func featureDoesExpectedBehavior() {
    let result = MyType().compute(input: 42)
    #expect(result == 84)
}
```

**Assertions:**
- `#expect(condition)` — non-fatal, continues test execution.
- `#require(condition)` — fatal, throws on failure (use for preconditions).
- `#expect(throws: MyError.self) { try riskyOperation() }` — verify thrown errors.
- `#expect(throws: Never.self) { try shouldNotThrow() }` — verify no error thrown.

**Suites:**
```swift
@Suite("Feature name")
struct FeatureTests {
    let sut: MyType

    init() {
        sut = MyType()
    }

    @Test("Specific behavior")
    func specificBehavior() {
        #expect(sut.value == 0)
    }
}
```

Suites use `init()` for setup (replaces `setUp`). Use `deinit` in classes for teardown if needed. Prefer struct suites.

## Test Organization

Mirror source module structure:
```
Sources/
  AppCore/
    Services/NetworkService.swift
    Models/User.swift
Tests/
  AppCoreTests/
    Services/NetworkServiceTests.swift
    Models/UserTests.swift
```

**Naming convention:**
- Test file: `{SourceFile}Tests.swift`
- Suite: `{TypeName}Tests`
- Test function: describe the behavior, not the method. `func returnsNilForInvalidInput()` not `func testParseMethod()`.

**Tags for categorization:**
```swift
extension Tag {
    @Tag static var networking: Self
    @Tag static var persistence: Self
    @Tag static var security: Self
}

@Test("Fetches user profile", .tags(.networking))
func fetchUserProfile() async throws { ... }
```

Run filtered: `swift test --filter .tags(.networking)` or via Xcode test navigator.

## Parameterized Tests

Use for testing the same logic with multiple inputs:

```swift
@Test("Validates email format", arguments: [
    ("user@example.com", true),
    ("invalid", false),
    ("@missing.com", false),
    ("user@.com", false),
])
func validatesEmail(email: String, isValid: Bool) {
    #expect(EmailValidator.isValid(email) == isValid)
}
```

**Multiple argument sources:**
```swift
@Test(arguments: [1, 2, 3], ["a", "b"])
func combinedInputs(number: Int, letter: String) {
    // Tests all combinations: (1,"a"), (1,"b"), (2,"a"), (2,"b"), (3,"a"), (3,"b")
}
```

Use parameterized tests instead of loops inside a test — each argument combination runs as an independent test case with its own pass/fail status.

## Async Testing

Tests can be `async` and `throws` directly:

```swift
@Test("Loads data from network")
func loadsData() async throws {
    let service = NetworkService(session: mockSession)
    let data = try await service.fetchData(from: testURL)
    #expect(data.count > 0)
}
```

**Timeouts:**
```swift
@Test("Completes within time limit", .timeLimit(.seconds(5)))
func timeSensitiveOperation() async throws {
    try await longRunningTask()
}
```

**Confirmation (replaces XCTest expectations):**
```swift
@Test("Calls delegate on completion")
func callsDelegate() async {
    await confirmation { confirm in
        let delegate = MockDelegate(onComplete: { confirm() })
        let service = MyService(delegate: delegate)
        service.start()
    }
}
```

For multiple expected calls:
```swift
await confirmation(expectedCount: 3) { confirm in
    // confirm() must be called exactly 3 times
}
```

## Integration Tests

For cross-layer and system API integration:

```swift
@Suite("Database integration")
struct DatabaseIntegrationTests {
    let store: DataStore

    init() async throws {
        store = try await DataStore(configuration: .inMemory)
    }

    @Test("Persists and retrieves records")
    func roundTrip() async throws {
        let record = Record(name: "test")
        try await store.save(record)
        let fetched = try await store.fetch(Record.self, id: record.id)
        #expect(fetched == record)
    }
}
```

**Guidelines:**
- Use in-memory or temp directory backends — never touch real user data.
- Clean up in `deinit` or use fresh instances per test via `init()`.
- Tag integration tests: `.tags(.integration)` so they can be run separately.

## UI Tests

UI tests still use XCUITest framework (Swift Testing does not replace XCUITest):

```swift
import XCTest

final class OnboardingUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["--ui-testing"]
        app.launch()
    }

    func testOnboardingFlow() throws {
        let welcomeText = app.staticTexts["Welcome"]
        XCTAssertTrue(welcomeText.waitForExistence(timeout: 5))

        app.buttons["Get Started"].tap()
        XCTAssertTrue(app.staticTexts["Step 1"].exists)
    }
}
```

**Guidelines:**
- Use `app.launchArguments` / `app.launchEnvironment` to configure test state.
- Use accessibility identifiers for element lookup, not text labels (localization-safe).
- Keep UI tests focused on critical user flows — they are slow and brittle.
- Tag or group UI tests separately from unit/integration tests.

## Testing System-Level Code

**System extensions:** Cannot be unit-tested directly in-process. Test the logic layer independently by extracting business logic from the extension entry point.

**IOKit interactions:** Create protocol abstractions over IOKit calls. Mock the protocol in tests. Test real IOKit integration in a dedicated integration test target that runs on the full system.

**Endpoint Security:** Extract event processing logic into pure functions. Test those functions with synthetic `es_message_t` data. Full ES integration requires running on a real system with SIP configuration.

**Pattern:**
```swift
// Production code
protocol DeviceProvider {
    func connectedDevices() throws -> [Device]
}

struct IOKitDeviceProvider: DeviceProvider { ... }

// Test code
struct MockDeviceProvider: DeviceProvider {
    var devices: [Device] = []
    func connectedDevices() throws -> [Device] { devices }
}
```

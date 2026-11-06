# Advanced Swift Mastery - Principal Engineer Reference

## Swift 6 Strict Concurrency

### Sendability Model

**@Sendable & Sendable Protocol**

```swift
// Basic sendable closure - no captures or safe captures
let sendableClosure: @Sendable () -> Void = {
    print("Safe to pass across isolation domains")
}

// Protocol conformance
struct SendableValue: Sendable {
    let id: Int  // Value type, implicitly sendable
    let name: String
}

// Conditional sendability
struct Container<T: Sendable>: Sendable {
    var value: T
}

// Suppress sendability checking (dangerous, only when you know better)
nonisolated(unsafe) let globalState = NSMutableArray()
```

**Noncopyable Types (~Copyable)**

```swift
struct FileHandle: ~Copyable {
    private let fd: Int32

    init(path: String) throws {
        fd = try path.withCString { cPath in
            let fd = open(cPath, O_RDONLY)
            guard fd >= 0 else { throw NSError(domain: "FileError", code: -1) }
            return fd
        }
    }

    // Explicit consuming move
    consuming func close() {
        close(fd)
        discard self  // Prevents reuse
    }

    // Borrowing read - doesn't consume
    borrowing func read(count: Int) throws -> [UInt8] {
        var buffer = [UInt8](repeating: 0, count: count)
        let read = Darwin.read(fd, &buffer, count)
        guard read >= 0 else { throw NSError(domain: "ReadError", code: -1) }
        return Array(buffer.prefix(read))
    }

    deinit {
        close(fd)
    }
}

// Usage forces explicit move semantics
var handle = try FileHandle(path: "/tmp/test.txt")
let data = handle.read(count: 1024)
handle.close()  // Must explicitly close
```

### Actor Isolation

**Global Actors & @MainActor**

```swift
// Custom global actor for background work
actor DatabaseActor {
    private var cache: [String: Data] = [:]

    func query(_ key: String) -> Data? {
        return cache[key]
    }

    func store(_ key: String, _ data: Data) {
        cache[key] = data
    }
}

nonisolated(unsafe) let dbActor = DatabaseActor()

// @MainActor enforces UI thread
// IMPORTANT: Use @Observable (Observation framework), NOT ObservableObject/@Published
@MainActor
@Observable
class UIViewModel {
    var state: String = "initial"  // No @Published needed — @Observable tracks all stored properties

    // Automatically on main thread
    func updateUI(_ text: String) {
        state = text
    }

    // Explicit nonisolated for expensive computation
    nonisolated func expensiveCalc(_ n: Int) -> Int {
        return (0...n).reduce(0, +)
    }

    @MainActor
    func applyResult(_ value: Int) {
        state = "Result: \(value)"
    }
}

// NEVER use the legacy pattern:
// class LegacyVM: ObservableObject {     // ❌ Deprecated pattern
//     @Published var value: String = ""   // ❌ Not needed with @Observable
// }
// ObservableObject still compiles but generates excessive view invalidation.
// @Observable is more efficient (property-level tracking, not object-level).

// Using actors
Task {
    await dbActor.store("key", Data())
    if let data = await dbActor.query("key") {
        print("Found: \(data.count) bytes")
    }
}
```

**Actor Reentrancy & Deadlock Prevention**

```swift
actor BankAccount {
    var balance: Double

    init(balance: Double) {
        self.balance = balance
    }

    // Reentrancy problem: calling async function within same actor
    func transfer(to other: BankAccount, amount: Double) async throws {
        guard balance >= amount else { throw TransferError.insufficientFunds }

        // Compiler allows this - actors are reentrant
        // Await creates re-entry point
        await other.deposit(amount)

        balance -= amount
    }

    func deposit(_ amount: Double) async {
        // Simulates I/O work
        try? await Task.sleep(nanoseconds: 100_000_000)
        balance += amount
    }
}

// Safe pattern: batch operations atomically
actor AtomicCounter {
    private var count: Int = 0

    nonisolated private let lock = NSLock()

    func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        count += 1
        return count
    }
}
```

### Structured Concurrency Patterns

**TaskGroup & ThrowingTaskGroup**

```swift
// Concurrent execution of heterogeneous work
func fetchAndProcessData() async throws -> [Result] {
    var results: [Result] = []

    try await withThrowingTaskGroup(of: Result.self) { group in
        for id in 1...10 {
            group.addTask {
                let data = try await fetchData(id: id)
                return processData(data)
            }
        }

        // Collect results as they complete (not in order)
        for try await result in group {
            results.append(result)
        }
    }

    return results
}

// Discarding task group for fire-and-forget work
func logAnalytics() async {
    await withDiscardingTaskGroup { group in
        group.addTask {
            try? await sendAnalytics(event: "viewed")
        }
        group.addTask {
            try? await sendAnalytics(event: "scrolled")
        }
        // Waits for all tasks before returning
    }
}

// Child task cancellation propagation
func downloadWithCancellation() async throws -> Data {
    try await withTaskGroup(of: Data.self) { group in
        for chunk in 1...4 {
            group.addTask {
                try await downloadChunk(chunk)
            }
        }

        if Task.isCancelled {
            group.cancelAll()  // Propagate cancellation
        }

        var accumulated = Data()
        for try await chunk in group {
            accumulated.append(chunk)
        }
        return accumulated
    }
}
```

**AsyncSequence & AsyncStream**

```swift
// Custom async sequence
struct DataFetcher: AsyncSequence {
    typealias Element = String

    let ids: [Int]

    func makeAsyncIterator() -> DataIterator {
        DataIterator(ids: ids)
    }
}

struct DataIterator: AsyncIterator {
    let ids: [Int]
    var index = 0

    mutating func next() async -> String? {
        guard index < ids.count else { return nil }
        let data = await fetchData(ids[index])
        index += 1
        return data
    }
}

// AsyncStream with continuation - event producer pattern
func observeNetworkChanges() -> AsyncStream<NetworkStatus> {
    AsyncStream { continuation in
        let monitor = NWPathMonitor()

        monitor.pathUpdateHandler = { path in
            let status = NetworkStatus(isConnected: path.status == .satisfied)
            continuation.yield(status)
        }

        monitor.start(queue: DispatchQueue.global())

        continuation.onTermination = { @Sendable _ in
            monitor.cancel()
        }
    }
}

// Consuming async stream
for await status in observeNetworkChanges() {
    print("Network: \(status.isConnected ? "online" : "offline")")
}

// Throttling async sequence
extension AsyncSequence {
    func throttle(interval: TimeInterval) -> AsyncThrottledSequence<Self> {
        AsyncThrottledSequence(base: self, interval: interval)
    }
}

struct AsyncThrottledSequence<Base: AsyncSequence>: AsyncSequence {
    typealias Element = Base.Element

    let base: Base
    let interval: TimeInterval

    func makeAsyncIterator() -> AsyncThrottledIterator<Base.AsyncIterator> {
        AsyncThrottledIterator(
            base: base.makeAsyncIterator(),
            interval: interval
        )
    }
}

struct AsyncThrottledIterator<Base: AsyncIterator>: AsyncIterator {
    var base: Base
    let interval: TimeInterval
    var lastEmit: Date = .distantPast

    mutating func next() async -> Base.Element? {
        while true {
            let now = Date()
            let elapsed = now.timeIntervalSince(lastEmit)

            if elapsed < interval {
                try? await Task.sleep(nanoseconds: UInt64((interval - elapsed) * 1_000_000_000))
            }

            if let element = await base.next() {
                lastEmit = Date()
                return element
            }
            return nil
        }
    }
}
```

### Task Cancellation

```swift
// Cooperative cancellation pattern
func importantWork() async throws {
    for item in items {
        // Check at natural breakpoints
        try Task.checkCancellation()

        // Do work
        await processItem(item)
    }
}

// Cancellation handler
func monitoredOperation() async -> String {
    return await withTaskCancellationHandler {
        let result = await performLongWork()
        return result
    } onCancel: {
        // Cleanup when cancelled
        print("Operation cancelled")
        cancelInProgressRequests()
    }
}

// Timeout pattern
func fetchWithTimeout(_ seconds: TimeInterval) async throws -> Data {
    try await withThrowingTaskGroup(of: Data.self) { group in
        let mainTask = group.addTask {
            try await fetch()
        }

        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError()
        }

        let data = try await group.next()!
        group.cancelAll()
        return data
    }
}
```

## Advanced Type System

### Generics: Associated Types & Where Clauses

```swift
// Associated types with constraints
protocol DataStore {
    associatedtype Item: Identifiable
    associatedtype Snapshot: Codable

    var items: [Item] { get }
    func save(_ snapshot: Snapshot) throws
}

// Primary associated types (Swift 5.7+) - explicit inference
protocol Repository<Element> {
    associatedtype Element: Equatable
    associatedtype Error: Swift.Error

    func fetch() async throws(Error) -> [Element]
}

// Complex where clauses
extension Repository
where Element: Sendable,
      Element: Codable,
      Error == DecodingError {

    func fetchAndDecode() async throws -> [Element] {
        try await fetch()
    }
}

// Recursive generic constraints
protocol TreeNode {
    associatedtype Value
    var value: Value { get }
    var children: [Self] { get }
}

// Generic function with multiple constraints
func merge<T, U>(_ a: [T], _ b: [U]) -> [(T, U)]
where T: Equatable & Hashable,
      U: Equatable & Hashable {
    return a.enumerated().compactMap { (index, item) in
        guard index < b.count else { return nil }
        return (item, b[index])
    }
}
```

### Opaque Types vs Type Erasure

```swift
// Opaque return type (reverse generics)
protocol View {
    associatedtype Body: View
    @ViewBuilder var body: Body { get }
}

// Returns concrete type but hides it
func makeButton() -> some View {
    Button("Tap me") { }
        .padding()
        .background(.blue)
}

// Type erasure using AnyView (slower, runtime overhead)
func makeConditionalView(_ condition: Bool) -> AnyView {
    if condition {
        return AnyView(Button("A") { })
    } else {
        return AnyView(Text("B"))
    }
}

// Better: opaque return with conditional
@ViewBuilder
func makeConditionalViewOpaque(_ condition: Bool) -> some View {
    if condition {
        Button("A") { }
    } else {
        Text("B")
    }
}

// Manual type erasure pattern
class AnyIterator<Element>: IteratorProtocol {
    private let _next: () -> Element?

    init<T: IteratorProtocol>(_ iter: T) where T.Element == Element {
        var iterator = iter
        _next = { iterator.next() }
    }

    func next() -> Element? {
        _next()
    }
}
```

### Result Builders: Custom DSLs

```swift
@resultBuilder
struct ArrayBuilder<Element> {
    static func buildBlock(_ components: Element...) -> [Element] {
        components
    }

    static func buildOptional(_ component: [Element]?) -> [Element] {
        component ?? []
    }

    static func buildEitherFirst<T>(_ component: T) -> [Element] where T: Collection, T.Element == Element {
        Array(component)
    }

    static func buildEitherSecond<T>(_ component: T) -> [Element] where T: Collection, T.Element == Element {
        Array(component)
    }

    static func buildArray(_ components: [[Element]]) -> [Element] {
        components.flatMap { $0 }
    }
}

// Query builder DSL
class QueryBuilder<T> {
    @resultBuilder
    struct PredicateBuilder {
        static func buildBlock(_ predicates: (T) -> Bool...) -> [(T) -> Bool] {
            predicates
        }
    }

    func filter(@PredicateBuilder _ builder: () -> [(T) -> Bool]) -> [T] {
        let predicates = builder()
        return items.filter { item in
            predicates.allSatisfy { $0(item) }
        }
    }

    var items: [T] = []
}

// Config builder
@resultBuilder
struct ConfigBuilder {
    static func buildBlock(_ components: Config...) -> [Config] {
        components
    }
}

struct Config {
    var key: String
    var value: String
}

func buildConfig(@ConfigBuilder _ builder: () -> [Config]) -> [String: String] {
    let configs = builder()
    var result: [String: String] = [:]
    for config in configs {
        result[config.key] = config.value
    }
    return result
}

let config = buildConfig {
    Config(key: "timeout", value: "30")
    Config(key: "retries", value: "3")
}
```

### Property Wrappers

```swift
// Custom @Published replacement
@propertyWrapper
class Observed<Value> {
    private var storage: Value
    private var observers: [(Value) -> Void] = []

    var wrappedValue: Value {
        get { storage }
        set {
            storage = newValue
            observers.forEach { $0(newValue) }
        }
    }

    var projectedValue: Observed<Value> {
        self
    }

    init(wrappedValue: Value) {
        self.storage = wrappedValue
    }

    func observe(_ callback: @escaping (Value) -> Void) {
        observers.append(callback)
    }
}

class Model {
    @Observed var name: String = "default"

    init() {
        $name.observe { newName in
            print("Name changed to: \(newName)")
        }
    }
}

// Validated property wrapper
@propertyWrapper
struct Validated<Value> {
    private var value: Value
    private let validate: (Value) -> Bool

    var wrappedValue: Value {
        get { value }
        set {
            if validate(newValue) {
                value = newValue
            }
        }
    }

    init(wrappedValue: Value, validate: @escaping (Value) -> Bool) {
        self.value = wrappedValue
        self.validate = validate
    }
}

class User {
    @Validated(validate: { $0 >= 0 && $0 <= 120 })
    var age: Int = 0
}
```

### Macros (Swift 5.9+)

```swift
// Freestanding macro - generates code
#myStringInterpolation("Hello", "World")  // Compiler plugin generates code

// Attached macro - modifies declarations
@AddPublic
struct MyData {
    var id: Int
    var name: String
}
// Becomes public members automatically

// Common pattern: Codable synthesis
@Codable
struct APIResponse {
    let id: Int
    let name: String
    let timestamp: Date
}

// Mirror generation macro
@Reflective
class DatabaseModel {
    var id: UUID
    var createdAt: Date
}
// Generates mirror for runtime reflection
```

## Memory Management Deep Dive

### ARC & Reference Cycles

```swift
// Weak self in escaping closures
class ViewController {
    var onDataReceived: ((Data) -> Void)?

    func setupCallback() {
        onDataReceived = { [weak self] data in
            // Safe - doesn't retain self
            self?.processData(data)
        }
    }

    func processData(_ data: Data) { }
}

// Unowned - assumes reference always valid
class NetworkManager {
    let owner: ViewController

    init(owner: ViewController) {
        self.owner = owner
    }

    func fetch() {
        apiCall { [unowned self] result in
            // Slightly more efficient than weak, but crashes if owner deallocated
            self.owner.handle(result)
        }
    }
}

// Capture list with multiple references
class DataController {
    var data: Data?
    var delegate: DataDelegate?

    func setupBinding() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("update"),
            object: nil,
            queue: .main
        ) { [weak self, weak delegate = self?.delegate] _ in
            self?.data = delegate?.getData()
        }
    }
}

// Retain cycle with closures - dangerous pattern
class EventBus {
    var handlers: [(Event) -> Void] = []

    // PROBLEM: closure captures self, handlers holds closure
    // SOLUTION: Use weak reference
    func subscribe(handler: @escaping (Event) -> Void) {
        handlers.append(handler)
    }
}

// Combine memory management (LEGACY — prefer @Observable + AsyncSequence for new code)
class CombineViewModel {
    @Published var state: String = ""  // Only in Combine-based code; new code uses @Observable
    private var subscriptions = Set<AnyCancellable>()

    func bindPublisher() {
        $state
            .sink { [weak self] newState in
                self?.handleState(newState)
            }
            .store(in: &subscriptions)
    }

    func handleState(_ state: String) { }
}
```

### Copy-on-Write for Value Types

```swift
// Efficient large value type
struct Buffer {
    private class Storage {
        var bytes: [UInt8]

        init(count: Int) {
            bytes = [UInt8](repeating: 0, count: count)
        }

        func copy() -> Storage {
            Storage(bytes: bytes)
        }
    }

    private var storage: Storage

    init(count: Int) {
        storage = Storage(count: count)
    }

    // Ensures unique storage on mutation (copy-on-write)
    mutating func write(at offset: Int, byte: UInt8) {
        if !isKnownUniquelyReferenced(&storage) {
            storage = storage.copy()
        }
        storage.bytes[offset] = byte
    }

    subscript(offset: Int) -> UInt8 {
        storage.bytes[offset]
    }
}

// Value type that avoids unnecessary copies
struct SmallString: Equatable {
    @usableFromInline
    internal var storage: String

    var isEmpty: Bool {
        storage.isEmpty
    }

    mutating func append(_ char: Character) {
        storage.append(char)
    }
}
```

### Unsafe Memory Operations

```swift
// UnsafePointer for C interop
func sumArray(_ arr: [Int]) -> Int {
    var total = 0
    arr.withUnsafeBytes { buffer in
        let basePtr = buffer.baseAddress!.assumingMemoryBound(to: Int.self)
        for i in 0..<arr.count {
            total += basePtr[i]
        }
    }
    return total
}

// UnsafeMutableBufferPointer for in-place mutation
func fillBuffer(_ buffer: inout [Int], with value: Int) {
    buffer.withUnsafeMutableBufferPointer { mutableBuffer in
        for i in 0..<mutableBuffer.count {
            mutableBuffer[i] = value
        }
    }
}

// OpaquePointer for opaque C types
func withOpaqueHandle(_ closure: (OpaquePointer) -> Void) {
    var handle: UnsafeMutableRawPointer?
    initializeHandle(&handle)
    defer { cleanupHandle(&handle) }

    if let ptr = handle {
        closure(OpaquePointer(ptr))
    }
}

// Manual memory management (rarely needed)
struct ManualBuffer {
    let ptr: UnsafeMutableRawPointer
    let count: Int

    init(capacity: Int) {
        ptr = UnsafeMutableRawPointer.allocate(byteCount: capacity, alignment: MemoryLayout<Int>.alignment)
        count = capacity
    }

    deinit {
        ptr.deallocate()
    }
}
```

## Performance Patterns

### Value Types vs Reference Types

```swift
// Choose value types for small, immutable data
struct Point: Equatable {
    var x: Double
    var y: Double

    var distance: Double {
        sqrt(x * x + y * y)
    }
}

// Reference types for mutable shared state
class Cache {
    private var items: [String: Any] = [:]

    func set(_ key: String, _ value: Any) {
        items[key] = value
    }

    func get(_ key: String) -> Any? {
        items[key]
    }
}

// Benchmark: struct copying overhead
struct LargeStruct {
    var array: [Int] = Array(0..<1000)
    var dict: [String: Int] = [:]
    var name: String = ""

    // Copy-on-write optimization essential here
    mutating func mutate() {
        array[0] = 999
    }
}

// Optimize: use class for large reference-counted types
class LargeClass {
    var array: [Int] = Array(0..<1000)
    var dict: [String: Int] = [:]
    var name: String = ""

    func mutate() {
        array[0] = 999
    }
}
```

### String Performance

```swift
// Avoid repeated substring allocation
func parseCSV(_ line: String) -> [String] {
    let utf8 = line.utf8
    var fields: [String] = []
    var currentStart = utf8.startIndex

    for index in utf8.indices {
        if utf8[index] == UInt8(ascii: ",") {
            let substring = String(utf8[currentStart..<index])
            fields.append(substring)
            currentStart = utf8.index(after: index)
        }
    }

    return fields
}

// Efficient string building
func buildString(count: Int) -> String {
    var result = String()
    result.reserveCapacity(count * 10)

    for i in 0..<count {
        result.append("Item \(i)\n")
    }

    return result
}

// String interpolation performance
let efficient = "Value: \(someInt)"  // Efficient
let inefficient = "Value: " + String(someInt)  // Slower
```

### Collection Performance

```swift
// ContiguousArray for performance-critical code
let contiguous: ContiguousArray<Int> = [1, 2, 3, 4, 5]
// Guaranteed memory layout, better CPU cache locality

// reserveCapacity prevents allocations
var array: [Int] = []
array.reserveCapacity(1000)
for i in 0..<1000 {
    array.append(i)  // No allocations after initial reserve
}

// Lazy sequences avoid intermediate allocations
let lazy = (0..<1000000)
    .lazy
    .map { $0 * 2 }
    .filter { $0 % 2 == 0 }
    .prefix(10)

for value in lazy {
    print(value)  // Only evaluates needed values
}

// IndexSet for sparse boolean arrays
var selected = IndexSet()
selected.insert(0)
selected.insert(5)
selected.insert(10)
// More efficient than [Bool]
```

### Inlining Hints

```swift
// @inlinable - compiler inlines across module boundaries
@inlinable
public func fastAdd(_ a: Int, _ b: Int) -> Int {
    a + b
}

// @usableFromInline for internal implementation detail
@usableFromInline
internal struct InternalData {
    var value: Int
}

// @frozen - layout guaranteed never to change
@frozen
public struct Color {
    public let red: Double
    public let green: Double
    public let blue: Double
}

// Whole module optimization forces inlining
// swiftc -O -whole-module-optimization
```

## Protocol-Oriented Design

```swift
// Protocol composition
protocol Drawable {
    func draw()
}

protocol Animated {
    func animate()
}

protocol Interactive: Drawable, Animated {
    func handleTap()
}

// Conditional conformance
extension Array: Equatable where Element: Equatable {
    // Array<Int> is Equatable, Array<NSMutableArray> is not
}

extension Dictionary: Codable where Key: Codable, Value: Codable {
    // Dictionary<String, String> is Codable
}

// Protocol extension with default implementation
protocol Logger {
    func log(_ message: String)
}

extension Logger {
    func logWarning(_ message: String) {
        log("⚠️ \(message)")
    }

    func logError(_ message: String) {
        log("❌ \(message)")
    }
}

// Witness pattern - avoiding existential overhead
struct LoggerWitness<T> {
    let log: (T, String) -> Void
}

func createIntLogger() -> LoggerWitness<Int> {
    LoggerWitness { value, message in
        print("[\(value)] \(message)")
    }
}

// When NOT to use protocols - single implementation
// ❌ Bad
protocol UserRepository {
    func fetch(id: Int) async -> User?
}

struct SQLiteUserRepository: UserRepository {
    func fetch(id: Int) async -> User? { }
}

// ✅ Better
struct SQLiteUserRepository {
    func fetch(id: Int) async -> User? { }
}
// No protocol overhead, type is known statically
```

## Error Handling Mastery

```swift
// Typed throws (Swift 6)
enum DatabaseError: Error {
    case connectionFailed
    case queryFailed(String)
    case transactionAborted
}

func query(_ sql: String) throws(DatabaseError) -> [String] {
    guard isConnected else {
        throw .connectionFailed
    }
    // ...
}

// Error hierarchy with recovery
protocol RecoveryError: Error {
    var recoveryOptions: [String] { get }
    var localizedFailureReason: String { get }
}

enum APIError: RecoveryError {
    case rateLimited
    case unauthorized
    case serverError(Int)

    var localizedFailureReason: String {
        switch self {
        case .rateLimited:
            return "Too many requests. Please try again later."
        case .unauthorized:
            return "Invalid credentials."
        case .serverError(let code):
            return "Server error: \(code)"
        }
    }

    var recoveryOptions: [String] {
        switch self {
        case .rateLimited:
            return ["Retry"]
        case .unauthorized:
            return ["Re-authenticate"]
        case .serverError:
            return ["Retry", "Contact Support"]
        }
    }
}

// Result-based error propagation
enum Result<T, E: Error> {
    case success(T)
    case failure(E)

    func flatMap<U>(_ transform: (T) -> Result<U, E>) -> Result<U, E> {
        switch self {
        case .success(let value):
            return transform(value)
        case .failure(let error):
            return .failure(error)
        }
    }
}

// Async error propagation chain
func performWorkflow() async throws -> Data {
    do {
        let user = try await fetchUser()
        let token = try await authenticate(user)
        return try await downloadData(with: token)
    } catch APIError.rateLimited {
        // Specific handling
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        return try await performWorkflow()
    } catch {
        // Generic handling
        throw WorkflowError.failed(underlying: error)
    }
}
```

## Interoperability

### Swift/ObjC Bridging

```swift
// @objc - expose to Objective-C
@objc
class DataService: NSObject {
    @objc
    func fetchData(_ completion: @escaping ([String]) -> Void) {
        // Accessible from ObjC
    }

    @objc(fetchDataAsynchronously:)
    func fetchData(completion: @escaping ([String]) -> Void) {
        // Custom ObjC selector name
    }
}

// @objcMembers - mark all as @objc
@objcMembers
class Model: NSObject {
    dynamic var name: String = ""
    // All properties and methods exposed
}

// NS_SWIFT_NAME for ObjC API optimization
// In Objective-C header:
// - (NSString *)stringByRemovingCharactersInSet:(NSCharacterSet *)characters
// NS_SWIFT_NAME(removingCharacters(_:));

// Swift sees as: removingCharacters(_:)

// Bridging header for mixing ObjC and Swift
// MyProject-Bridging-Header.h:
// #import "LegacyObjCClass.h"
// Then use LegacyObjCClass directly in Swift
```

### Swift/C++ Interop (Swift 5.9+)

```swift
// Import C++ types directly
import Cxx

// Use C++ std library
let vector = std.vector<Int32>()
vector.push_back(42)
vector.push_back(100)

// C++ class wrapper
func processVector(_ vec: std.vector<Int32>) {
    for i in 0..<vec.size() {
        print(vec[i])
    }
}

// Bridging custom C++ to Swift
struct SwiftWrapper {
    private var cppObject: CxxObject

    init() {
        cppObject = CxxObject()
    }

    func performWork() -> Int {
        Int(cppObject.doWork())
    }
}
```

### Swift/C Bridging

```swift
// Direct C interop
func sumArrayFromC(_ arr: UnsafePointer<Int32>, count: Int32) -> Int32 {
    var sum: Int32 = 0
    for i in 0..<count {
        sum += arr[Int(i)]
    }
    return sum
}

// Bridging header approach
// MyApp-Bridging-Header.h:
// #ifndef MyApp_Bridging_Header_h
// #define MyApp_Bridging_Header_h
// #include "C_functions.h"
// #endif

// Then use C functions directly in Swift:
// let result = c_calculate(42)

// Manual C struct wrapping
func withCString(_ str: String, _ closure: (UnsafePointer<CChar>?) -> Void) {
    str.withCString { cStr in
        closure(cStr)
    }
}

// Unsafe pointer conversions
let pointer: OpaquePointer = OpaquePointer(UnsafeMutableRawPointer.allocate(byteCount: 100, alignment: 8))
defer {
    pointer?.deallocate()
}
```

---

**Last Updated**: Swift 6.0+
**Scope**: Production-grade patterns for principal-level engineers
**Dependencies**: None (standard library only unless noted)

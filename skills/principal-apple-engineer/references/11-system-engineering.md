# System-Level Engineering & Low-Level Development on Apple Platforms

Expert-level reference for real-time programming, performance optimization, GPU computing, and system architecture patterns. Covers Metal, Accelerate, memory management, security, and IPC at the platform level.

## Real-Time Programming on Apple

### Thread Constraints & Mach Policies

Real-time threads cannot block. Strict rules: no malloc, no locks, no Objective-C messaging, no dynamic memory, no system calls that might block.

Use `THREAD_TIME_CONSTRAINT_POLICY` to declare real-time scheduling:

```c
#include <mach/thread_policy.h>
#include <mach/mach.h>

void set_realtime_priority(uint32_t period_us, uint32_t computation_us) {
    thread_time_constraint_policy_data_t policy;
    policy.period = period_us * 1000;      // nanoseconds
    policy.computation = computation_us * 1000;
    policy.constraint = period_us * 1000;  // hard deadline
    policy.preemptible = 0;                // cannot be preempted

    thread_policy_set(mach_thread_self(),
                     THREAD_TIME_CONSTRAINT_POLICY,
                     (thread_policy_t)&policy,
                     THREAD_TIME_CONSTRAINT_POLICY_COUNT);
}
```

### os_workgroup for Coordinated Real-Time Work

Coordinate multiple threads with synchronized deadlines:

```swift
import os

let workgroup = os_workgroup_create("com.app.render-workgroup")!

// Dispatch realtime work coordinated across threads
os_workgroup_interval_notify(workgroup) { workgroup, notify_token, clock_now in
    // Deadline: 5ms after clock_now
    let deadline = clock_now + 5_000_000  // nanoseconds

    // All threads in workgroup coordinate to deadline
    let work_result = os_workgroup_join(workgroup, token: notify_token)

    // Do RT-safe work here, all threads synchronized
}
```

## Memory & Performance Engineering

### Instruments Deep Dive

Use Time Profiler to find CPU hotspots:

```swift
import os

let subsystem = OSLog(subsystem: "com.app.performance", category: "profiling")

func profilingSignpost(_ name: StaticString, _ type: OSSignpostType = .begin) {
    os_signpost(type, log: subsystem, name: name)
}

// Call from code:
profilingSignpost("image-decode")
let decoded = decodeHDRImage(data)
profilingSignpost("image-decode", .end)
```

Allocations instrument findings: track peak memory, identify retain cycles. Leaks instrument finds unreachable allocations (not retained cycles—use Debug Memory Graph for those). System Trace correlates CPU, memory, I/O, and scheduling.

### Memory Mapping for Large Files

```c
#include <sys/mman.h>
#include <fcntl.h>

int fd = open("largefile.bin", O_RDONLY);
struct stat sb;
fstat(fd, &sb);

// Map entire file into address space
void *mapped = mmap(NULL, sb.st_size, PROT_READ, MAP_PRIVATE, fd, 0);

// Access as array—OS pages on demand
float *samples = (float *)mapped;
float peak = samples[1000000];  // Page fault if not in memory

// Advise kernel of access pattern
madvise(mapped, sb.st_size, MADV_SEQUENTIAL);

munmap(mapped, sb.st_size);
close(fd);
```

### Shared Memory with POSIX

```c
#include <sys/mman.h>
#include <fcntl.h>

// Producer
int fd = shm_open("/my_shared_buffer", O_CREAT | O_RDWR, 0600);
ftruncate(fd, 1024 * 1024);  // 1 MB
void *shared = mmap(NULL, 1024 * 1024, PROT_READ | PROT_WRITE,
                    MAP_SHARED, fd, 0);

// Consumer (different process)
int fd = shm_open("/my_shared_buffer", O_RDWR, 0);
void *shared = mmap(NULL, 1024 * 1024, PROT_READ | PROT_WRITE,
                    MAP_SHARED, fd, 0);

// Cleanup
munmap(shared, 1024 * 1024);
shm_unlink("/my_shared_buffer");
```

### Lock-Free Synchronization

Use `os_unfair_lock` for user-space contended locks (not real-time):

```swift
import os

class LockFreeDictionary {
    private var storage: [String: Int] = [:]
    private let lock = os_unfair_lock()

    func setValue(_ value: Int, forKey key: String) {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        storage[key] = value
    }
}

// For true lock-free, use atomic operations:
class AtomicCounter {
    private var _value: Int32 = 0

    func increment() -> Int32 {
        return OSAtomicIncrement32(&_value)
    }

    func compareAndSwap(expect: Int32, new: Int32) -> Bool {
        return OSAtomicCompareAndSwap32(expect, new, &_value)
    }
}
```

### Cache-Friendly Data Structures: AoS vs SoA

Array of Structures (poor cache locality):
```swift
struct Particle {
    var x: Float
    var y: Float
    var z: Float
    var vx: Float
    var vy: Float
    var vz: Float
}
var particles = [Particle](repeating: Particle(x: 0, y: 0, z: 0, vx: 0, vy: 0, vz: 0), count: 10000)
```

Structure of Arrays (cache-friendly):
```swift
struct ParticleSystem {
    var positions: ([Float], [Float], [Float])  // x, y, z arrays
    var velocities: ([Float], [Float], [Float]) // vx, vy, vz arrays

    mutating func update(dt: Float) {
        for i in positions.0.indices {
            positions.0[i] += velocities.0[i] * dt
            positions.1[i] += velocities.1[i] * dt
            positions.2[i] += velocities.2[i] * dt
        }
    }
}
```

## Metal & GPU Computing

### Metal Compute Pipeline

```swift
import Metal

let device = MTLCreateSystemDefaultDevice()!
let queue = device.makeCommandQueue()!

// Compile shader
let library = try! device.makeLibrary(source: """
kernel void add_arrays(device float *result [[buffer(0)]],
                      const device float *a [[buffer(1)]],
                      const device float *b [[buffer(2)]],
                      uint idx [[thread_position_in_grid]]) {
    result[idx] = a[idx] + b[idx];
}
""", options: nil)

let kernel = library.makeFunction(name: "add_arrays")!
let pipeline = try! device.makeComputePipelineState(function: kernel)

// Execute
let buffer_a = device.makeBuffer(bytes: a, length: a.count * 4)
let buffer_b = device.makeBuffer(bytes: b, length: b.count * 4)
let buffer_result = device.makeBuffer(length: a.count * 4)

let cmd = queue.makeCommandBuffer()!
let encoder = cmd.makeComputeCommandEncoder()!
encoder.setComputePipelineState(pipeline)
encoder.setBuffer(buffer_result, offset: 0, index: 0)
encoder.setBuffer(buffer_a, offset: 0, index: 1)
encoder.setBuffer(buffer_b, offset: 0, index: 2)

let threadgroups = MTLSize(width: 256, height: 1, depth: 1)
let threads = MTLSize(width: min(256, a.count), height: 1, depth: 1)
encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threads)
encoder.endEncoding()
cmd.commit()
cmd.waitUntilCompleted()
```

### Metal Performance Shaders

```swift
import MetalPerformanceShadersGraph

let graph = MPSGraph()

// Define computation graph: matrix multiply
let matrixA = MPSGraphPlaceholder(shape: [M, K], dataType: .float32)
let matrixB = MPSGraphPlaceholder(shape: [K, N], dataType: .float32)
let result = graph.matrixMultiplication(primary: matrixA,
                                       secondary: matrixB,
                                       name: nil)

// Execute
let feedDict: [MPSGraphTensor: MPSGraphTensorData] = [
    matrixA: MPSGraphTensorData(mpsndarray: ndarray_A),
    matrixB: MPSGraphTensorData(mpsndarray: ndarray_B)
]

let resultData = graph.run(resultTensor: result,
                          feedInputs: feedDict,
                          targetOperations: nil,
                          mode: .synchronous)
```

## Accelerate & SIMD

### vDSP Vector Operations

```swift
import Accelerate

var signal = [Float](repeating: 0, count: 4096)
var sine = [Float](repeating: 0, count: 4096)

// Generate sine wave
var phase = Float(0)
let increment = 2 * Float.pi * 440 / 48000
vDSP.sin(stride(from: 0, to: Float(4096), by: 1).map { Float($0) * increment },
         result: &sine)

// Convolution (FIR filter)
let kernel = [Float](repeating: 0.1, count: 51)
var filtered = [Float](repeating: 0, count: signal.count)
vDSP.convolve(signal, kernel: kernel, result: &filtered)

// FFT
var fftSetup = vDSP.FFTSetup(log2n: UInt32(log2(Float(4096))))!
vDSP.fft(&signal, with: fftSetup, inverse: false)
```

### SIMD Types in Swift

```swift
import simd

// Single-precision SIMD
let vec4 = SIMD4<Float>(1, 2, 3, 4)
let scaled = vec4 * 2  // [2, 4, 6, 8]
let dot = simd_dot(vec4, vec4)  // 30

// Matrix operations
let matrix = simd_float4x4(columns: (
    SIMD4<Float>(1, 0, 0, 0),
    SIMD4<Float>(0, 1, 0, 0),
    SIMD4<Float>(0, 0, 1, 0),
    SIMD4<Float>(0, 0, 0, 1)
))

// Quaternions for rotation
let quat = simd_quaternion(angle: Float.pi / 2, axis: SIMD3<Float>(0, 1, 0))
let rotated = simd_act(quat, SIMD3<Float>(1, 0, 0))  // [0, 0, -1]
```

## Networking at System Level

### Network Framework Connection

```swift
import Network

let endpoint = NWEndpoint.hostPort(host: "example.com", port: 443)
let params = NWParameters.tls
let connection = NWConnection(to: endpoint, using: params)

connection.stateUpdateHandler = { state in
    switch state {
    case .ready:
        print("Connected")
    case .failed(let error):
        print("Failed: \(error)")
    default:
        break
    }
}

connection.start(queue: .global())

// Send data
let data = "GET / HTTP/1.1\r\nHost: example.com\r\n\r\n".data(using: .utf8)!
connection.send(content: data, isComplete: true) { error in
    if let error = error {
        print("Send error: \(error)")
    }
}

// Receive
connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, error in
    if let data = data {
        let response = String(data: data, encoding: .utf8)
        print(response ?? "")
    }
}
```

### Bonjour Service Discovery

```swift
import Network

let serviceBrowser = NWBrowser(for: .bonjour(type: "_http._tcp", domain: "local."),
                               using: .tcp)

serviceBrowser.stateUpdateHandler = { state in
    print("Browser state: \(state)")
}

serviceBrowser.browseResultsChangedHandler = { results, changes in
    for result in results {
        switch result.endpoint {
        case .service(let name, let type, let domain, _):
            print("Found: \(name).\(type)\(domain)")
        default:
            break
        }
    }
}

serviceBrowser.start(queue: .global())
```

## C++ Interop for System Code

### Swift/C++ Bridge Module

Header file (module.modulemap):
```
module MySystemLib {
    umbrella header "MySystemLib.h"
    export *
}
```

C++ code (MySystemLib.h/cpp):
```cpp
#include <vector>
#include <string>

class SignalProcessor {
public:
    void process(const std::vector<float>& input, std::vector<float>& output) {
        for (size_t i = 0; i < input.size(); i++) {
            output[i] = input[i] * 0.5f;
        }
    }
};
```

Swift interop:
```swift
import MySystemLib

// Swift 5.9+ bridging
let processor = SignalProcessor()
var input = [Float](repeating: 1.0, count: 1024)
var output = [Float](repeating: 0, count: 1024)

// Calls C++ directly
processor.process(input, output)
```

### Calling Swift from C++

Use `@_cdecl` attribute to export Swift functions to C++:

```swift
@_cdecl("swift_process_samples")
func processSamples(_ input: UnsafePointer<Float>,
                 _ output: UnsafeMutablePointer<Float>,
                 _ count: Int32) {
    for i in 0..<Int(count) {
        output[i] = input[i] * 2
    }
}
```

Call from C++:
```cpp
extern "C" void swift_process_samples(const float *input, float *output, int32_t count);

int main() {
    float input[256] = {1, 2, 3};
    float output[256];
    swift_process_samples(input, output, 256);
}
```

## Security Engineering

### Secure Enclave & CryptoKit

```swift
import CryptoKit

// Generate P256 key pair
let privateKey = P256.Signing.PrivateKey()
let publicKey = privateKey.publicKey

// Sign data
let message = "Authenticate user".data(using: .utf8)!
let signature = try privateKey.signature(for: message)

// Verify
let isValid = publicKey.isValidSignature(signature, for: message)

// AES-GCM encryption
let symmetricKey = SymmetricKey(size: .bits256)
let sealed = try AES.GCM.seal(message, using: symmetricKey)
let decrypted = try AES.GCM.open(sealed, using: symmetricKey)
```

### Certificate Pinning

```swift
class PinnedURLSessionDelegate: NSObject, URLSessionDelegate {
    let certificateData: Data

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Verify certificate chain
        var secResult = SecTrustResultType.invalid
        SecTrustEvaluate(serverTrust, &secResult)

        // Extract leaf certificate and compare
        if let serverCert = SecTrustGetCertificateAtIndex(serverTrust, 0) {
            let serverData = SecCertificateCopyData(serverCert) as Data
            if serverData == certificateData {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
                return
            }
        }

        completionHandler(.cancelAuthenticationChallenge, nil)
    }
}
```

### Data Protection Classes

```swift
import Foundation

let fileURL = URL(fileURLWithPath: "/path/to/file")
let data = "Sensitive".data(using: .utf8)!

try data.write(to: fileURL, options: .completeFileProtection)

// NSFileProtectionComplete: encrypted always
// NSFileProtectionCompleteUnlessOpen: accessible only while unlocked
// NSFileProtectionCompleteUntilFirstUserAuthentication: accessible after first unlock
```

## Process & IPC

### XPC Service Communication

```swift
import Foundation

// Client side
let connection = NSXPCConnection(serviceName: "com.app.helper")
connection.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
connection.resume()

let helper = connection.remoteObjectProxyWithErrorHandler { error in
    print("XPC error: \(error)")
} as! HelperProtocol

helper.performExpensiveTask { result in
    print("Result: \(result)")
}

// Server side (in helper tool)
@objc protocol HelperProtocol {
    func performExpensiveTask(reply: @escaping (String) -> Void)
}

class Helper: HelperProtocol {
    func performExpensiveTask(reply: @escaping (String) -> Void) {
        let result = "Computed"
        reply(result)
    }
}

let listener = NSXPCListener(machServiceName: "com.app.helper")
listener.delegate = self
listener.resume()
```

### POSIX Named Pipes

```c
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>

// Create FIFO
mkfifo("/tmp/mypipe", 0666);

// Writer process
int fd = open("/tmp/mypipe", O_WRONLY);
const char *msg = "Hello from pipe";
write(fd, msg, strlen(msg));
close(fd);

// Reader process
int fd = open("/tmp/mypipe", O_RDONLY);
char buffer[256];
int n = read(fd, buffer, sizeof(buffer));
printf("Received: %.*s\n", n, buffer);
close(fd);
```

## File System Engineering

### APFS Features

```swift
import Foundation

let fileURL = URL(fileURLWithPath: "/path/to/file")

// Create clone (copy-on-write)
let cloneURL = URL(fileURLWithPath: "/path/to/clone")
try FileManager.default.copyItem(at: fileURL, to: cloneURL)
// Clone shares blocks until either is modified

// Extended attributes
try fileURL.setResourceValue("Custom Value", forKey: .customAttribute("com.app.metadata"))
if let value = try fileURL.resourceValues(forKeys: [.customAttribute("com.app.metadata")])
    .customAttribute("com.app.metadata") {
    print("Extended attr: \(value)")
}
```

### FSEvents Directory Monitoring

```swift
import Foundation

class DirectoryMonitor {
    let stream: FSEventStreamRef

    init(path: String, callback: @escaping ([String]) -> Void) {
        var context = FSEventStreamContext(version: 0, info: nil,
                                          retain: nil, release: nil, copyDescription: nil)

        stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { stream, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds in
                let paths = UnsafeMutableRawPointer(eventPaths)
                    .assumingMemoryBound(to: UnsafeMutablePointer<CChar>.self)

                var changedPaths: [String] = []
                for i in 0..<numEvents {
                    if let pathCString = paths[i] {
                        changedPaths.append(String(cString: pathCString))
                    }
                }
                callback(changedPaths)
            },
            &context,
            [path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            UInt32(kFSEventStreamCreateFlagFileEvents)
        )

        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), kCFRunLoopDefaultMode)
        FSEventStreamStart(stream)
    }

    deinit {
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
    }
}
```

## Energy & Thermal Management

### Thermal State & Power Assertions

```swift
import Foundation

let processInfo = ProcessInfo.processInfo

// Check thermal state
switch processInfo.thermalState {
case .nominal:
    print("Normal operation")
case .fair:
    print("Slight thermal pressure—reduce background activity")
case .serious:
    print("Significant thermal pressure—pause non-essential work")
case .critical:
    print("Extreme thermal pressure—emergency shutdown prep")
@unknown default:
    break
}

// Monitor thermal state changes
let center = OperationQueue.current
NotificationCenter.default.addObserver(
    forName: ProcessInfo.thermalStateDidChangeNotification,
    object: processInfo,
    queue: center,
    using: { _ in
        print("Thermal state changed to \(processInfo.thermalState)")
    }
)

// Prevent sleep during critical work
import IOKit.pwr_mgt

var assertionID: IOPMAssertionID = 0
IOPMAssertionCreateWithName(
    kIOPMAssertionTypeNoDisplaySleep as CFString,
    IOPMAssertionLevel(kIOPMAssertionLevelOn),
    "Processing critical data" as CFString,
    &assertionID
)

// Do work...

IOPMAssertionRelease(assertionID)
```

### Background Processing Budgets

```swift
import BackgroundTasks

let request = BGProcessingTaskRequest(identifier: "com.app.background-process")
request.requiresNetworkConnectivity = true
request.requiresExternalPower = false

try BGTaskScheduler.shared.submit(request)

// Handler
BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.app.background-process", using: nil) { task in
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1

    let operation = BlockOperation {
        // Do work
        print("Background work")
    }

    operation.completionBlock = {
        task.setTaskCompleted(success: !operation.isCancelled)
    }

    task.expirationHandler = {
        queue.cancelAllOperations()
    }

    queue.addOperation(operation)
}
```

---

**Total Reference Scope:** 11 major system domains. Use code examples as starting points for your own system-level implementations. Focus on pre-allocation, lock-free patterns, RT safety, and platform-specific optimizations.

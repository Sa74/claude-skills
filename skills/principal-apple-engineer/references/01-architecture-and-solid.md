# Clean Architecture & SOLID Principles for Apple Platforms

## Clean Architecture: The 3-Layer Foundation

Clean Architecture on Apple platforms divides code into three concentric layers, each with strict dependency rules.

### Layer Definitions & Dependency Rules

**Presentation Layer** (Views, ViewModels, Coordinators)
- Contains SwiftUI/UIKit, navigation, state management for UI
- Depends on Domain (business logic) and Data (repositories)
- **Critical Rule**: Never perform business logic here; only orchestrate domain entities and react to state

**Domain Layer** (Entities, Use Cases, Repositories/Protocols)
- Pure Swift—zero UIKit, SwiftUI, or Foundation networking imports
- Defines business rules, value objects, and protocol contracts
- Stateless, testable, framework-independent
- **Critical Rule**: The innermost layer must never import outer layers

**Data Layer** (API Clients, Database, Cache, Repositories)
- Implements repository protocols from Domain
- Contains networking, persistence, and external service integration
- Adapts external frameworks to domain contracts
- **Critical Rule**: Data layer can import Domain but Domain never imports Data

```swift
// ❌ VIOLATION: Domain imports UIKit or Foundation networking
import UIKit
import Alamofire

class UserUseCase {
    func fetchUser() -> AnyPublisher<User, Error> { ... }
}

// ✅ CORRECT: Domain uses only Swift types
protocol UserRepository {
    func fetchUser(id: String) async throws -> User
}

class FetchUserUseCase {
    let repository: UserRepository
    init(repository: UserRepository) { self.repository = repository }

    func execute(userId: String) async throws -> User {
        try await repository.fetchUser(id: userId)
    }
}
```

### Complete 3-Layer Example: Fetch and Display User Profile

**Domain Layer:**
```swift
// Domain/Entities.swift
public struct User: Equatable, Codable {
    public let id: String
    public let name: String
    public let email: String
    public let avatarURL: URL?
}

// Domain/Repositories/UserRepository.swift
public protocol UserRepository {
    func fetchUser(id: String) async throws -> User
    func saveUser(_ user: User) async throws
}

// Domain/UseCases/FetchUserUseCase.swift
public class FetchUserUseCase {
    private let repository: UserRepository

    public init(repository: UserRepository) {
        self.repository = repository
    }

    public func execute(userId: String) async throws -> User {
        try await repository.fetchUser(id: userId)
    }
}
```

**Data Layer:**
```swift
// Data/Models/UserDTO.swift
struct UserDTO: Codable {
    let id: String
    let name: String
    let email: String
    let avatarUrl: String?

    func toDomain() -> User {
        User(
            id: id,
            name: name,
            email: email,
            avatarURL: avatarUrl.flatMap(URL.init)
        )
    }
}

// Data/Services/APIClient.swift
class APIClient {
    private let session: URLSession
    private let baseURL: URL

    func get<T: Decodable>(_ endpoint: String) async throws -> T {
        let url = baseURL.appendingPathComponent(endpoint)
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// Data/Repositories/DefaultUserRepository.swift
class DefaultUserRepository: UserRepository {
    private let apiClient: APIClient
    private let cache: NSCache<NSString, NSData>

    init(apiClient: APIClient, cache: NSCache<NSString, NSData> = NSCache()) {
        self.apiClient = apiClient
        self.cache = cache
    }

    func fetchUser(id: String) async throws -> User {
        if let cached = cache.object(forKey: id as NSString),
           let user = try? JSONDecoder().decode(User.self, from: cached as Data) {
            return user
        }

        let dto: UserDTO = try await apiClient.get("users/\(id)")
        let user = dto.toDomain()

        if let encoded = try? JSONEncoder().encode(user) {
            cache.setObject(encoded as NSData, forKey: id as NSString)
        }

        return user
    }

    func saveUser(_ user: User) async throws {
        // Implement persistence
    }
}
```

**Presentation Layer (SwiftUI):**
```swift
// Presentation/ViewModels/UserProfileViewModel.swift
@Observable
class UserProfileViewModel {
    var user: User?
    var isLoading = false
    var errorMessage: String?

    private let fetchUserUseCase: FetchUserUseCase

    init(fetchUserUseCase: FetchUserUseCase) {
        self.fetchUserUseCase = fetchUserUseCase
    }

    func loadUser(id: String) async {
        isLoading = true
        errorMessage = nil

        do {
            user = try await fetchUserUseCase.execute(userId: id)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// Presentation/Views/UserProfileView.swift
struct UserProfileView: View {
    @State var viewModel: UserProfileViewModel
    let userId: String

    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView()
            } else if let user = viewModel.user {
                VStack(alignment: .leading, spacing: 16) {
                    if let avatarURL = user.avatarURL {
                        AsyncImage(url: avatarURL) { image in
                            image.resizable()
                                .scaledToFill()
                                .frame(height: 200)
                        } placeholder: {
                            ProgressView()
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(user.name).font(.title)
                        Text(user.email).font(.caption).foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding()
            } else if let error = viewModel.errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                    Text(error)
                    Button("Retry") { Task { await viewModel.loadUser(id: userId) } }
                }
            }
        }
        .task { await viewModel.loadUser(id: userId) }
    }
}
```

---

## SOLID Principles in Swift

### S: Single Responsibility Principle

A type should have one reason to change.

**❌ Violation:**
```swift
class UserManager {
    func fetchUser(id: String) async throws -> User { ... }
    func saveUser(_ user: User) throws { ... }
    func deleteUser(id: String) throws { ... }
    func validateEmail(_ email: String) -> Bool { ... }
    func sendWelcomeEmail(to user: User) async throws { ... }
    func logUserActivity(_ userId: String, action: String) { ... }
}
// Changes needed for: API logic, persistence, validation, email, logging—too many reasons
```

**✅ Correct:**
```swift
protocol UserRepository {
    func fetch(id: String) async throws -> User
    func save(_ user: User) async throws
}

protocol UserValidator {
    func isValidEmail(_ email: String) -> Bool
}

protocol EmailService {
    func sendWelcome(to user: User) async throws
}

protocol UserActivityLogger {
    func log(userId: String, action: String) async throws
}

class DefaultUserRepository: UserRepository { ... }
class EmailValidator: UserValidator { ... }
class SendGridEmailService: EmailService { ... }
class FirebaseActivityLogger: UserActivityLogger { ... }
```

### O: Open/Closed Principle

Open for extension, closed for modification.

**Strategy Pattern Example:**
```swift
// Domain
protocol ImageCacheStrategy {
    func save(_ data: Data, for key: String) async throws
    func retrieve(for key: String) async throws -> Data?
}

class ImageCache {
    private let strategy: ImageCacheStrategy

    init(strategy: ImageCacheStrategy) {
        self.strategy = strategy
    }

    func cacheImage(_ data: Data, url: String) async throws {
        try await strategy.save(data, for: url)
    }
}

// Extend without modifying ImageCache
class MemoryCacheStrategy: ImageCacheStrategy {
    private let cache = NSCache<NSString, NSData>()

    func save(_ data: Data, for key: String) async throws {
        cache.setObject(data as NSData, forKey: key as NSString)
    }

    func retrieve(for key: String) async throws -> Data? {
        cache.object(forKey: key as NSString) as Data?
    }
}

class DiskCacheStrategy: ImageCacheStrategy {
    private let fileManager = FileManager.default

    func save(_ data: Data, for key: String) async throws {
        let url = documentsDirectory.appendingPathComponent(key)
        try data.write(to: url)
    }

    func retrieve(for key: String) async throws -> Data? {
        let url = documentsDirectory.appendingPathComponent(key)
        return try fileManager.fileExists(atPath: url.path) ? try Data(contentsOf: url) : nil
    }
}
```

**Protocol Extensions for Open/Closed:**
```swift
protocol NetworkRequestInterceptor {
    func intercept(_ request: inout URLRequest) async throws
}

extension URLSession {
    func dataWithInterceptors(
        _ url: URL,
        interceptors: [NetworkRequestInterceptor]
    ) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        for interceptor in interceptors {
            try await interceptor.intercept(&request)
        }
        return try await data(for: request)
    }
}

// Extend behavior without modifying URLSession
class AuthenticationInterceptor: NetworkRequestInterceptor {
    let authToken: String

    func intercept(_ request: inout URLRequest) async throws {
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
    }
}
```

### I: Interface Segregation Principle

Many client-specific interfaces beat one general-purpose interface.

**❌ Monolithic Protocol:**
```swift
protocol UserService {
    func fetch(id: String) async throws -> User
    func save(_ user: User) async throws
    func delete(id: String) async throws
    func updateAvatar(_ imageData: Data, userId: String) async throws
    func changePassword(userId: String, newPassword: String) async throws
    func getTwoFactorMethods(userId: String) async throws -> [TwoFactorMethod]
    func enableTwoFactor(userId: String, method: TwoFactorMethod) async throws
}
```

**✅ Segregated Protocols:**
```swift
protocol UserFetcher {
    func fetch(id: String) async throws -> User
}

protocol UserPersistence {
    func save(_ user: User) async throws
    func delete(id: String) async throws
}

protocol UserAvatarManager {
    func updateAvatar(_ imageData: Data, userId: String) async throws
}

protocol PasswordManager {
    func changePassword(userId: String, newPassword: String) async throws
}

protocol TwoFactorManager {
    func getMethods(userId: String) async throws -> [TwoFactorMethod]
    func enable(_ method: TwoFactorMethod, userId: String) async throws
}

// Compose what you need
class UserProfileViewController {
    let fetcher: UserFetcher
    let persistence: UserPersistence
    let avatarManager: UserAvatarManager
    // Only depends on what it uses
}

class SecuritySettingsViewController {
    let passwordManager: PasswordManager
    let twoFactorManager: TwoFactorManager
}
```

### L: Liskov Substitution Principle

Subtypes must be substitutable for their base type without breaking behavior.

**❌ Violation:**
```swift
class Bird {
    func fly() -> String { "flying" }
}

class Penguin: Bird {
    override func fly() -> String {
        fatalError("Penguins cannot fly") // ❌ Violates LSP
    }
}

func makeBirdFly(_ bird: Bird) -> String {
    bird.fly() // Can crash if bird is a Penguin
}
```

**✅ Correct Design:**
```swift
protocol Animal {
    func move() -> String
}

protocol Flightable {
    func fly() -> String
}

class Eagle: Animal, Flightable {
    func move() -> String { fly() }
    func fly() -> String { "soaring" }
}

class Penguin: Animal {
    func move() -> String { "waddling" }
}

// Each type behaves correctly without surprising the caller
func letAnimalMove(_ animal: Animal) -> String {
    animal.move() // Always succeeds
}

// Flightable objects used where flight is expected
func watchFly(_ flyer: Flightable) -> String {
    flyer.fly() // Only called on things that can actually fly
}
```

**Another LSP Violation Example:**
```swift
// ❌ BAD: Mutable implementation of immutable protocol
protocol Identifiable {
    var id: UUID { get }
}

class User: Identifiable {
    var id: UUID  // Can be changed! Breaks protocol contract
}

// ✅ CORRECT: Return type must be consistent
protocol Identifiable {
    var id: UUID { get }
}

struct User: Identifiable {
    private let _id: UUID
    var id: UUID { _id } // Immutable as promised
}
```

### D: Dependency Inversion Principle

Depend on abstractions (protocols), not concrete implementations.

**Repository Pattern:**
```swift
// Domain: Abstraction
public protocol UserRepository {
    func fetch(id: String) async throws -> User
    func save(_ user: User) async throws
}

// Use case depends on abstraction
public class UpdateUserUseCase {
    private let repository: UserRepository

    public init(repository: UserRepository) {
        self.repository = repository
    }

    public func execute(user: User) async throws {
        try await repository.save(user)
    }
}

// Data: Concrete implementations
class RESTUserRepository: UserRepository {
    private let apiClient: APIClient

    func fetch(id: String) async throws -> User {
        try await apiClient.getUser(id: id)
    }

    func save(_ user: User) async throws {
        try await apiClient.updateUser(user)
    }
}

class CacheFirstUserRepository: UserRepository {
    private let cache: UserRepository
    private let remote: UserRepository

    func fetch(id: String) async throws -> User {
        return (try? await cache.fetch(id: id)) ?? (try await remote.fetch(id: id))
    }

    func save(_ user: User) async throws {
        try await cache.save(user)
        try await remote.save(user)
    }
}

// Composition: Inject abstraction at setup
let apiRepository = RESTUserRepository(apiClient: APIClient())
let cachedRepository = CacheFirstUserRepository(cache: InMemoryUserRepository(), remote: apiRepository)
let useCase = UpdateUserUseCase(repository: cachedRepository)
```

---

## Architectural Patterns Catalog

### MVVM with @Observable (iOS 17+)

```swift
// ViewModel
@Observable
class TodoListViewModel {
    var todos: [TodoItem] = []
    var isLoading = false
    var searchText = ""

    private let fetchTodosUseCase: FetchTodosUseCase

    init(fetchTodosUseCase: FetchTodosUseCase) {
        self.fetchTodosUseCase = fetchTodosUseCase
    }

    var filteredTodos: [TodoItem] {
        searchText.isEmpty ? todos : todos.filter { $0.title.contains(searchText) }
    }

    func loadTodos() async {
        isLoading = true
        do {
            todos = try await fetchTodosUseCase.execute()
        } catch {
            todos = []
        }
        isLoading = false
    }

    func toggleTodo(_ todo: TodoItem) async throws {
        var updated = todo
        updated.isCompleted.toggle()
        try await updateTodoUseCase.execute(todo: updated)
        // Update local state
        if let index = todos.firstIndex(where: { $0.id == updated.id }) {
            todos[index] = updated
        }
    }
}

// View
struct TodoListView: View {
    @State var viewModel: TodoListViewModel
    @State var showingNewTodo = false

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.filteredTodos.isEmpty {
                    ContentUnavailableView("No Todos", systemImage: "list.dash")
                } else {
                    List($viewModel.filteredTodos, editActions: .all) { $todo in
                        TodoRow(todo: $todo, onToggle: {
                            Task { try await viewModel.toggleTodo($todo) }
                        })
                    }
                }
            }
            .searchable($viewModel.searchText, prompt: "Search")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingNewTodo = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .task { await viewModel.loadTodos() }
        }
    }
}

struct TodoRow: View {
    @Binding var todo: TodoItem
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Button(action: onToggle) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(todo.isCompleted ? .green : .gray)
            }
            VStack(alignment: .leading) {
                Text(todo.title)
                if let description = todo.description {
                    Text(description).font(.caption).foregroundColor(.gray)
                }
            }
        }
    }
}
```

### MVVM-C: Coordinator Pattern for Navigation

```swift
// Coordinator
protocol Coordinator: AnyObject {
    var navigationController: UINavigationController { get set }
    func start()
}

class TodoCoordinator: Coordinator {
    var navigationController: UINavigationController
    private var childCoordinators: [Coordinator] = []

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func start() {
        let viewModel = TodoListViewModel(fetchTodosUseCase: resolveFetchTodosUseCase())
        viewModel.onSelectTodo = { [weak self] todo in
            self?.showTodoDetail(todo)
        }

        let controller = UIHostingController(rootView: TodoListView(viewModel: viewModel))
        navigationController.pushViewController(controller, animated: false)
    }

    func showTodoDetail(_ todo: TodoItem) {
        let coordinator = TodoDetailCoordinator(
            navigationController: navigationController,
            todo: todo
        )
        childCoordinators.append(coordinator)
        coordinator.start()
    }
}

// SwiftUI Navigation with Coordinator
@Observable
class TodoListViewModel {
    var selectedTodo: TodoItem?
    var todos: [TodoItem] = []

    func selectTodo(_ todo: TodoItem) {
        selectedTodo = todo
    }
}

struct TodoListWithNavigation: View {
    @State var viewModel: TodoListViewModel

    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            List(viewModel.todos) { todo in
                NavigationLink(value: todo) {
                    TodoRow(todo: todo)
                }
            }
            .navigationDestination(for: TodoItem.self) { todo in
                TodoDetailView(todo: todo)
            }
        }
    }
}
```

### Redux/TCA-Style State Management

```swift
// State
struct AppState {
    var todos: [TodoItem] = []
    var isLoading = false
    var error: Error?
    var filter: TodoFilter = .all
}

// Actions
enum AppAction {
    case fetchTodos
    case fetchTodosResponse(Result<[TodoItem], Error>)
    case toggleTodo(id: UUID)
    case setFilter(TodoFilter)
}

// Reducer
func appReducer(state: inout AppState, action: AppAction) {
    switch action {
    case .fetchTodos:
        state.isLoading = true
        state.error = nil

    case .fetchTodosResponse(.success(let todos)):
        state.todos = todos
        state.isLoading = false

    case .fetchTodosResponse(.failure(let error)):
        state.error = error
        state.isLoading = false

    case .toggleTodo(let id):
        if let index = state.todos.firstIndex(where: { $0.id == id }) {
            state.todos[index].isCompleted.toggle()
        }

    case .setFilter(let filter):
        state.filter = filter
    }
}

// Store
@Observable
class Store {
    var state: AppState
    private let reducer: (inout AppState, AppAction) -> Void

    init(initialState: AppState = AppState(), reducer: @escaping (inout AppState, AppAction) -> Void) {
        self.state = initialState
        self.reducer = reducer
    }

    func dispatch(_ action: AppAction) {
        reducer(&state, action)
    }
}

// View Integration
struct ReduxTodoView: View {
    @State var store: Store

    var body: some View {
        ZStack {
            if store.state.isLoading {
                ProgressView()
            } else {
                List(store.state.filteredTodos) { todo in
                    HStack {
                        Button(action: { store.dispatch(.toggleTodo(id: todo.id)) }) {
                            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                        }
                        Text(todo.title)
                    }
                }
            }
        }
        .onAppear { store.dispatch(.fetchTodos) }
    }
}
```

---

## SPM Module Architecture

### Multi-Module Structure

```
MyApp/
├── Package.swift
├── Modules/
│   ├── Domain/
│   │   ├── Sources/Domain/
│   │   │   ├── Entities/
│   │   │   ├── Repositories/
│   │   │   └── UseCases/
│   │   └── Tests/
│   ├── Data/
│   │   ├── Sources/Data/
│   │   │   ├── API/
│   │   │   ├── Persistence/
│   │   │   └── Repositories/
│   │   └── Tests/
│   └── Presentation/
│       ├── Sources/Presentation/
│       └── Resources/
```

**Package.swift:**
```swift
let package = Package(
    name: "MyApp",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Data", targets: ["Data"]),
        .library(name: "Presentation", targets: ["Presentation"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "0.1.0"),
    ],
    targets: [
        // DOMAIN: Pure business logic, no external dependencies
        .target(
            name: "Domain",
            dependencies: [],
            path: "Modules/Domain/Sources"
        ),
        .testTarget(
            name: "DomainTests",
            dependencies: ["Domain"],
            path: "Modules/Domain/Tests"
        ),

        // DATA: Implements Domain protocols, may use external SDKs
        .target(
            name: "Data",
            dependencies: [
                "Domain",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ],
            path: "Modules/Data/Sources"
        ),
        .testTarget(
            name: "DataTests",
            dependencies: ["Data", "Domain"],
            path: "Modules/Data/Tests"
        ),

        // PRESENTATION: UIKit/SwiftUI, depends on Domain and Data
        .target(
            name: "Presentation",
            dependencies: ["Domain", "Data"],
            path: "Modules/Presentation/Sources",
            resources: [.process("Resources")]
        ),
    ]
)
```

### Dependency Graph Rules

```swift
// ✅ CORRECT dependency directions
// Presentation → Domain
// Presentation → Data
// Data → Domain
// Domain → (nothing, pure Swift only)

// ❌ VIOLATIONS:
// Domain → Data (Domain should define protocols, Data implements)
// Domain → UIKit/SwiftUI (never)
// Data → Presentation (Data never imports UI)

// ✅ Presentation depends on protocols, not concrete implementations
import Domain

class ProfileViewController: UIViewController {
    let userRepository: UserRepository  // Protocol from Domain
    // Not: let userRepository: FirebaseUserRepository
}
```

### Internal vs Public APIs

```swift
// Modules/Domain/Sources/Domain/Public/Entities.swift
public struct User: Codable, Equatable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

// Modules/Domain/Sources/Domain/Public/Repositories/UserRepository.swift
public protocol UserRepository {
    func fetch(id: String) async throws -> User
}

// Modules/Domain/Sources/Domain/Internal/Validators.swift (not public)
struct EmailValidator {
    func isValid(_ email: String) -> Bool {
        email.contains("@")
    }
}
```

---

## Common Anti-Patterns & Fixes

### Massive ViewController/ViewModel

**❌ Anti-pattern:**
```swift
class UserViewController: UIViewController {
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var avatarImageView: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Network call
        URLSession.shared.dataTask(with: URL(string: "...")!) { data, _, _ in
            // Parse JSON
            // Update UI
            // Log to analytics
            // Cache image
            // Update database
        }.resume()
    }

    func validateEmail(_ email: String) -> Bool { ... }
    func formatPhoneNumber(_ phone: String) -> String { ... }
    func encryptPassword(_ password: String) -> String { ... }
}
```

**✅ Fix:**
```swift
// Separate concerns
class UserViewController: UIViewController {
    var viewModel: UserViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()
        Task { await viewModel.loadUser() }
    }
}

@Observable
class UserViewModel {
    var user: User?

    private let fetchUserUseCase: FetchUserUseCase

    init(fetchUserUseCase: FetchUserUseCase) {
        self.fetchUserUseCase = fetchUserUseCase
    }

    func loadUser() async { ... }
}
```

### God Objects / Manager-of-Managers

**❌ Anti-pattern:**
```swift
class AppManager {
    let networkManager = NetworkManager()
    let databaseManager = DatabaseManager()
    let cacheManager = CacheManager()
    let analyticsManager = AnalyticsManager()
    let authManager = AuthManager()

    func doEverything() { ... }
}
```

**✅ Fix: Composition over monolithic managers**
```swift
// Each responsibility has focused protocol
protocol NetworkClient { ... }
protocol Persistence { ... }
protocol CacheStrategy { ... }
protocol Analytics { ... }
protocol Authentication { ... }

// Inject only what's needed
class UserViewModel {
    let network: NetworkClient
    let persistence: Persistence

    init(network: NetworkClient, persistence: Persistence) { ... }
}
```

### Stringly-Typed APIs

**❌ Anti-pattern:**
```swift
func updateUser(with dictionary: [String: Any]) {
    if let name = dictionary["user_name"] as? String { ... }
    if let age = dictionary["user_age"] as? Int { ... }
}

let result = networkClient.post(endpoint: "user/123", data: ["action": "update", "type": "profile"])
```

**✅ Fix: Typed protocols and enums**
```swift
struct UpdateUserRequest {
    let userId: String
    let name: String
    let age: Int
}

enum UserEndpoint {
    case updateProfile(userId: String, request: UpdateUserRequest)

    var path: String {
        switch self {
        case .updateProfile(let userId, _):
            return "/users/\(userId)/profile"
        }
    }
}

func updateUser(request: UpdateUserRequest) async throws { ... }
```

### Premature vs Appropriate Abstraction

**❌ Over-abstraction:**
```swift
protocol StringFormatter { func format(_ s: String) -> String }
protocol IntFormatter { func format(_ i: Int) -> String }
protocol DateFormatter { func format(_ d: Date) -> String }

// Premature: one-off formatters as protocols when String.formatted() exists
```

**✅ Appropriate abstraction:**
```swift
// Abstracts real variation: different caching strategies
protocol CacheStrategy {
    func set(_ value: Data, for key: String) async throws
    func get(for key: String) async throws -> Data?
}

// Multiple implementations solve real problem
class InMemoryCacheStrategy: CacheStrategy { ... }
class DiskCacheStrategy: CacheStrategy { ... }
```

### Singleton Abuse

**❌ Anti-pattern:**
```swift
class NetworkClient {
    static let shared = NetworkClient()
    private init() {}

    func request(_ url: URL) async throws -> Data { ... }
}

// Hard to test, hidden dependency
class UserViewController: UIViewController {
    override func viewDidLoad() {
        let data = try? await NetworkClient.shared.request(url)
    }
}
```

**✅ Fix: Dependency injection**
```swift
class UserViewController: UIViewController {
    let networkClient: NetworkClient  // Injected, testable

    init(networkClient: NetworkClient) {
        self.networkClient = networkClient
    }
}

// For view controllers, use factory or coordinator
let networkClient = NetworkClient()
let controller = UserViewController(networkClient: networkClient)
```

---

## Cross-Platform Architecture

### Shared Domain & Data, Platform-Specific UI

```
MyApp/
├── Package.swift
├── Modules/
│   ├── Domain/         # Shared, no UIKit/SwiftUI
│   ├── Data/           # Shared, network/persistence
│   ├── iOSPresentation/
│   │   └── Sources/iOSPresentation/  # SwiftUI, iOS-specific
│   └── macOSPresentation/
│       └── Sources/macOSPresentation/  # SwiftUI, macOS-specific
```

**Cross-platform Package.swift:**
```swift
let package = Package(
    name: "CrossPlatformApp",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Data", targets: ["Data"]),
        .library(name: "iOSPresentation", targets: ["iOSPresentation"]),
        .library(name: "macOSPresentation", targets: ["macOSPresentation"]),
    ],
    targets: [
        .target(name: "Domain"),
        .target(name: "Data", dependencies: ["Domain"]),
        .target(
            name: "iOSPresentation",
            dependencies: ["Domain", "Data"]
        ),
        .target(
            name: "macOSPresentation",
            dependencies: ["Domain", "Data"]
        ),
    ]
)
```

### Protocol-Based Platform Abstraction

**When to use conditional compilation (#if os()):**

❌ **Wrong:** Over-using #if os()
```swift
// ❌ This signals wrong abstraction
struct DataRepository {
    func fetch() async throws -> Data {
        #if os(iOS)
            return try await fetchWithiOSAPI()
        #elseif os(macOS)
            return try await fetchWithmacOSAPI()
        #endif
    }
}
```

✅ **Correct:** Protocol-based abstraction
```swift
// Better: Abstract the difference
protocol PlatformDataProvider {
    func fetch() async throws -> Data
}

class iOSDataProvider: PlatformDataProvider {
    func fetch() async throws -> Data { ... }
}

class macOSDataProvider: PlatformDataProvider {
    func fetch() async throws -> Data { ... }
}

// Inject at setup time
let provider: PlatformDataProvider = {
    #if os(iOS)
    return iOSDataProvider()
    #elseif os(macOS)
    return macOSDataProvider()
    #endif
}()
```

**Conditional compilation is acceptable for:**
```swift
// Platform-specific configurations/constants
#if os(iOS)
let maxCacheSize: Int = 100_000_000  // 100 MB on iOS
#elseif os(macOS)
let maxCacheSize: Int = 1_000_000_000  // 1 GB on macOS
#endif

// Importing platform-specific frameworks (at module boundary)
#if os(iOS)
import UIKit
#else
import AppKit
#endif

// Feature flags tied to OS versions
#if os(iOS) && swift(>=6.0)
// Use new feature only on iOS with Swift 6+
#endif
```

### Composing Shared + Platform-Specific Features

```swift
// Domain/Entities.swift (shared)
public struct Document {
    public let id: String
    public let title: String
    public let content: String
    public let createdAt: Date
}

// Data/Repositories.swift (shared)
public protocol DocumentRepository {
    func fetch(id: String) async throws -> Document
}

// iOSPresentation/ViewModels/DocumentViewModel.swift (iOS-specific)
@Observable
class DocumentViewModel {
    var document: Document?

    private let repository: DocumentRepository
    private let shareService: iOSShareService  // iOS-specific

    init(repository: DocumentRepository, shareService: iOSShareService) {
        self.repository = repository
        self.shareService = shareService
    }

    func shareDocument() async {
        guard let document = document else { return }
        await shareService.share(document)
    }
}

// macOSPresentation/ViewModels/DocumentViewModel.swift (macOS-specific)
@Observable
class DocumentViewModel {
    var document: Document?

    private let repository: DocumentRepository
    private let printService: macOSPrintService  // macOS-specific

    init(repository: DocumentRepository, printService: macOSPrintService) {
        self.repository = repository
        self.printService = printService
    }

    func printDocument() async {
        guard let document = document else { return }
        await printService.print(document)
    }
}
```

---

## Testing Strategies Within Architecture

**Testing the three layers:**

```swift
// Domain layer: Pure unit tests, no mocks needed for repositories
class FetchUserUseCaseTests: XCTestCase {
    func test_executeFetchesUserFromRepository() async throws {
        let mockRepository = MockUserRepository()
        let useCase = FetchUserUseCase(repository: mockRepository)

        let user = try await useCase.execute(userId: "123")

        XCTAssertEqual(user.id, "123")
        XCTAssertTrue(mockRepository.fetchWasCalled)
    }
}

// Data layer: Test repository implementations with fake APIs
class UserRepositoryTests: XCTestCase {
    func test_saveUserPersistsToDatabase() async throws {
        let fakeAPI = FakeAPIClient()
        let repository = DefaultUserRepository(apiClient: fakeAPI)
        let user = User(id: "1", name: "Test", email: "test@example.com", avatarURL: nil)

        try await repository.save(user)

        XCTAssertTrue(fakeAPI.saveWasCalled)
    }
}

// Presentation layer: Test ViewModel updates and side effects
@MainActor
class UserProfileViewModelTests: XCTestCase {
    func test_loadUserUpdatesState() async {
        let mockUseCase = MockFetchUserUseCase()
        let viewModel = UserProfileViewModel(fetchUserUseCase: mockUseCase)

        await viewModel.loadUser(id: "123")

        XCTAssertNotNil(viewModel.user)
        XCTAssertFalse(viewModel.isLoading)
    }
}
```

This reference provides the architectural foundation and patterns for building scalable, testable Apple apps that separate concerns cleanly and follow SOLID principles consistently.

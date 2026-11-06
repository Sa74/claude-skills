# iOS & iPadOS Platform Development Reference

## SwiftUI Navigation & Presentation Patterns

### NavigationStack (iOS 16+)
```swift
// Basic NavigationStack with path-based routing
struct ContentView: View {
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List(items) { item in
                NavigationLink(value: item) {
                    Text(item.title)
                }
            }
            .navigationDestination(for: Item.self) { item in
                DetailView(item: item)
                    .navigationTitle(item.title)
            }
        }
    }
}

// Type-safe routing with AppRoute enum
enum AppRoute: Hashable {
    case detail(id: Int)
    case settings
    case profile(userID: String)
}

struct MainView: View {
    @State private var path: [AppRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(path: $path)
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .detail(let id):
                        DetailView(itemID: id)
                    case .settings:
                        SettingsView()
                    case .profile(let userID):
                        ProfileView(userID: userID)
                    }
                }
        }
    }
}
```

### NavigationSplitView (iPad/Multitasking)
```swift
// Three-column split view for iPad
struct SidebarApp: View {
    @State private var selectedCategory: Category?
    @State private var selectedItem: Item?

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(categories, selection: $selectedCategory) { category in
                NavigationLink(value: category) {
                    Label(category.name, systemImage: category.icon)
                }
            }
        } content: {
            // Content column
            if let category = selectedCategory {
                List(category.items, selection: $selectedItem) { item in
                    NavigationLink(value: item) {
                        Text(item.title)
                    }
                }
            }
        } detail: {
            // Detail column
            if let item = selectedItem {
                DetailView(item: item)
            } else {
                Text("Select an item")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// Adaptive split view (responds to size classes)
struct AdaptiveSplitView: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    @State private var selectedItem: Item?

    var body: some View {
        if sizeClass == .compact {
            // Phone: single column
            NavigationStack {
                ItemListView(selectedItem: $selectedItem)
            }
        } else {
            // iPad: split view
            NavigationSplitView {
                ItemListView(selectedItem: $selectedItem)
            } detail: {
                if let item = selectedItem {
                    DetailView(item: item)
                } else {
                    Text("Select an item")
                }
            }
        }
    }
}
```

### Sheet & Fullscreen Presentations
```swift
// Sheet with detection of dismiss
struct SheetExample: View {
    @State private var isPresented = false
    @State private var selectedData: String?

    var body: some View {
        Button("Show Sheet") {
            isPresented = true
        }
        .sheet(isPresented: $isPresented, onDismiss: {
            print("Sheet dismissed")
        }) {
            EditView(data: $selectedData)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

// Fullscreen cover with state passing
struct FullscreenExample: View {
    @State private var showCamera = false
    @State private var capturedImage: UIImage?

    var body: some View {
        VStack {
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }

            Button("Capture Photo") {
                showCamera = true
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(image: $capturedImage, isPresented: $showCamera)
                .ignoresSafeArea()
        }
    }
}

// Popover with size preference
struct PopoverExample: View {
    @State private var showPopover = false

    var body: some View {
        Button("Show Menu") {
            showPopover = true
        }
        .popover(isPresented: $showPopover,
                 arrowEdge: .top) {
            VStack(spacing: 12) {
                Button("Option 1") { }
                Divider()
                Button("Option 2") { }
            }
            .padding()
            .presentationCompactAdaptation(.popover)
        }
    }
}
```

## Environment Values & Size Classes

```swift
// Critical environment values for responsive design
struct ResponsiveLayout: View {
    @Environment(\.horizontalSizeClass) var hSizeClass
    @Environment(\.verticalSizeClass) var vSizeClass
    @Environment(\.dynamicTypeSize) var typeSize
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.legibilityWeight) var weight

    var body: some View {
        VStack(spacing: typeSize.lineSpacing) {
            if hSizeClass == .compact && vSizeClass == .regular {
                // iPhone portrait
                iPhonePortraitLayout()
            } else if hSizeClass == .regular && vSizeClass == .compact {
                // iPhone landscape
                iPhoneLandscapeLayout()
            } else {
                // iPad
                iPadLayout()
            }
        }
    }

    @ViewBuilder
    func iPhonePortraitLayout() -> some View {
        VStack(spacing: 16) {
            Text("Portrait Layout")
                .font(.system(.headline, design: .rounded))
        }
    }

    @ViewBuilder
    func iPhoneLandscapeLayout() -> some View {
        HStack(spacing: 16) {
            Text("Landscape Layout")
        }
    }

    @ViewBuilder
    func iPadLayout() -> some View {
        HStack(spacing: 32) {
            Text("iPad Sidebar")
                .frame(maxWidth: 300)
            Text("Main Content")
        }
    }
}

// Dynamic Type scaling
struct AccessibleText: View {
    @Environment(\.dynamicTypeSize) var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Title")
                .font(typeSize.isAccessibilitySize ? .title3 : .title2)

            Text("Body text that scales with accessibility settings")
                .font(.body)
                .lineLimit(typeSize <= .medium ? 3 : nil)
        }
    }
}
```

## ScrollView Performance

```swift
// LazyVStack for large lists (iOS 14+)
struct LazyScrollPerformance: View {
    let items: [Item]
    @State private var scrollPosition: Int?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(items) { item in
                    ItemRow(item: item)
                        .id(item.id)
                }
            }
            .padding()
        }
        .scrollPosition(id: $scrollPosition)
        .onAppear {
            scrollPosition = items.first?.id
        }
    }
}

// LazyHGrid for grid layouts
struct GridPerformance: View {
    let items: [Photo]
    let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 8)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(items) { photo in
                    PhotoCell(photo: photo)
                        .frame(height: 100)
                }
            }
            .padding()
        }
    }
}

// Scroll modifier with tracking
struct ScrollTrackingView: View {
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(0..<50, id: \.self) { index in
                    Text("Item \(index)")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue.opacity(0.1))
                }
            }
        }
        .onScrollGeometryChange(for: CGFloat.self) { proxy in
            proxy.contentOffset.y
        } action: { oldValue, newValue in
            scrollOffset = newValue
        }
    }
}
```

## Search & Toolbar

```swift
// Searchable modifier with suggestions
struct SearchableExample: View {
    @State private var searchText = ""
    @State private var suggestions: [String] = []
    let items = ["Apple", "Banana", "Cherry", "Date", "Elderberry"]

    var filteredItems: [String] {
        if searchText.isEmpty {
            return items
        }
        return items.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List(filteredItems, id: \.self) { item in
                Text(item)
            }
            .searchable(text: $searchText,
                       prompt: "Search items",
                       suggestions: {
                ForEach(suggestions, id: \.self) { suggestion in
                    Text(suggestion)
                        .searchCompletion(suggestion)
                }
            })
            .onChange(of: searchText) { oldValue, newValue in
                suggestions = items.filter { $0.hasPrefix(newValue) }
            }
        }
    }
}

// Toolbar with iPad hardware keyboard support
struct ToolbarExample: View {
    @State private var showFilters = false
    @Environment(\.horizontalSizeClass) var sizeClass

    var body: some View {
        NavigationStack {
            ScrollView {
                // Content
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Items")
                        .font(.headline)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showFilters = true }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    if sizeClass == .compact {
                        NavigationLink(destination: SidebarView()) {
                            Image(systemName: "sidebar.left")
                        }
                    }
                }
            }
            .sheet(isPresented: $showFilters) {
                FiltersView()
            }
        }
    }
}

// KeyboardShortcut for iPad
struct KeyboardShortcutExample: View {
    @State private var newItem = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack {
            TextField("New item", text: $newItem)
                .focused($isInputFocused)

            Button("Add Item") {
                // Add logic
            }
            .keyboardShortcut(.defaultAction)
        }
        .onKeyboardShortcut(KeyEquivalent("n"), modifiers: [.command]) {
            isInputFocused = true
        }
    }
}

// Bottom sheet/bar patterns
struct BottomSheetExample: View {
    @State private var isExpanded = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(0..<20, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.blue.opacity(0.3))
                            .frame(height: 80)
                    }
                }
            }

            // Bottom bar
            VStack(spacing: 0) {
                Divider()
                HStack {
                    Button("Action") { }
                    Spacer()
                    Button("Confirm") { }
                }
                .padding()
                .background(.ultraThickMaterial)
            }
        }
    }
}
```

## UIKit Integration

### UIViewRepresentable Pattern
```swift
// Wrap UIView with SwiftUI integration
struct MapViewRepresentable: UIViewRepresentable {
    let coordinate: CLLocationCoordinate2D
    @Binding var isLoading: Bool

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        uiView.setRegion(region, animated: true)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        @Binding var isLoading: Bool

        init(isLoading: Binding<Bool>) {
            self._isLoading = isLoading
        }

        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
            isLoading = false
        }
    }
}
```

### UIViewControllerRepresentable Pattern
```swift
// Wrap UIViewController with lifecycle management
struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedImage: $selectedImage, dismiss: dismiss)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        @Binding var selectedImage: UIImage?
        let dismiss: DismissAction

        init(selectedImage: Binding<UIImage?>, dismiss: DismissAction) {
            self._selectedImage = selectedImage
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                 didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                selectedImage = image
            }
            dismiss()
        }
    }
}
```

### UIHostingController Integration
```swift
// Embed SwiftUI in UIKit UIViewController
class ContainerViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let swiftUIView = SwiftUIContentView()
        let hostingController = UIHostingController(rootView: swiftUIView)

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        hostingController.didMove(toParent: self)
    }
}
```

## UICollectionView with DiffableDataSource

```swift
// Modern compositional layout + diffable data source
class PhotoCollectionViewController: UIViewController {
    var collectionView: UICollectionView!
    var dataSource: UICollectionViewDiffableDataSource<Section, Photo>!

    enum Section {
        case main
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureCollectionView()
        configureDataSource()
        loadData()
    }

    func configureCollectionView() {
        let layout = UICollectionViewCompositionalLayout { _, environment in
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(0.5),
                heightDimension: .fractionalHeight(1.0)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .fractionalWidth(0.5)
            )
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)

            return section
        }

        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemBackground
        view.addSubview(collectionView)

        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: PhotoCell.identifier)
    }

    func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource(
            collectionView: collectionView,
            cellProvider: { collectionView, indexPath, photo in
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: PhotoCell.identifier,
                    for: indexPath
                ) as! PhotoCell
                cell.configure(with: photo)
                return cell
            }
        )
    }

    func loadData() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Photo>()
        snapshot.appendSections([.main])
        snapshot.appendItems(photos, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: true)
    }
}
```

## iPad-Specific Features

### Multitasking & Stage Manager
```swift
// SceneDelegate handling for multiple windows (Stage Manager)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // Stage Manager detection
        if windowScene.windows.count > 1 {
            // Multiple windows open
        }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: ContentView())
        self.window = window
        window.makeKeyAndVisible()
    }

    func scenePhase(_ scene: UIScene, willEnter phase: UIScene.Phase) {
        switch phase {
        case .active:
            print("App is active")
        case .inactive:
            print("App is inactive")
        case .background:
            print("App in background")
        @unknown default:
            break
        }
    }
}

// Scene phase detection in SwiftUI
struct ScenePhaseExample: View {
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        Text("Current phase: \(scenePhase == .active ? "Active" : "Inactive")")
            .onChange(of: scenePhase) { oldPhase, newPhase in
                switch newPhase {
                case .active:
                    print("Resumed")
                case .inactive:
                    print("Paused")
                case .background:
                    print("Backgrounded")
                @unknown default:
                    break
                }
            }
    }
}
```

### Pointer & Trackpad Support
```swift
// iPad pointer interaction
struct PointerInteractionExample: View {
    @State private var isHovered = false

    var body: some View {
        Button(action: {}) {
            Text("Hover me on iPad")
                .frame(maxWidth: .infinity)
                .padding()
                .background(isHovered ? .blue : .gray)
                .foregroundStyle(.white)
                .cornerRadius(8)
        }
        .onContinuousHover { phase in
            switch phase {
            case .active:
                isHovered = true
            case .ended:
                isHovered = false
            }
        }
    }
}

// UIPointerInteraction for UIKit
class PointerButton: UIButton {
    override func viewDidLoad() {
        super.viewDidLoad()

        let interaction = UIPointerInteraction(delegate: PointerDelegate())
        addInteraction(interaction)
    }
}

class PointerDelegate: NSObject, UIPointerInteractionDelegate {
    func pointerInteraction(_ interaction: UIPointerInteraction,
                          styleFor region: UIPointerRegion) -> UIPointerStyle? {
        var config = UIPointerHoverEffect.Options()
        config.prefersShadow = true
        config.prefersScaledContent = true

        let effect = UIPointerHoverEffect(options: config)
        let shape = UIPointerShape.roundedRect(CGRect(x: 0, y: 0, width: 100, height: 40))

        return UIPointerStyle(effect: effect, shape: shape)
    }
}
```

### Apple Pencil & PencilKit
```swift
// PencilKit canvas integration
struct PencilKitView: UIViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = drawing
        canvas.delegate = context.coordinator
        canvas.tool = PKInkingTool(.pen, color: .black, width: 5)
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.drawing = drawing
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var drawing: PKDrawing

        init(drawing: Binding<PKDrawing>) {
            self._drawing = drawing
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            drawing = canvasView.drawing
        }
    }
}

// PencilKit with tool picker
struct DrawingApp: View {
    @State private var drawing = PKDrawing()
    @State private var showToolPicker = true

    var body: some View {
        ZStack {
            PencilKitView(drawing: $drawing)
                .ignoresSafeArea()

            VStack(alignment: .trailing) {
                HStack {
                    Button("Save") { saveDrawing() }
                    Button("Clear") { drawing = PKDrawing() }
                }
                .padding()
                Spacer()
            }
        }
    }

    func saveDrawing() {
        if let image = drawing.image(from: drawing.bounds, scale: 1) {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
    }
}
```

## App Lifecycle & Background Tasks

```swift
// Modern SwiftUI App lifecycle
@main
struct MyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    print("App launched")
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                print("Active")
            case .inactive:
                print("Inactive")
            case .background:
                startBackgroundTask()
            @unknown default:
                break
            }
        }
    }

    @Environment(\.scenePhase) var scenePhase

    func startBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "BackgroundWork") {
            UIApplication.shared.endBackgroundTask(self.backgroundTask)
            self.backgroundTask = .invalid
        }

        DispatchQueue.global(qos: .background).async {
            // Background work
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
}

// UIApplicationDelegate for advanced lifecycle
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }

    func application(_ application: UIApplication,
                   didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                   fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Handle push notification
        completionHandler(.newData)
    }
}

// Background app refresh (iOS 13+)
func scheduleBackgroundRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: "com.example.app.refresh")
    request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 15) // 15 minutes

    do {
        try BGTaskScheduler.shared.submit(request)
    } catch {
        print("Could not schedule refresh: \(error)")
    }
}

// Processing task for long operations
func scheduleBackgroundProcessing() {
    let request = BGProcessingTaskRequest(identifier: "com.example.app.processing")
    request.requiresNetworkConnectivity = true
    request.requiresExternalPower = true

    do {
        try BGTaskScheduler.shared.submit(request)
    } catch {
        print("Could not schedule processing task: \(error)")
    }
}
```

## Data Persistence

### SwiftData (iOS 17+)
```swift
@Model
final class Item {
    var title: String
    var timestamp: Date
    var isCompleted: Bool

    @Relationship(deleteRule: .cascade) var subitems: [SubItem] = []

    init(title: String, timestamp: Date = Date(), isCompleted: Bool = false) {
        self.title = title
        self.timestamp = timestamp
        self.isCompleted = isCompleted
    }
}

@Model
final class SubItem {
    var title: String
    var parent: Item?

    init(title: String) {
        self.title = title
    }
}

// SwiftUI query and mutation
struct ContentView: View {
    @Query(sort: \.timestamp, order: .reverse) var items: [Item]
    @Environment(\.modelContext) var modelContext
    @State private var newItemTitle = ""

    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    TextField("New item", text: $newItemTitle)
                    Button("Add") {
                        let item = Item(title: newItemTitle)
                        modelContext.insert(item)
                        newItemTitle = ""
                    }
                }
                .padding()

                List {
                    ForEach(items) { item in
                        Text(item.title)
                            .onTapGesture {
                                item.isCompleted.toggle()
                            }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            modelContext.delete(items[index])
                        }
                    }
                }
            }
        }
        .modelContainer(for: Item.self)
    }
}
```

### Core Data (Legacy)
```swift
// NSPersistentContainer setup
let container = NSPersistentContainer(name: "MyModel")
container.loadPersistentStores { _, error in
    if let error = error as? NSError {
        print("Core Data error: \(error)")
    }
}

// Fetching with NSFetchRequest
func fetchItems() -> [Item] {
    let request: NSFetchRequest<Item> = Item.fetchRequest()
    request.sortDescriptors = [NSSortDescriptor(keyPath: \Item.timestamp, ascending: false)]

    do {
        return try container.viewContext.fetch(request)
    } catch {
        print("Fetch error: \(error)")
        return []
    }
}

// Saving context
func saveContext() {
    let context = container.viewContext
    if context.hasChanges {
        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            print("Save error: \(nsError)")
        }
    }
}
```

### Keychain for Credentials
```swift
// Secure credential storage
class KeychainManager {
    static let shared = KeychainManager()

    func save(password: String, for account: String) {
        let data = password.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    func retrieve(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)

        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
```

## Networking with URLSession

```swift
// Async/await URLSession with error handling
class APIClient {
    let session = URLSession.shared

    func fetchUsers(from url: URL) async throws -> [User] {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.serverError(httpResponse.statusCode)
        }

        return try JSONDecoder().decode([User].self, from: data)
    }

    func uploadData(_ data: Data, to url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (responseData, _) = try await session.upload(for: request, from: data)
        let response = try JSONDecoder().decode(UploadResponse.self, from: responseData)
        return response.id
    }
}

enum APIError: LocalizedError {
    case invalidResponse
    case serverError(Int)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let code):
            return "Server error: \(code)"
        case .decodingError:
            return "Failed to decode response"
        }
    }
}

// Certificate pinning
class PinningDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession,
                   didReceive challenge: URLAuthenticationChallenge,
                   completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Verify certificate chain
        var secResult = SecTrustResultType.invalid
        let status = SecTrustEvaluate(serverTrust, &secResult)

        if status == errSecSuccess {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
```

## Key Frameworks Reference

### HealthKit
```swift
// Request authorization and fetch step count
class HealthKitManager {
    let store = HKHealthStore()

    func requestAuthorization() async throws {
        let types: Set = [HKQuantityType(.stepCount)]
        try await store.requestAuthorization(toShare: [], read: types)
    }

    func fetchStepsForToday() async throws -> HKQuantitySample? {
        let stepType = HKQuantityType(.stepCount)
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: now,
            options: .strictStartDate
        )

        let query = HKSampleQuery(
            sampleType: stepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { query, samples, error in
            // Handle results
        }

        store.execute(query)
        return nil
    }
}
```

### MapKit (SwiftUI)
```swift
// Modern Map view with annotations
struct MapExample: View {
    @State private var position: MapCameraPosition = .automatic
    @State private var annotations: [AnnotatedItem] = []

    var body: some View {
        Map(position: $position) {
            ForEach(annotations) { item in
                Annotation("", coordinate: item.coordinate) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .onMapCameraChange { context in
            position = context.camera
        }
    }
}

struct AnnotatedItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String
}
```

### ActivityKit & Live Activities (iOS 16.1+)
```swift
// Define live activity attributes
struct FitnessActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var caloriesBurned: Int
        var stepsCount: Int
    }

    var activityName: String
}

// Start live activity
func startLiveActivity() async {
    let initialState = FitnessActivityAttributes.ContentState(
        caloriesBurned: 0,
        stepsCount: 0
    )

    let attributes = FitnessActivityAttributes(activityName: "Morning Run")

    do {
        let activity = try Activity<FitnessActivityAttributes>.request(
            attributes: attributes,
            contentState: initialState,
            pushType: .token
        )

        // Handle activity token for push updates
        for await data in activity.pushTokenUpdates {
            // Send to server
        }
    } catch {
        print("Failed to start activity: \(error)")
    }
}
```

### WidgetKit
```swift
// Define widget provider
struct ItemWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ItemWidgetEntry {
        ItemWidgetEntry(date: Date(), itemCount: 5)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ItemWidgetEntry>) -> ()) {
        var entries: [ItemWidgetEntry] = []
        let currentDate = Date()

        for i in 0..<5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: i, to: currentDate)!
            entries.append(ItemWidgetEntry(date: entryDate, itemCount: Int.random(in: 1...10)))
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct ItemWidgetEntry: TimelineEntry {
    let date: Date
    let itemCount: Int
}

struct ItemWidget: Widget {
    let kind: String = "ItemWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ItemWidgetProvider()) { entry in
            VStack {
                Text("Items: \(entry.itemCount)")
                    .font(.headline)
                Text(entry.date, style: .time)
                    .font(.caption)
            }
            .padding()
        }
        .configurationDisplayName("Item Widget")
        .description("Shows item count")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
```

---

**Reference compiled for Principal-level iOS/iPadOS development with production-ready patterns.**

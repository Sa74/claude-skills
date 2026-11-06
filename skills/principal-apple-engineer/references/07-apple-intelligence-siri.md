# Apple Intelligence, Siri & On-Device ML Reference

Expert-level patterns for integrating Apple Intelligence, App Intents, Siri, and CoreML into production iOS/macOS applications.

---

## App Intents Framework

### Core Protocol Structure

The `AppIntent` protocol is the foundation for Siri integration and Apple Intelligence semantic understanding:

```swift
import AppIntents

protocol AppIntent: Sendable {
    associatedtype RequestType: AppIntentRequest = DefaultAppIntentRequest
    associatedtype ResultType: AppIntentResult

    @MainActor
    func perform() async throws -> ResultType
}

// Minimal intent implementation
struct CreateTaskIntent: AppIntent {
    @Parameter(title: "Task Title") var title: String
    @Parameter(title: "Priority", default: .medium) var priority: TaskPriority
    @Parameter(title: "Due Date") var dueDate: Date?

    static let title: LocalizedStringResource = "Create a Task"
    static let description: LocalizedStringResource? = "Creates a new task in your task list"
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        let task = Task(title: title, priority: priority, dueDate: dueDate)
        try await TaskManager.shared.save(task)

        return .result(
            value: task,
            dialog: IntentDialog("Created task \(title)")
        )
    }
}
```

### Parameter Definitions & Types

Use `@Parameter` macro for type-safe, discoverable parameters:

```swift
struct AdvancedTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Manage Task"

    // Simple parameter with title and description
    @Parameter(title: "Task", description: "The task to modify")
    var task: TaskEntity

    // Parameter with dynamic options
    @Parameter(
        title: "Assign To",
        description: "Team member to assign task to",
        default: .current()
    )
    var assignee: TeamMember

    // Optional parameter with constraint
    @Parameter(
        title: "Estimated Hours",
        description: "Time estimate (1-100 hours)"
    )
    var estimatedHours: Int?

    // Conditional parameter (shown only if certain conditions)
    @Parameter(title: "Recurrence")
    var recurrence: TaskRecurrence?

    @MainActor
    func perform() async throws -> some IntentResult {
        task.assignee = assignee
        if let hours = estimatedHours {
            task.estimatedHours = min(100, max(1, hours))
        }
        task.recurrence = recurrence
        try await TaskManager.shared.save(task)

        return .result(
            value: task,
            dialog: IntentDialog("Updated task \(task.title)")
        )
    }
}
```

### IntentResult Patterns

Structure responses for optimal Siri/Apple Intelligence presentation:

```swift
struct TaskListIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Tasks"

    @Parameter(title: "Filter") var filter: TaskFilter = .all

    @MainActor
    func perform() async throws -> some IntentResult {
        let tasks = try await TaskManager.shared.fetch(filter: filter)

        // Simple result with value
        if tasks.isEmpty {
            return .result(
                value: [],
                dialog: IntentDialog("You have no tasks")
            )
        }

        // Result with formatted dialog
        let count = tasks.count
        let summary = tasks.prefix(3).map(\.title).joined(separator: ", ")

        return .result(
            value: tasks,
            dialog: IntentDialog(
                stringLiteral: "You have \(count) tasks: \(summary)"
            )
        )
    }
}

// Opening another intent from result
struct ViewTaskDetailIntent: AppIntent {
    static let title: LocalizedStringResource = "View Task"

    @Parameter(title: "Task") var task: TaskEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        return .result(
            value: task,
            opensIntent: OpenAppIntent(
                intent: TaskDetailIntent(task: task),
                behavior: .default
            )
        )
    }
}
```

### App Entities for Semantic Indexing

Entities enable Apple Intelligence to understand your app's data:

```swift
struct TaskEntity: AppEntity, Identifiable {
    typealias DefaultQuery = TaskEntityQuery

    let id: UUID
    var title: String
    var description: String
    var priority: TaskPriority
    var isCompleted: Bool
    var dueDate: Date?
    var assignee: TeamMember?

    // Display representation for Siri/Spotlight
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: title),
            subtitle: LocalizedStringResource(
                stringLiteral: priority.rawValue.capitalized
            ),
            image: DisplayRepresentation.Image(
                systemName: isCompleted ? "checkmark.circle.fill" : "circle"
            )
        )
    }

    // Entity identifier
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: LocalizedStringResource("Task"))
    }
}

// Query for finding and filtering entities
struct TaskEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [TaskEntity] {
        return try await TaskManager.shared.fetch(ids: identifiers)
    }

    func suggestedEntities() async throws -> [TaskEntity] {
        return try await TaskManager.shared.fetch(
            filter: .incomplete,
            limit: 10,
            sortBy: .dueDate
        )
    }

    // Entity string query for text search (used by Apple Intelligence)
    func entities(matching string: String) async throws -> [TaskEntity] {
        return try await TaskManager.shared.search(query: string)
    }
}

// Property query for semantic understanding
struct TaskEntityPropertyQuery: EntityPropertyQuery {
    static let properties: [KeyPath<TaskEntity, String>] = [
        \TaskEntity.title,
        \TaskEntity.description
    ]

    static let sortingOptions: [EntitySortOption<TaskEntity>] = [
        EntitySortOption(keyPath: \TaskEntity.dueDate, name: "Due Date"),
        EntitySortOption(keyPath: \TaskEntity.priority, name: "Priority")
    ]
}
```

### Dynamic Options & Conditional Parameters

Provide contextual options to users:

```swift
struct AssignTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Assign Task"

    @Parameter(title: "Task") var task: TaskEntity

    // Dynamic options computed based on app state
    @Parameter(
        title: "Assignee",
        description: "Team member to assign to",
        options: AvailableTeamMembersProvider()
    )
    var assignee: TeamMember

    @Parameter(title: "Deadline") var deadline: Date?

    // Conditional: only show if task allows subtasks
    @Parameter(title: "Create Subtask")
    var createSubtask: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        task.assignee = assignee
        if let deadline = deadline {
            task.dueDate = deadline
        }

        if createSubtask {
            let subtask = TaskEntity(title: "Subtask of \(task.title)")
            subtask.parent = task
            try await TaskManager.shared.save(subtask)
        }

        try await TaskManager.shared.save(task)
        return .result(dialog: IntentDialog("Assigned to \(assignee.name)"))
    }
}

// Dynamic options provider
struct AvailableTeamMembersProvider: DynamicOptionsProvider {
    @MainActor
    func results() async throws -> [TeamMember] {
        return try await TeamManager.shared.fetchActiveMembers()
    }

    @MainActor
    func defaultResult() async -> TeamMember? {
        return try? await TeamManager.shared.currentUser()
    }
}
```

### Parameter Summary for Human-Readable Dialogs

Define how parameters appear in Siri's confirmation UI:

```swift
struct ComplexTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Schedule Task"

    @Parameter(title: "Task") var task: TaskEntity
    @Parameter(title: "Date") var date: Date
    @Parameter(title: "Priority") var priority: TaskPriority
    @Parameter(title: "Add Reminder") var addReminder: Bool = false

    static var parameterSummary: ParameterSummary {
        Summary("Schedule \($task) for \($date) at \($priority) priority") {
            if $addReminder {
                Section("Reminder") {
                    $addReminder
                }
            }
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        task.dueDate = date
        task.priority = priority

        if addReminder {
            try await NotificationManager.shared.scheduleReminder(
                for: task,
                at: date
            )
        }

        try await TaskManager.shared.save(task)
        return .result(dialog: IntentDialog("Task scheduled"))
    }
}
```

---

## App Shortcuts & Discoverability

### Registering Shortcuts with AppShortcutsProvider

Make intents discoverable via Siri and Shortcuts app:

```swift
struct TaskManagerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateTaskIntent(),
            phrases: [
                "Create a task",
                "Add a task in \(.applicationName)",
                "New task in \(.applicationName)",
                "Make a new task"
            ],
            shortTitle: "Create Task",
            systemImageName: "plus.circle"
        )

        AppShortcut(
            intent: TaskListIntent(),
            phrases: [
                "Show my tasks",
                "List tasks in \(.applicationName)",
                "What tasks do I have"
            ],
            shortTitle: "My Tasks",
            systemImageName: "list.bullet"
        )

        AppShortcut(
            intent: CompleteTaskIntent(),
            phrases: [
                "Mark \(.applicationName) task done",
                "Complete task in \(.applicationName)",
                "Finish my task"
            ],
            shortTitle: "Complete Task",
            systemImageName: "checkmark.circle.fill"
        )
    }
}

// Parameterized shortcut with entity injection
struct TaskManagerParameterizedShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AssignTaskIntent(),
            phrases: [
                "Assign \($task) to \($assignee)",
                "Give \($task) to \($assignee) in \(.applicationName)"
            ],
            shortTitle: "Assign Task",
            systemImageName: "person.badge.plus"
        )
    }
}
```

### Siri Tip View for In-App Discoverability

Educate users about available Siri commands:

```swift
import SwiftUI

struct TaskDetailView: View {
    @State var task: TaskEntity
    @State var showSiriTip = true

    var body: some View {
        VStack {
            Text(task.title).font(.title2)
            Text(task.description).font(.body)

            Button("Mark Complete") {
                Task {
                    task.isCompleted = true
                    try await TaskManager.shared.save(task)
                }
            }
        }
        .siriTipView(intent: CompleteTaskIntent())
    }
}

// Or using popoverTip for more granular control
#Preview {
    struct PreviewContainer: View {
        @State var task = TaskEntity(id: UUID(), title: "Sample", ...)

        var body: some View {
            TaskDetailView(task: task)
        }
    }

    return PreviewContainer()
}
```

---

## CoreML & On-Device Machine Learning

### Loading & Running CoreML Models

Efficient model inference with proper memory management:

```swift
import CoreML
import Vision

class MLModelManager {
    static let shared = MLModelManager()

    private var priorityClassifier: MLModel?
    private var taskSimilarityModel: MLModel?

    private init() {
        loadModels()
    }

    private func loadModels() {
        // Load with configuration for performance
        var config = MLModelConfiguration()
        config.preferredMetalDevice = MTLCreateSystemDefaultDevice()
        config.computeUnits = .cpuAndGPU

        do {
            if let modelURL = Bundle.main.url(
                forResource: "TaskPriorityClassifier",
                withExtension: "mlmodel"
            ) {
                let modelAsset = try MLModel.compileModel(at: modelURL)
                self.priorityClassifier = try MLModel(
                    contentsOf: modelAsset,
                    configuration: config
                )
            }
        } catch {
            print("Failed to load priority classifier: \(error)")
        }
    }

    // Async prediction with error handling
    func classifyTaskPriority(
        title: String,
        description: String,
        daysUntilDue: Int
    ) async throws -> TaskPriority {
        guard let model = priorityClassifier else {
            throw MLError.modelNotLoaded
        }

        // Prepare input
        let input = TaskPriorityClassifierInput(
            title: title,
            description: description,
            daysUntilDue: daysUntilDue as NSNumber
        )

        // Async prediction
        let output = try await model.prediction(from: input)

        guard let priority = TaskPriority(
            rawValue: output.priority
        ) else {
            throw MLError.invalidOutput
        }

        return priority
    }

    enum MLError: LocalizedError {
        case modelNotLoaded
        case invalidOutput
        case predictionFailed(String)
    }
}

// Usage in intent
struct SmartCreateTaskIntent: AppIntent {
    @Parameter(title: "Title") var title: String
    @Parameter(title: "Description") var description: String
    @Parameter(title: "Due In (days)") var daysUntilDue: Int = 7

    static let title: LocalizedStringResource = "Create Smart Task"

    @MainActor
    func perform() async throws -> some IntentResult {
        // Use ML to infer priority
        let priority = try await MLModelManager.shared.classifyTaskPriority(
            title: title,
            description: description,
            daysUntilDue: daysUntilDue
        )

        let task = TaskEntity(
            id: UUID(),
            title: title,
            description: description,
            priority: priority,
            isCompleted: false,
            dueDate: Calendar.current.date(
                byAdding: .day,
                value: daysUntilDue,
                to: Date()
            )
        )

        try await TaskManager.shared.save(task)

        return .result(
            value: task,
            dialog: IntentDialog(
                stringLiteral: "Created \(priority.rawValue) priority task"
            )
        )
    }
}
```

### Vision Framework Integration

Process images for task-related features (OCR, classification):

```swift
import Vision

class TaskVisionProcessor {
    static let shared = TaskVisionProcessor()

    // OCR: Extract text from images
    func extractText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            options: [:]
        )

        try handler.perform([request])

        guard let observations = request.results as? [VNRecognizedTextObservation]
        else {
            return ""
        }

        return observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: " ")
    }

    // Face detection for team member photos
    func detectFaces(in image: UIImage) async throws -> [CGRect] {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)

        try handler.perform([request])

        guard let observations = request.results as? [VNFaceObservation]
        else {
            return []
        }

        return observations.map { $0.boundingBox }
    }

    // Custom CoreML model for task image classification
    func classifyTaskImage(_ image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        guard let modelURL = Bundle.main.url(
            forResource: "TaskImageClassifier",
            withExtension: "mlmodel"
        ) else {
            throw VisionError.modelNotFound
        }

        let compiledModelURL = try MLModel.compileModel(at: modelURL)
        let model = try MLModel(contentsOf: compiledModelURL)

        let request = VNCoreMLRequest(model: model)
        let handler = VNImageRequestHandler(cgImage: cgImage)

        try handler.perform([request])

        guard let results = request.results as? [VNClassificationObservation],
              let topResult = results.first
        else {
            throw VisionError.classificationFailed
        }

        return topResult.identifier
    }

    enum VisionError: LocalizedError {
        case invalidImage
        case modelNotFound
        case classificationFailed

        var errorDescription: String? {
            switch self {
            case .invalidImage: return "Unable to process image"
            case .modelNotFound: return "ML model not found"
            case .classificationFailed: return "Image classification failed"
            }
        }
    }
}
```

### Natural Language Processing

Analyze task text for semantic understanding:

```swift
import NaturalLanguage

class TaskNLProcessor {
    static let shared = TaskNLProcessor()

    // Extract named entities (people, dates, locations)
    func extractEntities(from text: String) -> [String: [String]] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text

        var entities: [String: [String]] = [
            "person": [],
            "organization": [],
            "location": [],
            "date": []
        ]

        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation]
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .nameType,
            options: options
        ) { tag, tokenRange in
            if let tag = tag {
                let token = String(text[tokenRange])
                if let key = tag.rawValue as String? {
                    entities[key, default: []].append(token)
                }
            }
            return true
        }

        return entities
    }

    // Determine task sentiment (positive/negative/neutral)
    func analyzeSentiment(_ text: String) -> Double {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text

        let range = text.startIndex..<text.endIndex
        if let (_, range) = tagger.tag(
            at: range.lowerBound,
            unit: .paragraph,
            scheme: .sentimentScore,
            options: [.omitWhitespace]
        ) {
            if let tag = tagger.tag(
                at: range.lowerBound,
                unit: .paragraph,
                scheme: .sentimentScore,
                options: [.omitWhitespace]
            ).0
            {
                return Double(tag.rawValue) ?? 0.0
            }
        }

        return 0.0
    }

    // Language identification
    func detectLanguage(_ text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        guard let language = recognizer.dominantLanguage?.rawValue
        else {
            return "unknown"
        }

        return language
    }

    // Tokenization for search indexing
    func tokenizeForSearch(_ text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text

        var tokens: [String] = []
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation]

        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: options
        ) { tag, tokenRange in
            // Skip common words and particles
            if tag != .particle && tag != .pronoun {
                tokens.append(String(text[tokenRange]).lowercased())
            }
            return true
        }

        return tokens
    }
}
```

### Sound Classification

Add audio intelligence to task notifications or voice commands:

```swift
import SoundAnalysis
import AVFoundation

class TaskSoundAnalyzer: NSObject, SNResultsObserving {
    static let shared = TaskSoundAnalyzer()

    private var audioEngine: AVAudioEngine?
    private var soundClassificationRequest: SNClassifySoundRequest?

    override init() {
        super.init()
        setupAudioEngine()
    }

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setCategory(
                .record,
                mode: .default,
                options: .duckOthers
            )
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }

    // Classify ambient sound (detect meetings, noise levels)
    func startSoundClassification() async throws {
        guard let modelURL = Bundle.main.url(
            forResource: "TaskEnvironmentClassifier",
            withExtension: "mlmodel"
        ) else {
            throw SoundError.modelNotFound
        }

        let compiledURL = try MLModel.compileModel(at: modelURL)
        let coreMLModel = try MLModel(contentsOf: compiledURL)

        soundClassificationRequest = try SNClassifySoundRequest(mlModel: coreMLModel)

        guard let request = soundClassificationRequest else {
            throw SoundError.requestCreationFailed
        }

        request.resultsObserver = self

        let audioEngine = self.audioEngine ?? AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        do {
            let analyzer = try SNAudioFileAnalyzer(audioNode: inputNode)
            try analyzer.add(request)
            try analyzer.analyze()
        } catch {
            throw SoundError.analysisFailed(error.localizedDescription)
        }
    }

    // SNResultsObserving delegate
    func request(
        _ request: SNRequest,
        didProduce result: SNResult
    ) {
        guard let result = result as? SNClassificationResult else { return }

        for classification in result.classifications {
            let identifier = classification.identifier
            let confidence = classification.confidence

            // Take action based on detected sound
            if identifier == "meeting" && confidence > 0.8 {
                // Defer task notifications during meetings
                TaskManager.shared.shouldDeferNotifications = true
            } else if identifier == "silence" {
                // Re-enable notifications when meeting ends
                TaskManager.shared.shouldDeferNotifications = false
            }
        }
    }

    enum SoundError: LocalizedError {
        case modelNotFound
        case requestCreationFailed
        case analysisFailed(String)
    }
}
```

---

## Spotlight & Search Integration

### Core Spotlight Indexing

Make task data searchable via system-wide search:

```swift
import CoreSpotlight
import os

class TaskSpotlightManager {
    static let shared = TaskSpotlightManager()
    private let logger = Logger(subsystem: "com.taskmanager", category: "spotlight")

    func indexTask(_ task: TaskEntity) async throws {
        let attributeSet = CSSearchableItemAttributeSet(
            itemContentType: kUTTypeContent as String
        )

        // Basic attributes
        attributeSet.title = task.title
        attributeSet.contentDescription = task.description
        attributeSet.keywords = [task.priority.rawValue, "task"]

        // Rich metadata
        attributeSet.dueDate = task.dueDate
        attributeSet.rating = NSNumber(value: task.priority.sortOrder)

        // Custom attributes for contextual search
        attributeSet.setValue(task.isCompleted, forKey: "isCompleted")
        attributeSet.setValue(task.assignee?.name ?? "", forKey: "assigneeName")

        // For team context
        if let assignee = task.assignee {
            attributeSet.author = assignee.name
        }

        // Create searchable item
        let item = CSSearchableItem(
            uniqueIdentifier: task.id.uuidString,
            domainIdentifier: "com.taskmanager.tasks",
            attributeSet: attributeSet
        )

        do {
            try await CSSearchableIndex.default().indexSearchableItems([item])
            logger.info("Indexed task: \(task.title)")
        } catch {
            logger.error("Failed to index task: \(error.localizedDescription)")
            throw error
        }
    }

    func indexTasks(_ tasks: [TaskEntity]) async throws {
        let items = tasks.map { task -> CSSearchableItem in
            let attributeSet = CSSearchableItemAttributeSet(
                itemContentType: kUTTypeContent as String
            )

            attributeSet.title = task.title
            attributeSet.contentDescription = task.description
            attributeSet.dueDate = task.dueDate
            attributeSet.keywords = [task.priority.rawValue, "task"]

            return CSSearchableItem(
                uniqueIdentifier: task.id.uuidString,
                domainIdentifier: "com.taskmanager.tasks",
                attributeSet: attributeSet
            )
        }

        try await CSSearchableIndex.default().indexSearchableItems(items)
    }

    func updateTask(_ task: TaskEntity) async throws {
        try await indexTask(task)
    }

    func deleteTask(_ taskId: UUID) async throws {
        try await CSSearchableIndex.default()
            .deleteSearchableItems(withIdentifiers: [taskId.uuidString])
    }

    func deleteAllTasks() async throws {
        try await CSSearchableIndex.default()
            .deleteSearchableItems(withDomainIdentifiers: ["com.taskmanager.tasks"])
    }
}
```

### NSUserActivity for Search & Handoff

Enable task continuity across devices:

```swift
func createUserActivity(for task: TaskEntity) -> NSUserActivity {
    let activity = NSUserActivity(activityType: "com.taskmanager.view-task")

    activity.title = task.title
    activity.keywords = Set([task.title, task.priority.rawValue])
    activity.isEligibleForSearch = true
    activity.isEligibleForHandoff = true
    activity.isEligibleForPublicIndexing = false

    // User info for restoration
    activity.userInfo = [
        "taskId": task.id.uuidString,
        "title": task.title,
        "priority": task.priority.rawValue
    ]

    // For Spotlight
    let contentAttributeSet = CSSearchableItemAttributeSet(
        itemContentType: kUTTypeContent as String
    )
    contentAttributeSet.title = task.title
    contentAttributeSet.contentDescription = task.description
    contentAttributeSet.keywords = [task.priority.rawValue, "task"]

    activity.contentAttributeSet = contentAttributeSet

    return activity
}

// In SceneDelegate or WindowScene
func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
) {
    // Handle activity from search or handoff
    if let userActivity = connectionOptions.userActivities.first {
        handleUserActivity(userActivity)
    }
}

func handleUserActivity(_ activity: NSUserActivity) {
    guard activity.activityType == "com.taskmanager.view-task",
          let taskIdString = activity.userInfo?["taskId"] as? String,
          let taskId = UUID(uuidString: taskIdString)
    else {
        return
    }

    Task {
        if let task = try? await TaskManager.shared.fetch(id: taskId) {
            // Navigate to task detail
            navigateToTask(task)
        }
    }
}
```

---

## Error Handling & Privacy

### Intent Error Handling

Proper error communication for Siri:

```swift
struct SafeTaskIntent: AppIntent {
    @Parameter(title: "Task") var task: TaskEntity

    static let title: LocalizedStringResource = "Safe Task Operation"

    @MainActor
    func perform() async throws -> some IntentResult {
        do {
            // Attempt operation
            try await TaskManager.shared.save(task)
            return .result(dialog: IntentDialog("Task saved"))
        } catch TaskManager.Error.notAuthorized {
            throw IntentError.permissionDenied(
                "You don't have permission to modify this task"
            )
        } catch TaskManager.Error.taskNotFound {
            throw IntentError.notFound(
                "The task \(task.title) was not found"
            )
        } catch TaskManager.Error.networkError {
            throw IntentError.temporarilyUnavailable(
                "Can't reach the server. Try again in a moment."
            )
        } catch {
            throw IntentError.unknown("Task operation failed")
        }
    }
}

enum IntentError: LocalizedError {
    case permissionDenied(String)
    case notFound(String)
    case temporarilyUnavailable(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied(let msg),
             .notFound(let msg),
             .temporarilyUnavailable(let msg),
             .unknown(let msg):
            return msg
        }
    }
}
```

### Privacy: On-Device vs Cloud

Apple Intelligence processes data on-device by default. Document data flow:

```swift
// MARK: - Privacy & Data Flow Documentation

/**
 Data Processing Categories:

 ON-DEVICE PROCESSING (No server communication):
 - Priority classification via CoreML model
 - Text tokenization via NaturalLanguage framework
 - Entity extraction (NER) via NaturalLanguage
 - Sentiment analysis via NaturalLanguage
 - Sound classification via SoundAnalysis
 - Vision requests via Vision framework
 - All Create ML inference

 CLOUD PROCESSING (User data may be sent to servers):
 - Syncing tasks to iCloud (CloudKit)
 - Backup operations
 - Team collaboration features
 - Analytics (opt-in)

 USER CONTROLS:
 - Apple Intelligence toggle in Settings
 - On-Device Intelligence can be disabled per feature
 - CloudKit can be disabled entirely
 - Analytics opt-out available in app
 */

// Example: Privacy-respecting intent that avoids cloud calls
struct PrivateTaskAnalysisIntent: AppIntent {
    @Parameter(title: "Task") var task: TaskEntity

    static let title: LocalizedStringResource = "Analyze Task (Private)"

    @MainActor
    func perform() async throws -> some IntentResult {
        // All processing happens on-device
        let tokens = TaskNLProcessor.shared.tokenizeForSearch(task.title)
        let sentiment = TaskNLProcessor.shared.analyzeSentiment(task.description)
        let language = TaskNLProcessor.shared.detectLanguage(task.description)

        // Do NOT call cloud APIs here
        // Do NOT sync to server
        // Result stays local

        let analysis = TaskAnalysis(
            tokens: tokens,
            sentiment: sentiment,
            language: language
        )

        return .result(value: analysis)
    }
}
```

---

## Performance & Best Practices

### Model Loading Patterns

Efficient model management:

```swift
actor ModelCache {
    private var models: [String: MLModel] = [:]

    func model(named name: String) async throws -> MLModel {
        // Return cached model if available
        if let cached = models[name] {
            return cached
        }

        // Load and cache
        guard let url = Bundle.main.url(forResource: name, withExtension: "mlmodel")
        else {
            throw CacheError.modelNotFound(name)
        }

        let compiledURL = try MLModel.compileModel(at: url)
        let model = try MLModel(contentsOf: compiledURL)
        models[name] = model

        return model
    }

    func clearCache() {
        models.removeAll()
    }

    enum CacheError: LocalizedError {
        case modelNotFound(String)
    }
}

// Usage with structured concurrency
let modelCache = ModelCache()

func predictPriority(title: String) async throws -> TaskPriority {
    let model = try await modelCache.model(named: "TaskPriority")
    let input = TaskPriorityInput(title: title)
    let output = try await model.prediction(from: input)
    return TaskPriority(rawValue: output.priority) ?? .medium
}
```

### Prediction Latency Budgets

Keep Siri responsive:

```swift
// Timeout for predictions to ensure Siri doesn't hang
func predictWithTimeout<T>(
    timeout: TimeInterval = 1.0,
    operation: @escaping () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(
                nanoseconds: UInt64(timeout * 1_000_000_000)
            )
            throw LatencyError.timedOut
        }

        do {
            return try await group.next()!
        } catch {
            group.cancelAll()
            throw error
        }
    }
}

enum LatencyError: LocalizedError {
    case timedOut

    var errorDescription: String? {
        "Operation took too long"
    }
}

// Usage in intent
struct FastTaskIntent: AppIntent {
    @Parameter(title: "Title") var title: String

    @MainActor
    func perform() async throws -> some IntentResult {
        // Predict priority but timeout after 500ms
        let priority = try await predictWithTimeout(timeout: 0.5) {
            try await MLModelManager.shared.classifyTaskPriority(
                title: title,
                description: "",
                daysUntilDue: 7
            )
        }

        return .result(dialog: IntentDialog("Priority: \(priority.rawValue)"))
    }
}
```

### Testing Intents

Verify behavior without running full app:

```swift
import XCTest
import AppIntents

class TaskIntentTests: XCTestCase {
    func testCreateTaskIntent() async throws {
        let intent = CreateTaskIntent()
        intent.title = "Test Task"
        intent.priority = .high

        let result = try await intent.perform()

        XCTAssertNotNil(result)
    }

    func testEntityQuery() async throws {
        let query = TaskEntityQuery()
        let entities = try await query.entities(matching: "urgent")

        XCTAssertGreaterThan(entities.count, 0)
    }

    func testMLModelPerformance() async throws {
        let start = Date()

        _ = try await MLModelManager.shared.classifyTaskPriority(
            title: "Sample task",
            description: "Description",
            daysUntilDue: 7
        )

        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 1.0, "Prediction should complete within 1 second")
    }
}
```

---

## Summary

- **App Intents** enable semantic understanding; design for discoverability
- **Entities** make app data queryable by Apple Intelligence
- **CoreML** runs inference on-device; cache models for performance
- **Vision & NL frameworks** add intelligence without cloud calls
- **Spotlight** indexes searchable content; use NSUserActivity for handoff
- **Error handling** must be precise for Siri UX; privacy defaults to on-device

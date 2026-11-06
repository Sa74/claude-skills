# visionOS & Spatial Computing Reference
## Principal Apple Engineer Skill

---

## 1. Scene Architecture & Window Management

### Scene Types and Immersion Levels

visionOS supports distinct scene paradigms. Choose based on spatial requirements:

```swift
// WindowGroup: Standard 2D windows in shared space
// Users see other apps alongside yours, minimal immersion
#Preview {
    WindowGroup {
        ContentView()
    }
}

// Volumetric window: 3D content in shared space
// Coexists with other apps; no full immersion
#Preview {
    WindowGroup(id: "editor") {
        ModelEditorView()
    }
    .windowStyle(.volumetric)
}

// ImmersiveSpace: Fully immersive or mixed
#Preview {
    ImmersiveSpace(id: "gallery") {
        ImmersiveGalleryView()
    }
    .immersionStyle(selection: .constant(.mixed), in: .mixed)
}
```

### Scene Coordination and Opening Immersive Spaces

Multiple scenes require careful orchestration. Only one immersive space can be active at a time.

```swift
struct SpatialApp: App {
    @State private var immersiveSpaceIsShown = false
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Programmatically open immersive space
                    Task {
                        await openImmersiveSpace(id: "exploration")
                        immersiveSpaceIsShown = true
                    }
                }
        }

        ImmersiveSpace(id: "exploration") {
            ExplorationView()
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed, .progressive, .full)
    }
}
```

### Immersion Styles Deep Dive

```swift
// .mixed: user sees real world + app
// Most accessible, best for collaboration

// .progressive: gradual transition; system manages
// Intermediate immersion level

// .full: complete environmental replacement
// Maximum immersion; requires Full Space entitlement

struct ImmersiveEnvironmentView: View {
    @State private var immersionLevel: ImmersionStyle = .mixed
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace

    var body: some View {
        VStack {
            Picker("Immersion", selection: $immersionLevel) {
                Text("Mixed").tag(ImmersionStyle.mixed)
                Text("Progressive").tag(ImmersionStyle.progressive)
                Text("Full").tag(ImmersionStyle.full)
            }

            Button("Enter Space") {
                Task {
                    await openImmersiveSpace(id: "immersive")
                }
            }

            Button("Exit") {
                Task {
                    await dismissImmersiveSpace()
                }
            }
        }
    }
}
```

---

## 2. RealityKit Fundamentals

### RealityView and Entity Architecture

RealityView is the canvas for 3D content. Entities form a hierarchical component-based system.

```swift
import RealityKit

struct SpatialModelView: View {
    var body: some View {
        RealityView { content in
            // Create root anchor (origin point in space)
            let anchor = AnchorEntity(plane: .horizontal)

            // Create a 3D model entity
            let modelEntity = ModelEntity(
                mesh: .generateBox(size: [0.2, 0.2, 0.2]),
                materials: [SimpleMaterial(color: .blue, isMetallic: false)]
            )
            modelEntity.position = [0, 0.1, -0.5]

            // Add to hierarchy
            anchor.addChild(modelEntity)
            content.add(anchor)
        } update: { content in
            // Called when SwiftUI state changes
            if let modelEntity = content.entities.first?.children.first as? ModelEntity {
                var transform = modelEntity.transform
                transform.translation.y += 0.01
                modelEntity.move(to: transform, relativeTo: modelEntity.parent, duration: 0.1, timingFunction: .linear)
            }
        }
        .gesture(
            SpatialTapGesture()
                .onEnded { value in
                    print("Tapped at: \(value.location3D)")
                }
        )
    }
}
```

### Loading USDZ Assets and Reality Composer Pro Integration

```swift
struct ModelLoaderView: View {
    @State private var loadedModel: ModelEntity?

    var body: some View {
        RealityView { content in
            let anchor = AnchorEntity(world: [0, 0, -1])

            // Load USDZ from bundle
            if let model = try? await ModelEntity(
                named: "chair",
                in: realityKitContentBundle
            ) {
                model.position = [0, 0, 0]
                anchor.addChild(model)
                content.add(anchor)
            }
        }
    }
}

// Reality Composer Pro generated scene
struct RCProScene: View {
    var body: some View {
        RealityView { content in
            // Load Reality Composer Pro scene
            if let scene = try? await Entity(named: "Scene", in: realityKitContentBundle) {
                content.add(scene)
            }
        }
    }
}
```

### Materials and Visual Properties

```swift
import RealityKit

func createMaterialShowcase() -> ModelEntity {
    let box = ModelEntity(
        mesh: .generateBox(size: [0.3, 0.3, 0.3]),
        materials: [createPBRMaterial()]
    )
    return box
}

// Physically-Based Rendering Material
func createPBRMaterial() -> Material {
    var material = PhysicallyBasedMaterial()
    material.color = .init(tint: .blue)
    material.roughness = .init(floatValue: 0.4)
    material.metallic = .init(floatValue: 1.0)
    material.normal = .init(texture: .init(try! TextureResource.load(named: "normal")))

    return material
}

// Simple material for UI elements
func createSimpleMaterial() -> Material {
    return SimpleMaterial(
        color: .init(tint: .cyan),
        isMetallic: false
    )
}

// Glass-like material for depth
func createGlassMaterial() -> Material {
    var material = PhysicallyBasedMaterial()
    material.color = .init(tint: .white.withAlphaComponent(0.1))
    material.roughness = .init(floatValue: 0.1)
    material.metallic = .init(floatValue: 0.0)
    return material
}
```

### Animation in RealityKit

```swift
struct AnimationView: View {
    @State private var isAnimating = false

    var body: some View {
        RealityView { content in
            let anchor = AnchorEntity(world: [0, 0, -1])
            let box = ModelEntity(
                mesh: .generateBox(size: [0.2, 0.2, 0.2]),
                materials: [SimpleMaterial(color: .yellow, isMetallic: false)]
            )
            anchor.addChild(box)
            content.add(anchor)
        } update: { content in
            guard let anchor = content.entities.first as? AnchorEntity,
                  let box = anchor.children.first as? ModelEntity else { return }

            if isAnimating {
                // Orbit animation
                var transform = box.transform
                let angle = Float.random(in: 0..<(2 * .pi))
                transform.translation.x = sin(angle) * 0.5
                transform.translation.z = cos(angle) * 0.5

                box.move(to: transform, relativeTo: box.parent, duration: 2.0, timingFunction: .linear)
            }
        }
        .onAppear { isAnimating = true }
    }
}

// Skeletal animation from USDZ
struct SkeletalAnimationView: View {
    var body: some View {
        RealityView { content in
            if let model = try? await ModelEntity(named: "character", in: realityKitContentBundle) {
                // Get all animation clips
                var animationPlaybackController = model.move(
                    to: model.transform,
                    relativeTo: model.parent,
                    duration: 2.0,
                    timingFunction: .linear
                )

                if var animation = try? await AnimationPlaybackController(
                    named: "walk",
                    animations: model.availableAnimations
                ) {
                    animation.speed = 1.0
                    animation.play()
                }

                let anchor = AnchorEntity(world: [0, 0, -1])
                anchor.addChild(model)
                content.add(anchor)
            }
        }
    }
}
```

### Physics Simulation

```swift
struct PhysicsView: View {
    var body: some View {
        RealityView { content in
            let anchor = AnchorEntity(world: [0, 0, -0.5])

            // Create a rigid body
            var box = ModelEntity(
                mesh: .generateBox(size: [0.1, 0.1, 0.1]),
                materials: [SimpleMaterial(color: .red, isMetallic: false)]
            )
            box.position.y = 0.5

            // Add physics components
            var physicsBody = PhysicsBodyComponent(
                massProperties: .default,
                material: nil,
                linearVelocity: [0, -0.5, 0],
                angularVelocity: [0, 0, 0]
            )
            box.components[PhysicsBodyComponent.self] = physicsBody

            // Collision component
            box.components[CollisionComponent.self] = CollisionComponent(
                shapes: [.generateBox(size: [0.1, 0.1, 0.1])],
                isSimulationEnabled: true,
                isSceneUnderstandingEnabled: false
            )

            // Ground plane
            var ground = ModelEntity(
                mesh: .generatePlane(width: 2, height: 2),
                materials: [SimpleMaterial(color: .gray, isMetallic: false)]
            )
            ground.position.y = -0.5
            var groundPhysics = PhysicsBodyComponent(
                massProperties: .init(mass: .infinity),
                material: nil,
                linearVelocity: .zero,
                angularVelocity: .zero
            )
            ground.components[PhysicsBodyComponent.self] = groundPhysics
            ground.components[CollisionComponent.self] = CollisionComponent(
                shapes: [.generatePlane(width: 2, height: 2)],
                isSimulationEnabled: false,
                isSceneUnderstandingEnabled: false
            )

            // Add simulation
            anchor.components[PhysicsSimulationComponent.self] = PhysicsSimulationComponent()

            anchor.addChild(box)
            anchor.addChild(ground)
            content.add(anchor)
        }
    }
}
```

### Spatial Audio

```swift
struct SpatialAudioView: View {
    var body: some View {
        RealityView { content in
            let anchor = AnchorEntity(world: [0, 0, -1])

            let sphere = ModelEntity(
                mesh: .generateSphere(radius: 0.1),
                materials: [SimpleMaterial(color: .green, isMetallic: false)]
            )

            // Add spatial audio component
            var audioComponent = SpatialAudioComponent(
                audioFileResource: try! AudioFileResource.load(
                    named: "notification",
                    in: realityKitContentBundle,
                    inputMode: .spatial
                )
            )
            audioComponent.spatializationMode = .automatic
            sphere.components[SpatialAudioComponent.self] = audioComponent

            // Ambient audio (no specific source location)
            var ambientAudio = AmbientAudioComponent(
                audioFileResource: try! AudioFileResource.load(
                    named: "ambient",
                    in: realityKitContentBundle,
                    inputMode: .nonSpatial
                )
            )
            ambientAudio.volume = 0.5
            sphere.components[AmbientAudioComponent.self] = ambientAudio

            anchor.addChild(sphere)
            content.add(anchor)
        }
    }
}
```

---

## 3. Gesture and Interaction

### Spatial Tap Gestures

```swift
struct InteractiveModelView: View {
    @State private var selectedEntity: ModelEntity?

    var body: some View {
        RealityView { content in
            let anchor = AnchorEntity(plane: .horizontal)

            for i in 0..<3 {
                let model = ModelEntity(
                    mesh: .generateBox(size: [0.15, 0.15, 0.15]),
                    materials: [SimpleMaterial(color: .blue, isMetallic: false)]
                )
                model.position.x = Float(i - 1) * 0.3
                model.position.y = 0.1
                model.id = "model_\(i)"
                anchor.addChild(model)
            }

            content.add(anchor)
        }
        .gesture(
            SpatialTapGesture()
                .onEnded { value in
                    // value.location3D: position in world space
                    // value.entity: tapped entity
                    print("Tapped entity: \(value.entity?.id ?? "none")")
                    print("World position: \(value.location3D)")
                }
        )
    }
}
```

### 3D Drag Gestures

```swift
struct DraggableModelView: View {
    @State private var draggedEntity: ModelEntity?
    @State private var dragOffset: SIMD3<Float> = .zero

    var body: some View {
        RealityView { content in
            let anchor = AnchorEntity(world: [0, 0, -1])

            let box = ModelEntity(
                mesh: .generateBox(size: [0.2, 0.2, 0.2]),
                materials: [SimpleMaterial(color: .orange, isMetallic: false)]
            )
            box.id = "draggable"
            anchor.addChild(box)
            content.add(anchor)
        } update: { content in
            if let dragged = draggedEntity {
                dragged.position += dragOffset
                dragOffset = .zero
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Get RealityView content
                    if let entity = content.entities
                        .flatMap { $0.children }
                        .first(where: { $0.id == "draggable" }) as? ModelEntity {

                        draggedEntity = entity
                        // Convert 2D drag to 3D movement
                        dragOffset.x = Float(value.translation.width) * 0.001
                        dragOffset.y = -Float(value.translation.height) * 0.001
                    }
                }
                .onEnded { _ in
                    draggedEntity = nil
                }
        )
    }
}

// Advanced: convert 2D gesture to 3D transform
struct AdvancedDragView: View {
    @State private var boxTransform: Transform = Transform(
        translation: [0, 0, -1],
        rotation: simd_quatf()
    )

    var body: some View {
        RealityView { content in
            let anchor = AnchorEntity(world: [0, 0, 0])

            var box = ModelEntity(
                mesh: .generateBox(size: [0.2, 0.2, 0.2]),
                materials: [SimpleMaterial(color: .purple, isMetallic: false)]
            )
            box.move(to: boxTransform, relativeTo: anchor, duration: 0, timingFunction: .linear)
            anchor.addChild(box)
            content.add(anchor)
        } update: { content in
            if let box = content.entities.first?.children.first as? ModelEntity {
                box.move(to: boxTransform, relativeTo: box.parent, duration: 0.1, timingFunction: .easeInOut)
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    boxTransform.translation.x = Float(value.translation.width) * 0.001
                    boxTransform.translation.y = -Float(value.translation.height) * 0.001
                }
        )
    }
}
```

### Rotate and Magnify Gestures

```swift
struct RotateAndScaleView: View {
    @State private var scale: Float = 1.0
    @State private var rotation: simd_quatf = simd_quatf()

    var body: some View {
        RealityView { content in
            let anchor = AnchorEntity(world: [0, 0, -1])
            let sphere = ModelEntity(
                mesh: .generateSphere(radius: 0.2),
                materials: [SimpleMaterial(color: .cyan, isMetallic: true)]
            )
            anchor.addChild(sphere)
            content.add(anchor)
        } update: { content in
            guard let anchor = content.entities.first as? AnchorEntity,
                  let sphere = anchor.children.first as? ModelEntity else { return }

            var transform = sphere.transform
            transform.scale = [scale, scale, scale]
            transform.translation = [0, 0, -1]
            sphere.move(to: transform, relativeTo: anchor, duration: 0, timingFunction: .linear)
        }
        .gesture(
            RotateGesture3D()
                .onChanged { value in
                    rotation = value.rotation
                }
        )
        .gesture(
            MagnifyGesture()
                .onChanged { value in
                    scale = Float(value.magnification)
                }
        )
    }
}
```

### Hover Effects

```swift
struct HoveredEntity: View {
    var body: some View {
        RealityView { content in
            let anchor = AnchorEntity(world: [0, 0, -1])

            var box = ModelEntity(
                mesh: .generateBox(size: [0.2, 0.2, 0.2]),
                materials: [SimpleMaterial(color: .blue, isMetallic: false)]
            )

            // Add hover effect
            box.components[HoverEffectComponent.self] = HoverEffectComponent()

            anchor.addChild(box)
            content.add(anchor)
        }
    }
}
```

---

## 4. Hand Tracking and World Tracking (ARKit)

### Hand Skeleton Access

```swift
import ARKit

struct HandTrackingView: View {
    @State private var handTrackingProvider = HandTrackingProvider()
    @State private var latestHandAnchor: HandAnchor?

    var body: some View {
        RealityView { content in
            let anchor = AnchorEntity(world: [0, 0, -1])
            content.add(anchor)
        }
        .task {
            // Start hand tracking
            do {
                try await handTrackingProvider.requestHandTrackingAuthorization()

                let session = ARKitSession()
                try await session.run([handTrackingProvider])

                // Stream hand anchors
                for await update in handTrackingProvider.anchorUpdates {
                    switch update.event {
                    case .added, .updated:
                        latestHandAnchor = update.anchor

                        // Access hand skeleton
                        let handSkeleton = update.anchor.skeleton

                        // Joint positions in meters
                        if let thumbTipJoint = handSkeleton.joint(.thumbTip) {
                            let position = thumbTipJoint.position
                            print("Thumb tip at: \(position)")
                        }

                        // Useful joints
                        let palmJoint = handSkeleton.joint(.palm)
                        let indexTipJoint = handSkeleton.joint(.indexFingerTip)

                    case .removed:
                        latestHandAnchor = nil
                    }
                }
            } catch {
                print("Hand tracking error: \(error)")
            }
        }
    }
}
```

### Plane Detection and Scene Understanding

```swift
import ARKit

struct PlaneDetectionView: View {
    @State private var planeProvider = PlaneDetectionProvider()
    @State private var detectedPlanes: [PlaneAnchor] = []

    var body: some View {
        RealityView { content in
            let rootAnchor = AnchorEntity(world: [0, 0, 0])
            content.add(rootAnchor)
        } update: { content in
            // Update planes in view
            for plane in detectedPlanes {
                if !content.entities.contains(where: { $0.id == plane.id }) {
                    var planeModel = ModelEntity(
                        mesh: .generatePlane(width: plane.extent.x, height: plane.extent.z),
                        materials: [SimpleMaterial(color: .cyan.withAlphaComponent(0.3), isMetallic: false)]
                    )
                    planeModel.move(to: plane.transform, relativeTo: nil, duration: 0, timingFunction: .linear)
                    content.add(planeModel)
                }
            }
        }
        .task {
            do {
                let session = ARKitSession()
                try await session.run([planeProvider])

                for await update in planeProvider.anchorUpdates {
                    switch update.event {
                    case .added, .updated:
                        if let index = detectedPlanes.firstIndex(where: { $0.id == update.anchor.id }) {
                            detectedPlanes[index] = update.anchor
                        } else {
                            detectedPlanes.append(update.anchor)
                        }

                        // Access plane properties
                        print("Plane classification: \(update.anchor.classification)")
                        print("Plane extent: \(update.anchor.extent)")

                    case .removed:
                        detectedPlanes.removeAll { $0.id == update.anchor.id }
                    }
                }
            } catch {
                print("Plane detection error: \(error)")
            }
        }
    }
}

// Scene understanding: room geometry
struct MeshAnchorView: View {
    @State private var meshProvider = MeshAnchorProvider()
    @State private var sceneMeshes: [MeshAnchor] = []

    var body: some View {
        RealityView { content in
            let root = AnchorEntity(world: [0, 0, 0])
            content.add(root)
        }
        .task {
            do {
                let session = ARKitSession()
                try await session.run([meshProvider])

                for await update in meshProvider.anchorUpdates {
                    switch update.event {
                    case .added, .updated:
                        let mesh = update.anchor

                        // Create ModelEntity from mesh geometry
                        var geometry = MeshResource()
                        var material = SimpleMaterial(color: .white, isMetallic: false)

                        if let modelEntity = try? ModelEntity(
                            mesh: geometry,
                            materials: [material]
                        ) {
                            modelEntity.move(to: mesh.transform, relativeTo: nil, duration: 0, timingFunction: .linear)
                            // Add to content
                        }

                    case .removed:
                        break
                    }
                }
            } catch {
                print("Mesh anchor error: \(error)")
            }
        }
    }
}
```

### Image Tracking

```swift
import ARKit

struct ImageTrackingView: View {
    @State private var imageProvider = ImageTrackingProvider()

    var body: some View {
        RealityView { content in
            let root = AnchorEntity(world: [0, 0, 0])
            content.add(root)
        }
        .task {
            do {
                // Create tracking images from bundle
                let trackingImages = try loadTrackingImages()

                let imageProvider = ImageTrackingProvider(referenceImages: trackingImages)
                let session = ARKitSession()
                try await session.run([imageProvider])

                for await update in imageProvider.anchorUpdates {
                    switch update.event {
                    case .added, .updated:
                        let imageAnchor = update.anchor
                        print("Detected image: \(imageAnchor.referenceImage.name ?? "unknown")")
                        print("Position: \(imageAnchor.transform.translation)")

                    case .removed:
                        break
                    }
                }
            } catch {
                print("Image tracking error: \(error)")
            }
        }
    }

    private func loadTrackingImages() throws -> Set<ARReferenceImage> {
        var images = Set<ARReferenceImage>()

        if let image = UIImage(named: "target") {
            if let referenceImage = ARReferenceImage(image, orientation: .up, name: "target") {
                images.insert(referenceImage)
            }
        }

        return images
    }
}
```

---

## 5. SharePlay and Collaboration

### SharePlay with Spatial Personas

```swift
import GroupActivities

struct CollaborativeModelView: View {
    @State private var isSharePlayActive = false
    @State private var groupSession: GroupSession<ModelEditingActivity>?
    @State private var messenger: GroupActivityMessenger?

    var body: some View {
        RealityView { content in
            let anchor = AnchorEntity(world: [0, 0, -1])

            let sharedModel = ModelEntity(
                mesh: .generateBox(size: [0.2, 0.2, 0.2]),
                materials: [SimpleMaterial(color: .blue, isMetallic: false)]
            )
            sharedModel.id = "shared-model"
            anchor.addChild(sharedModel)
            content.add(anchor)
        } update: { content in
            if let model = content.entities.first?.children.first as? ModelEntity {
                // Update from messenger
                Task {
                    for await message in messenger?.messages(of: ModelTransformMessage.self) ?? .init() {
                        model.move(to: message.transform, relativeTo: model.parent, duration: 0.2, timingFunction: .linear)
                    }
                }
            }
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
            Task {
                if let session = try await ModelEditingActivity.prepareForActivation() {
                    self.groupSession = session
                    self.isSharePlayActive = true

                    Task {
                        for await session in ModelEditingActivity.sessions() {
                            self.groupSession = session

                            let messenger = GroupActivityMessenger()
                            self.messenger = messenger
                        }
                    }
                }
            }
        }
    }
}

// Define the activity
struct ModelEditingActivity: GroupActivity {
    static let activityIdentifier = "com.example.model-editing"

    var metadata: GroupActivityMetadata {
        var metadata = GroupActivityMetadata()
        metadata.title = "Edit Model Together"
        metadata.subtitle = "Collaborative 3D Editing"
        return metadata
    }
}

struct ModelTransformMessage: Codable {
    let transform: Transform
    let modelId: String
}
```

### Spatial Persona Positioning

```swift
import GroupActivities

struct SpatialPersonaView: View {
    @State private var groupSession: GroupSession<SharedActivity>?
    @State private var participants: [Participant] = []

    var body: some View {
        RealityView { content in
            let root = AnchorEntity(world: [0, 0, 0])

            // Create spatial persona anchors
            for participant in participants {
                let personaAnchor = AnchorEntity(
                    world: simd_make_float3(
                        Float.random(in: -1...1),
                        0.5,
                        Float.random(in: -2...0)
                    )
                )
                personaAnchor.id = participant.id
                root.addChild(personaAnchor)
            }

            content.add(root)
        } update: { content in
            for (index, participant) in participants.enumerated() {
                if let anchor = content.entities.first?.children[index] as? AnchorEntity {
                    // Position updates would come from group coordinator
                    var position = anchor.position
                    position.x = Float(index) * 0.5
                    anchor.position = position
                }
            }
        }
        .task {
            for await session in SharedActivity.sessions() {
                self.groupSession = session

                for await update in session.$participants {
                    participants = Array(update)
                }
            }
        }
    }
}

struct SharedActivity: GroupActivity {
    static let activityIdentifier = "com.example.shared-space"
    var metadata: GroupActivityMetadata {
        var m = GroupActivityMetadata()
        m.title = "Shared Space"
        return m
    }
}
```

---

## 6. Ornaments and UI Attachments

### Ornament Pattern

```swift
struct OrnamentedWindowView: View {
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            VStack {
                Text("3D Model Viewer")
                    .font(.title)

                RealityView { content in
                    let anchor = AnchorEntity(plane: .horizontal)
                    let model = ModelEntity(
                        mesh: .generateSphere(radius: 0.2),
                        materials: [SimpleMaterial(color: .blue, isMetallic: true)]
                    )
                    anchor.addChild(model)
                    content.add(anchor)
                }
            }
            .ornament(attachmentAnchor: .scene(.topTrailing)) {
                VStack {
                    Button(action: { showSettings.toggle() }) {
                        Image(systemName: "gear")
                    }

                    if showSettings {
                        VStack {
                            Toggle("Show Grid", isOn: .constant(true))
                            Slider(value: .constant(0.5), in: 0...1)
                        }
                        .padding()
                        .background(.regularMaterial)
                    }
                }
            }
        }
    }
}
```

### ViewAttachmentEntity for 3D Labels

```swift
struct LabeledModelView: View {
    var body: some View {
        RealityView { content in
            let anchor = AnchorEntity(world: [0, 0, -1])

            let box = ModelEntity(
                mesh: .generateBox(size: [0.2, 0.2, 0.2]),
                materials: [SimpleMaterial(color: .orange, isMetallic: false)]
            )
            box.id = "labeled-box"
            anchor.addChild(box)

            content.add(anchor)
        } attachments: {
            // SwiftUI view attached to 3D entity
            Attachment(id: "label") {
                VStack(spacing: 0) {
                    Text("Interactive Box")
                        .font(.headline)
                        .padding(8)
                        .background(.thinMaterial)
                        .cornerRadius(4)
                }
            }
        } update: { content, attachments in
            if let box = content.entities.first?.children.first as? ModelEntity,
               let labelView = attachments.first(where: { $0.id == "label" }) {

                let attachment = ViewAttachmentEntity(view: labelView)
                attachment.position.y = box.model?.bounds.max.y ?? 0.2

                box.addChild(attachment)
            }
        }
    }
}
```

---

## 7. Design Principles and Spatial Ergonomics

### Scale and Distance Guidelines

```swift
struct ProperScalingView: View {
    var body: some View {
        RealityView { content in
            let anchor = AnchorEntity(world: [0, 0, 0])

            // Comfortable viewing distance: 1-3 meters
            // Positions measured in meters (visionOS standard unit)

            // Item at 1.5 meters (very comfortable)
            let closeModel = ModelEntity(
                mesh: .generateBox(size: [0.2, 0.2, 0.2]),
                materials: [SimpleMaterial(color: .blue, isMetallic: false)]
            )
            closeModel.position = [0, 1.5, -1.5]
            anchor.addChild(closeModel)

            // Item at 2.5 meters (further but still good)
            let farModel = ModelEntity(
                mesh: .generateBox(size: [0.2, 0.2, 0.2]),
                materials: [SimpleMaterial(color: .green, isMetallic: false)]
            )
            farModel.position = [0, 1.5, -2.5]
            anchor.addChild(farModel)

            // Avoid content below waist (y < 0.5) or above head (y > 2.0)

            content.add(anchor)
        }
    }
}

// Window sizing
struct WindowSizingView: View {
    var body: some View {
        VStack {
            Text("Optimal window width: 0.5-0.8 meters")
            Text("Height: 0.4-0.6 meters")
            Text("Place at eye level, 1-3 meters away")
        }
        .frame(width: 700, height: 500)
    }
}
```

### Material and Depth Perception

```swift
struct DepthMaterialView: View {
    var body: some View {
        RealityView { content in
            let anchor = AnchorEntity(world: [0, 0, 0])

            // Background with depth cue: use glass material
            var background = ModelEntity(
                mesh: .generateBox(size: [1, 1, 0.01]),
                materials: [createGlassMaterial()]
            )
            background.position.z = -2
            anchor.addChild(background)

            // Foreground: solid material
            let foreground = ModelEntity(
                mesh: .generateSphere(radius: 0.2),
                materials: [
                    PhysicallyBasedMaterial()
                ]
            )
            foreground.position.z = -1
            anchor.addChild(foreground)

            content.add(anchor)
        }
    }
}

func createGlassMaterial() -> Material {
    var material = PhysicallyBasedMaterial()
    material.color = .init(tint: .white.withAlphaComponent(0.1))
    material.roughness = .init(floatValue: 0.1)
    material.metallic = .init(floatValue: 0.0)
    return material
}
```

### Typography for Spatial Content

```swift
struct SpatialTypographyView: View {
    var body: some View {
        VStack(spacing: 32) {
            // Minimum readable size at 1.5m: roughly 12pt
            Text("Body text (12pt minimum)")
                .font(.system(size: 12))

            // Headlines: larger
            Text("Headline (24pt+)")
                .font(.system(size: 24, weight: .bold))

            // Interactive labels: 14-18pt
            Text("Button label")
                .font(.system(size: 16))
        }
        .frame(width: 700, height: 500)
        .padding()
    }
}
```

---

## 8. Performance Optimization

### Render Budget and Entity Management

```swift
struct PerformanceOptimizedView: View {
    @State private var entityCount = 0
    @State private var fps: Double = 90

    var body: some View {
        RealityView { content in
            let anchor = AnchorEntity(world: [0, 0, 0])

            // visionOS target: 90 fps stereo (both eyes)
            // Budget: typically 1000-2000 visible entities

            // Efficient: many small simple entities
            for i in 0..<100 {
                let model = ModelEntity(
                    mesh: .generateBox(size: [0.05, 0.05, 0.05]),
                    materials: [SimpleMaterial(color: .blue, isMetallic: false)]
                )
                model.position = [
                    Float(i % 10) * 0.1 - 0.5,
                    Float(i / 10) * 0.1,
                    -1
                ]
                anchor.addChild(model)
            }

            content.add(anchor)
        } update: { content in
            entityCount = content.entities.flatMap { $0.children }.count
        }
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            // Monitor performance
            print("Entity count: \(entityCount)")
        }
    }
}

// Texture memory management
struct TextureOptimizationView: View {
    var body: some View {
        RealityView { content in
            let anchor = AnchorEntity(world: [0, 0, 0])

            // Load high-res texture only when needed
            Task {
                if let texture = try? await TextureResource.load(
                    named: "high-res-texture",
                    in: realityKitContentBundle
                ) {
                    // Use texture efficiently
                    var material = PhysicallyBasedMaterial()
                    // Assign to model
                }
            }

            content.add(anchor)
        }
    }
}

// Culling and level-of-detail
struct LODView: View {
    @State private var cameraDistance: Float = 1.5

    var body: some View {
        RealityView { content in
            let anchor = AnchorEntity(world: [0, 0, -1.5])

            // LOD: simple mesh at distance, complex mesh nearby
            let mesh = cameraDistance < 1.0 ?
                MeshResource.generateBox(size: [0.2, 0.2, 0.2]) :
                MeshResource.generateBox(size: [0.2, 0.2, 0.2])

            let model = ModelEntity(
                mesh: mesh,
                materials: [SimpleMaterial(color: .blue, isMetallic: false)]
            )
            anchor.addChild(model)
            content.add(anchor)
        }
    }
}
```

### Compositor Services for Custom Metal

```swift
struct CompositorServicesView: View {
    var body: some View {
        RealityView { content in
            let anchor = AnchorEntity(world: [0, 0, 0])
            // For advanced custom rendering, use CompositorServices
            // Requires Metal knowledge and custom frame scheduling
            content.add(anchor)
        }
    }
}
```

---

## 9. Migration from iOS to visionOS

### Compatibility Mode vs Native Apps

```swift
// Compatibility: iOS app runs unchanged on visionOS
// Rendered in compatibility window, standard 2D appearance
struct iOSCompatibleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// Native visionOS: leverage spatial capabilities
struct VisionOSNativeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        ImmersiveSpace(id: "immersive") {
            ImmersiveView()
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
```

### Platform-Specific Adaptations

```swift
struct AdaptiveContentView: View {
    @Environment(\.horizontalSizeClass) var sizeClass

    var body: some View {
        #if os(visionOS)
        VisionOSLayout()
        #elseif os(iOS)
        iOSLayout()
        #else
        macOSLayout()
        #endif
    }
}

// Conditional modifiers
struct ConditionalView: View {
    var body: some View {
        VStack {
            Text("Adaptive Content")
        }
        #if os(visionOS)
        .frame(width: 700, height: 500)
        .ornament(attachmentAnchor: .scene(.bottom)) {
            Text("visionOS controls")
        }
        #else
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
    }
}
```

### Adding 3D to Existing 2D Apps

```swift
struct EnhancedApp: App {
    @State private var show3DContent = false

    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()

                if show3DContent {
                    RealityView { content in
                        let anchor = AnchorEntity(world: [0, 0, -1])
                        let model = ModelEntity(
                            mesh: .generateSphere(radius: 0.2),
                            materials: [SimpleMaterial(color: .cyan, isMetallic: false)]
                        )
                        anchor.addChild(model)
                        content.add(anchor)
                    }
                    .tabItem {
                        Label("3D View", systemImage: "cube")
                    }
                }
            }
        }

        ImmersiveSpace(id: "volumetric") {
            VolumesView()
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
```

---

## Quick Reference: Common Patterns

### Minimal 3D Scene
```swift
RealityView { content in
    let anchor = AnchorEntity(world: [0, 0, -1])
    let box = ModelEntity(
        mesh: .generateBox(size: [0.1, 0.1, 0.1]),
        materials: [SimpleMaterial(color: .blue, isMetallic: false)]
    )
    anchor.addChild(box)
    content.add(anchor)
}
```

### State-Driven Animation
```swift
RealityView { content in
    let anchor = AnchorEntity(world: [0, 0, -1])
    content.add(anchor)
} update: { content in
    if let anchor = content.entities.first as? AnchorEntity {
        // Update based on SwiftUI state
    }
}
```

### Gesture Handling
```swift
.gesture(
    SpatialTapGesture()
        .onEnded { value in
            print("Tapped: \(value.location3D)")
        }
)
```

---

## Key Takeaways

1. **Immersion Levels**: Choose between WindowGroup (2D), .volumetric (3D in shared space), and ImmersiveSpace (full control)
2. **Entity Component System**: RealityKit uses composition; attach components to ModelEntity
3. **Gestures**: SpatialTapGesture is primary; compose with DragGesture for 3D manipulation
4. **Performance**: 90 fps stereo target; 1000-2000 visible entities budget
5. **ARKit**: HandTrackingProvider, PlaneDetectionProvider, MeshAnchorProvider in full-space immersive
6. **Ergonomics**: 1-3 meter viewing distance, avoid below waist/above head, minimum 12pt text
7. **Migration**: Start with compatibility mode, add spatial features incrementally
8. **SharePlay**: GroupActivities framework for multi-user experiences with spatial personas

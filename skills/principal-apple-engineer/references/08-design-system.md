# Cross-Platform Apple Design System Architecture

Expert-level reference for building production-grade design systems across iOS, macOS, watchOS, and tvOS using SwiftUI.

## Design Token Architecture

### Color Tokens

A semantic, adaptive color system that responds to user preferences and platform capabilities.

```swift
enum DesignTokens {
    enum Color {
        // MARK: - Semantic Colors

        static var primary: SwiftUI.Color {
            #if os(iOS)
            return SwiftUI.Color(
                light: .init(red: 0.0, green: 0.478, blue: 1.0),
                dark: .init(red: 0.04, green: 0.52, blue: 1.0)
            )
            #else
            return .accentColor
            #endif
        }

        static var secondary: SwiftUI.Color {
            SwiftUI.Color(
                light: .init(red: 0.5, green: 0.5, blue: 0.5),
                dark: .init(red: 0.6, green: 0.6, blue: 0.6)
            )
        }

        static var accent: SwiftUI.Color {
            .accentColor
        }

        static var destructive: SwiftUI.Color {
            SwiftUI.Color(
                light: .init(red: 1.0, green: 0.231, blue: 0.188),
                dark: .init(red: 1.0, green: 0.27, blue: 0.227)
            )
        }

        static var success: SwiftUI.Color {
            SwiftUI.Color(
                light: .init(red: 0.204, green: 0.782, blue: 0.349),
                dark: .init(red: 0.255, green: 0.835, blue: 0.404)
            )
        }

        static var warning: SwiftUI.Color {
            SwiftUI.Color(
                light: .init(red: 1.0, green: 0.584, blue: 0.0),
                dark: .init(red: 1.0, green: 0.604, blue: 0.016)
            )
        }

        static var surfaceBase: SwiftUI.Color {
            SwiftUI.Color(
                light: .init(white: 1.0),
                dark: .init(white: 0.11)
            )
        }

        static var surfaceElevated: SwiftUI.Color {
            SwiftUI.Color(
                light: .init(white: 0.97),
                dark: .init(white: 0.17)
            )
        }

        static var textPrimary: SwiftUI.Color {
            .primary
        }

        static var textSecondary: SwiftUI.Color {
            .secondary
        }

        static var divider: SwiftUI.Color {
            SwiftUI.Color(
                light: .init(white: 0.0, opacity: 0.1),
                dark: .init(white: 1.0, opacity: 0.1)
            )
        }

        // MARK: - High Contrast Support

        static func primaryWithAccessibilityContrast(
            contrastLevel: AccessibilityContrast
        ) -> SwiftUI.Color {
            switch contrastLevel {
            case .normal:
                return primary
            case .increased:
                return SwiftUI.Color(
                    light: .init(red: 0.0, green: 0.4, blue: 0.95),
                    dark: .init(red: 0.2, green: 0.6, blue: 1.0)
                )
            @unknown default:
                return primary
            }
        }
    }
}

// MARK: - View Modifier Extension for Appearance-Aware Colors

extension View {
    func semanticBackground(_ color: SwiftUI.Color = DesignTokens.Color.surfaceBase) -> some View {
        self.background(color)
    }

    func adaptiveOverlay() -> some View {
        self.background(.ultraThinMaterial)
    }
}
```

### Typography Tokens

Complete type scale with Dynamic Type support for all platforms.

```swift
extension DesignTokens {
    enum Typography {
        // MARK: - Type Scale Definitions

        static let largeTitle = FontToken(
            size: 34,
            weight: .regular,
            lineHeight: 41,
            tracking: 0.37
        )

        static let title1 = FontToken(
            size: 28,
            weight: .regular,
            lineHeight: 34,
            tracking: 0.36
        )

        static let title2 = FontToken(
            size: 22,
            weight: .regular,
            lineHeight: 28,
            tracking: 0.35
        )

        static let title3 = FontToken(
            size: 20,
            weight: .regular,
            lineHeight: 24,
            tracking: 0.38
        )

        static let headline = FontToken(
            size: 17,
            weight: .semibold,
            lineHeight: 22,
            tracking: -0.41
        )

        static let body = FontToken(
            size: 17,
            weight: .regular,
            lineHeight: 22,
            tracking: -0.41
        )

        static let callout = FontToken(
            size: 16,
            weight: .regular,
            lineHeight: 21,
            tracking: -0.32
        )

        static let subheadline = FontToken(
            size: 15,
            weight: .regular,
            lineHeight: 20,
            tracking: -0.24
        )

        static let footnote = FontToken(
            size: 13,
            weight: .regular,
            lineHeight: 18,
            tracking: -0.08
        )

        static let caption1 = FontToken(
            size: 12,
            weight: .regular,
            lineHeight: 16,
            tracking: 0.0
        )

        static let caption2 = FontToken(
            size: 11,
            weight: .regular,
            lineHeight: 13,
            tracking: 0.07
        )

        // MARK: - Custom Font Integration

        static func customFont(
            _ name: String,
            size: CGFloat,
            relativeTo textStyle: Font.TextStyle = .body
        ) -> Font {
            return .custom(name, size: size, relativeTo: textStyle)
        }
    }

    struct FontToken {
        let size: CGFloat
        let weight: Font.Weight
        let lineHeight: CGFloat
        let tracking: CGFloat

        func asFont(relativeTo textStyle: Font.TextStyle = .body) -> Font {
            Font.system(size: size, weight: weight, design: .default)
                .tracking(tracking / 1000)
        }

        func asAttributedString(
            _ text: String,
            color: SwiftUI.Color = .textPrimary
        ) -> some View {
            Text(text)
                .font(asFont())
                .foregroundColor(color)
                .lineSpacing((lineHeight - size) / 2)
        }
    }
}

// MARK: - Dynamic Type Extension

extension View {
    func scaledFont(
        token: DesignTokens.FontToken,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> some View {
        self
            .font(token.asFont(relativeTo: textStyle))
            .environment(\.dynamicTypeSize, .large)
    }
}

// MARK: - Accessible Typography with Min/Max Sizes

struct AccessibleText: View {
    let text: String
    let token: DesignTokens.FontToken
    @ScaledMetric var scaledSize: CGFloat
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var body: some View {
        let minSize = token.size * 0.85
        let maxSize = token.size * 1.5
        let effectiveSize = scaledSize.clamped(to: minSize...maxSize)

        Text(text)
            .font(.system(size: effectiveSize, weight: token.weight, design: .default))
            .lineSpacing((token.lineHeight - token.size) / 2)
    }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
```

### Spacing & Layout Tokens

4-point grid system with platform-adaptive adjustments.

```swift
extension DesignTokens {
    enum Spacing {
        // MARK: - Base Grid (4pt)

        static let spacing2: CGFloat = 2
        static let spacing4: CGFloat = 4
        static let spacing8: CGFloat = 8
        static let spacing12: CGFloat = 12
        static let spacing16: CGFloat = 16
        static let spacing24: CGFloat = 24
        static let spacing32: CGFloat = 32
        static let spacing48: CGFloat = 48
        static let spacing64: CGFloat = 64

        // MARK: - Common Composite Spacings

        static let spacingXSmall = spacing8
        static let spacingSmall = spacing12
        static let spacingMedium = spacing16
        static let spacingLarge = spacing24
        static let spacingXLarge = spacing32

        // MARK: - Padding Insets

        static let cardPadding = EdgeInsets(
            top: spacing16,
            leading: spacing16,
            bottom: spacing16,
            trailing: spacing16
        )

        static let sectionPadding = EdgeInsets(
            top: spacing24,
            leading: spacing16,
            bottom: spacing24,
            trailing: spacing16
        )

        static let screenMargins = EdgeInsets(
            top: spacing16,
            leading: spacing16,
            bottom: spacing32,
            trailing: spacing16
        )

        // MARK: - Platform-Adaptive Spacing

        static var adaptiveContentMargin: CGFloat {
            #if os(watchOS)
            return spacing8
            #elseif os(tvOS)
            return spacing48
            #else
            return spacing16
            #endif
        }

        static func adaptiveSpacing(
            compact: CGFloat,
            regular: CGFloat,
            sizeClass: UserInterfaceSizeClass?
        ) -> CGFloat {
            sizeClass == .compact ? compact : regular
        }
    }

    // MARK: - Safe Area Integration

    struct SafeAreaLayout {
        @Environment(\.safeAreaInsets) var safeInsets

        var availableWidth: CGFloat? = nil
        var availableHeight: CGFloat? = nil

        func contentFrame(in geometry: GeometryProxy) -> CGRect {
            let maxWidth = availableWidth ?? geometry.size.width
            let maxHeight = availableHeight ?? geometry.size.height

            return CGRect(
                x: safeInsets.leading,
                y: safeInsets.top,
                width: maxWidth - (safeInsets.leading + safeInsets.trailing),
                height: maxHeight - (safeInsets.top + safeInsets.bottom)
            )
        }
    }
}
```

### Radius & Shape Tokens

Comprehensive corner radius system with continuous corners support.

```swift
extension DesignTokens {
    enum Radius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let extraLarge: CGFloat = 16
        static let pill: CGFloat = 999

        // MARK: - Shape Instances

        static var smallRounded: some Shape {
            RoundedRectangle(cornerRadius: small, style: .continuous)
        }

        static var mediumRounded: some Shape {
            RoundedRectangle(cornerRadius: medium, style: .continuous)
        }

        static var largeRounded: some Shape {
            RoundedRectangle(cornerRadius: large, style: .continuous)
        }

        static var pill: some Shape {
            Capsule(style: .continuous)
        }

        // MARK: - Dynamic Radius Selection

        static func rounded(for size: CGFloat) -> CGFloat {
            switch size {
            case ..<40: return small
            case 40..<100: return medium
            case 100..<200: return large
            default: return extraLarge
            }
        }
    }
}

// MARK: - Shape Extension

extension Shape {
    func styled(radius: CGFloat) -> AnyShape {
        AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}
```

### Shadow & Elevation Tokens

Layered elevation system for spatial hierarchy.

```swift
extension DesignTokens {
    enum Elevation {
        // MARK: - Shadow Presets

        static let none = ShadowToken()

        static let subtle = ShadowToken(
            color: .black,
            opacity: 0.04,
            x: 0,
            y: 1,
            blur: 3,
            spread: 0
        )

        static let medium = ShadowToken(
            color: .black,
            opacity: 0.08,
            x: 0,
            y: 4,
            blur: 6,
            spread: 0
        )

        static let prominent = ShadowToken(
            color: .black,
            opacity: 0.12,
            x: 0,
            y: 12,
            blur: 16,
            spread: 0
        )

        static let elevated = ShadowToken(
            color: .black,
            opacity: 0.15,
            x: 0,
            y: 20,
            blur: 25,
            spread: -5
        )
    }

    struct ShadowToken {
        let color: SwiftUI.Color
        let opacity: Double
        let x: CGFloat
        let y: CGFloat
        let blur: CGFloat
        let spread: CGFloat

        init(
            color: SwiftUI.Color = .black,
            opacity: Double = 0.0,
            x: CGFloat = 0,
            y: CGFloat = 0,
            blur: CGFloat = 0,
            spread: CGFloat = 0
        ) {
            self.color = color
            self.opacity = opacity
            self.x = x
            self.y = y
            self.blur = blur
            self.spread = spread
        }

        func apply(to view: some View) -> some View {
            view
                .shadow(
                    color: color.opacity(opacity),
                    radius: blur / 2,
                    x: x,
                    y: y
                )
        }
    }

    // MARK: - Material Backgrounds

    enum MaterialAppearance {
        case ultraThin
        case thin
        case regular
        case thick
        case chrome

        var material: Material {
            switch self {
            case .ultraThin: return .ultraThinMaterial
            case .thin: return .thinMaterial
            case .regular: return .regularMaterial
            case .thick: return .thickMaterial
            case .chrome: return .ultraThickMaterial
            }
        }
    }
}

// MARK: - View Shadow Extension

extension View {
    func applyShadow(_ token: DesignTokens.ShadowToken) -> some View {
        self.shadow(
            color: token.color.opacity(token.opacity),
            radius: token.blur / 2,
            x: token.x,
            y: token.y
        )
    }

    func elevatedBackground(_ material: Material = .regularMaterial) -> some View {
        self
            .background(material)
            .applyShadow(.medium)
    }
}
```

### Icon System

SF Symbols integration with variant support.

```swift
extension DesignTokens {
    enum Icons {
        // MARK: - Navigation Icons

        static let home = "house.fill"
        static let search = "magnifyingglass"
        static let bell = "bell.fill"
        static let settings = "gear"
        static let menu = "line.3.horizontal"

        // MARK: - Action Icons

        static let add = "plus.circle.fill"
        static let edit = "pencil"
        static let delete = "trash"
        static let share = "square.and.arrow.up"
        static let chevronRight = "chevron.right"
        static let close = "xmark"

        // MARK: - Status Icons

        static let success = "checkmark.circle.fill"
        static let warning = "exclamationmark.triangle.fill"
        static let error = "xmark.circle.fill"
        static let info = "info.circle.fill"

        // MARK: - Symbol Configuration

        struct SymbolConfig {
            let name: String
            let size: CGFloat
            let weight: Font.Weight
            let variant: SymbolVariant

            func image(
                renderingMode: SymbolRenderingMode = .hierarchical,
                foregroundColor: SwiftUI.Color? = nil
            ) -> some View {
                Image(systemName: name)
                    .font(.system(size: size, weight: weight))
                    .symbolVariant(variant)
                    .symbolRenderingMode(renderingMode)
                    .foregroundColor(foregroundColor ?? .primary)
            }
        }

        // MARK: - Preset Symbol Configurations

        static let smallIcon = SymbolConfig(
            name: "circle.fill",
            size: 16,
            weight: .regular,
            variant: .none
        )

        static let mediumIcon = SymbolConfig(
            name: "circle.fill",
            size: 24,
            weight: .regular,
            variant: .none
        )

        static let largeIcon = SymbolConfig(
            name: "circle.fill",
            size: 32,
            weight: .semibold,
            variant: .none
        )
    }
}

// MARK: - Icon Rendering Extensions

extension Image {
    func symbolStyle(
        size: CGFloat,
        weight: Font.Weight = .regular,
        color: SwiftUI.Color = .primary
    ) -> some View {
        self
            .font(.system(size: size, weight: weight))
            .foregroundColor(color)
    }

    func adaptiveSymbolSize() -> some View {
        #if os(watchOS)
        self.font(.system(size: 16))
        #elseif os(tvOS)
        self.font(.system(size: 32))
        #else
        self.font(.system(size: 24))
        #endif
    }
}
```

## Reusable Component Library

### Button Components

Production-grade button styles with full state management.

```swift
// MARK: - Button Style Enumerations

enum ButtonVariant {
    case primary
    case secondary
    case tertiary
    case destructive
    case ghost
}

enum ButtonSize {
    case small
    case medium
    case large

    var height: CGFloat {
        switch self {
        case .small: return 32
        case .medium: return 44
        case .large: return 56
        }
    }

    var padding: EdgeInsets {
        switch self {
        case .small: return EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        case .medium: return EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
        case .large: return EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
        }
    }
}

// IMPORTANT: Always implement ButtonStyle protocol for reusable button styling.
// This gives you press state for free and proper SwiftUI integration.
struct PrimaryButtonStyle: ButtonStyle {
    let variant: ButtonVariant
    let size: ButtonSize
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size == .small ? .system(size: 14, weight: .semibold) : .headline)
            .frame(maxWidth: .infinity)
            .frame(height: size.height)
            .padding(size.padding)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .foregroundColor(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        guard isEnabled else {
            return DesignTokens.Color.secondary.opacity(0.3)
        }
        let base: Color = switch variant {
        case .primary: DesignTokens.Color.primary
        case .secondary: DesignTokens.Color.surfaceElevated
        case .tertiary: .clear
        case .destructive: DesignTokens.Color.destructive
        case .ghost: .clear
        }
        return isPressed ? base.opacity(0.8) : base
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary, .destructive: .white
        case .secondary: DesignTokens.Color.textPrimary
        case .tertiary, .ghost: DesignTokens.Color.primary
        }
    }
}

// Usage: Button("Save") { save() }.buttonStyle(PrimaryButtonStyle(variant: .primary, size: .medium))

// Convenience wrapper that applies the custom ButtonStyle:
struct DesignSystemButton: View {
    let title: String
    let variant: ButtonVariant
    let size: ButtonSize
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(PrimaryButtonStyle(variant: variant, size: size))
            .accessibilityLabel(title)
    }
}
// All styling logic lives in PrimaryButtonStyle (ButtonStyle protocol).
// DesignSystemButton is a convenience wrapper — the ButtonStyle is reusable independently.

// MARK: - Loading Button

struct LoadingButton: View {
    let title: String
    @State var isLoading = false
    let action: () async -> Void

    var body: some View {
        Button(action: {
            Task {
                isLoading = true
                await action()
                isLoading = false
            }
        }) {
            if isLoading {
                HStack {
                    ProgressView()
                        .tint(.white)
                    Text(title)
                }
            } else {
                Text(title)
            }
        }
        .disabled(isLoading)
    }
}

// MARK: - Icon Button

struct IconButton: View {
    let iconName: String
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.system(size: size, weight: .semibold))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
    }
}
```

### Card Components

Versatile card patterns with content variants.

```swift
struct DesignSystemCard<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat = DesignTokens.Radius.medium

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(DesignTokens.Spacing.spacing16)
            .background(DesignTokens.Color.surfaceElevated)
            .cornerRadius(cornerRadius)
            .applyShadow(.subtle)
    }
}

struct ImageCard: View {
    let image: Image
    let title: String
    let subtitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            image
                .resizable()
                .scaledToFill()
                .frame(height: 200)
                .clipped()

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(DesignTokens.Color.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(DesignTokens.Color.textSecondary)
                }

                if let action = action {
                    Button(action: action) {
                        Text("View Details")
                            .font(.callout)
                            .foregroundColor(DesignTokens.Color.primary)
                    }
                }
            }
            .padding(DesignTokens.Spacing.spacing16)
        }
        .background(DesignTokens.Color.surfaceBase)
        .cornerRadius(DesignTokens.Radius.large)
        .applyShadow(.medium)
    }
}

struct InteractiveCard: View {
    let title: String
    let onTap: () -> Void
    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing12) {
            Text(title)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.Spacing.spacing16)
        .background(DesignTokens.Color.surfaceElevated)
        .cornerRadius(DesignTokens.Radius.medium)
        .onTapGesture(perform: onTap)
        .contextMenu {
            Button("Action", action: onTap)
        }
    }
}
```

### Input Components

Form inputs with validation and state management.

```swift
struct StyledTextField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    var validationState: ValidationState = .normal

    enum ValidationState {
        case normal
        case error(String)
        case success
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing8) {
            Text(label)
                .font(.caption)
                .foregroundColor(DesignTokens.Color.textSecondary)

            TextField(placeholder, text: $text)
                .padding(DesignTokens.Spacing.spacing12)
                .background(DesignTokens.Color.surfaceElevated)
                .cornerRadius(DesignTokens.Radius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                        .stroke(borderColor, lineWidth: 1)
                )

            if case .error(let message) = validationState {
                HStack(spacing: DesignTokens.Spacing.spacing8) {
                    Image(systemName: DesignTokens.Icons.error)
                        .font(.caption)
                    Text(message)
                        .font(.caption)
                }
                .foregroundColor(DesignTokens.Color.destructive)
            }
        }
    }

    var borderColor: SwiftUI.Color {
        switch validationState {
        case .normal: return DesignTokens.Color.divider
        case .error: return DesignTokens.Color.destructive
        case .success: return DesignTokens.Color.success
        }
    }
}

struct SearchBar: View {
    @Binding var searchText: String
    let placeholder: String = "Search"

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.spacing8) {
            Image(systemName: DesignTokens.Icons.search)
                .foregroundColor(DesignTokens.Color.textSecondary)

            TextField(placeholder, text: $searchText)
                .textFieldStyle(.roundedBorder)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: DesignTokens.Icons.close)
                        .foregroundColor(DesignTokens.Color.textSecondary)
                }
            }
        }
        .padding(DesignTokens.Spacing.spacing12)
        .background(DesignTokens.Color.surfaceElevated)
        .cornerRadius(DesignTokens.Radius.large)
    }
}
```

### List Components

Styled list rows with accessibility support.

```swift
struct DesignSystemListRow: View {
    let leadingIcon: String?
    let title: String
    let subtitle: String?
    let trailingAccessory: String?

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.spacing12) {
            if let icon = leadingIcon {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DesignTokens.Color.primary)
                    .frame(width: 32, height: 32)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .foregroundColor(DesignTokens.Color.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(DesignTokens.Color.textSecondary)
                }
            }

            Spacer()

            if let accessory = trailingAccessory {
                Text(accessory)
                    .font(.callout)
                    .foregroundColor(DesignTokens.Color.textSecondary)
            }
        }
        .padding(DesignTokens.Spacing.spacing12)
        .frame(height: 60)
        .contentShape(Rectangle())
    }
}
```

## Accessibility as a First-Class Concern

```swift
extension View {
    func accessibleLabel(_ label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(Text(label))
            .accessibilityHint(hint.map(Text.init) ?? Text(""))
    }

    func accessibleButton(label: String) -> some View {
        self
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(label))
            .accessibilityAddTraits(.isButton)
    }

    func accessibleMinimumTouchTarget(size: CGFloat = 44) -> some View {
        self.frame(minWidth: size, minHeight: size)
    }
}

struct AccessibleCard: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing12) {
            Text(title).font(.headline)
            Text(content).font(.body)
        }
        .padding(DesignTokens.Spacing.spacing16)
        .background(DesignTokens.Color.surfaceElevated)
        .cornerRadius(DesignTokens.Radius.medium)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(content))
    }
}

// MARK: - Dynamic Type Support

struct DynamicTypeAwareView: View {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @Environment(\.legibilityWeight) var legibilityWeight

    var body: some View {
        VStack {
            Text("Dynamic Type: \(dynamicTypeSize.description)")
                .font(.body)
                .accessibilityLabel("Current dynamic type size")

            if reduceMotion {
                Text("Animations disabled")
            }

            if reduceTransparency {
                Color.blue.opacity(0.7)
            } else {
                Color.blue.opacity(0.3)
            }
        }
    }
}
```

## Cross-Platform Adaptations

```swift
// MARK: - Platform-Specific Modifiers

struct PlatformAdaptiveModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) var sizeClass

    func body(content: Content) -> some View {
        #if os(iOS)
        if sizeClass == .compact {
            content.padding(.vertical, DesignTokens.Spacing.spacing8)
        } else {
            content.padding(.vertical, DesignTokens.Spacing.spacing16)
        }
        #elseif os(watchOS)
        content.padding(.vertical, DesignTokens.Spacing.spacing4)
        #else
        content.padding(.vertical, DesignTokens.Spacing.spacing16)
        #endif
    }
}

extension View {
    func platformAdaptive() -> some View {
        modifier(PlatformAdaptiveModifier())
    }
}

// MARK: - SPM Package Structure

// In Package.swift:
/*
let package = Package(
    name: "DesignSystem",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        .library(name: "DesignSystem", targets: ["DesignSystem"])
    ],
    targets: [
        .target(
            name: "DesignSystem",
            dependencies: [],
            resources: [.process("Resources")]
        )
    ]
)
*/
```

## Animation Tokens

```swift
extension DesignTokens {
    enum Animation {
        static let quick = 0.15
        static let normal = 0.3
        static let slow = 0.5

        static let easeInOutCurve = SwiftUI.Animation.easeInOut(duration: normal)
        static let springCurve = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.7)
        static let quickCurve = SwiftUI.Animation.easeInOut(duration: quick)
    }
}

struct AnimatedCard: View {
    @State private var isExpanded = false

    var body: some View {
        VStack {
            Text("Content")
                .frame(height: isExpanded ? 200 : 100)
        }
        .animation(DesignTokens.Animation.easeInOutCurve, value: isExpanded)
        .onTapGesture { isExpanded.toggle() }
    }
}

struct MatchedGeometryAnimation: View {
    @Namespace var animation
    @State var showDetail = false

    var body: some View {
        if showDetail {
            VStack {
                RoundedRectangle(cornerRadius: 12)
                    .matchedGeometryEffect(id: "card", in: animation)
                    .frame(height: 400)
            }
        } else {
            VStack {
                RoundedRectangle(cornerRadius: 8)
                    .matchedGeometryEffect(id: "card", in: animation)
                    .frame(height: 100)
            }
        }
    }
}

// MARK: - Reduce Motion Awareness

struct ConditionalAnimation<V: View>: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let content: V

    var body: some View {
        if reduceMotion {
            content
        } else {
            content.animation(DesignTokens.Animation.easeInOutCurve, value: UUID())
        }
    }
}
```

## Production Deployment

Export design system as SPM module. Import with `@_spi` for internal-only APIs:

```swift
@_spi(DesignSystem) import DesignSystem
```

Version tokens using semantic versioning. Deprecate old patterns:

```swift
@available(*, deprecated, message: "Use DesignTokens.Color.primary instead")
static var oldBlueColor: Color { .blue }
```

Provide Xcode Playgrounds for token exploration. Maintain a living design system documentation site with SwiftUI preview integration.

import SwiftUI

public enum Theme {
    // Colors
    public static let background = Color(nsColor: .windowBackgroundColor)
    public static let secondaryBackground = Color(nsColor: .controlBackgroundColor)
    public static let accent = Color.primary
    public static let subtleBorder = Color.primary.opacity(0.08)
    public static let userBubble = Color.primary.opacity(0.06)
    public static let assistantBubble = Color.clear
    public static let textPrimary = Color.primary
    public static let textSecondary = Color.secondary
    public static let textTertiary = Color.secondary.opacity(0.7)

    // Layout & Spacing
    public static let cornerRadiusSmall: CGFloat = 8
    public static let cornerRadiusMedium: CGFloat = 14
    public static let cornerRadiusLarge: CGFloat = 20
    public static let maxContentWidth: CGFloat = 680

    // Animations
    public static let defaultAnimation: Animation = .easeInOut(duration: 0.2)
}

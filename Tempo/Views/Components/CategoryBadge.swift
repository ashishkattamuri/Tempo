import SwiftUI

/// Visual badge displaying a task's category with color and icon.
struct CategoryBadge: View {
    let category: TaskCategory
    var size: BadgeSize = .medium
    var showLabel: Bool = true

    enum BadgeSize {
        case small
        case medium
        case large

        var iconSize: CGFloat {
            switch self {
            case .small: return 12
            case .medium: return 16
            case .large: return 20
            }
        }

        var padding: CGFloat {
            switch self {
            case .small: return 4
            case .medium: return 6
            case .large: return 8
            }
        }

        var fontSize: Font {
            switch self {
            case .small: return .caption2
            case .medium: return .caption
            case .large: return .subheadline
            }
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.iconName)
                .font(.system(size: size.iconSize))

            if showLabel {
                Text(category.displayName)
                    .font(size.fontSize)
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal, size.padding)
        .padding(.vertical, size.padding / 2)
        .background(category.color.opacity(0.15))
        .foregroundColor(category.color)
        .cornerRadius(Constants.cornerRadius / 2)
        .accessibilityLabel("\(category.displayName) category")
    }
}

// MARK: - Previews

#Preview("All Categories") {
    VStack(spacing: 16) {
        ForEach(TaskCategory.allCases) { category in
            HStack {
                CategoryBadge(category: category, size: .small, showLabel: false)
                CategoryBadge(category: category, size: .medium)
                CategoryBadge(category: category, size: .large)
            }
        }
    }
    .padding()
}

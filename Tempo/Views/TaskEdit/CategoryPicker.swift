import SwiftUI

/// Category selection view with descriptions.
struct CategoryPicker: View {
    @Binding var selection: TaskCategory

    var body: some View {
        VStack(spacing: 12) {
            ForEach(TaskCategory.allCases) { category in
                CategoryOptionRow(
                    category: category,
                    isSelected: selection == category,
                    onSelect: { selection = category }
                )
            }
        }
    }
}

/// Individual category option row
struct CategoryOptionRow: View {
    let category: TaskCategory
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? category.color : .gray)

                // Category icon and color
                Image(systemName: category.iconName)
                    .font(.title3)
                    .foregroundColor(category.color)
                    .frame(width: 32)

                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.displayName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text(category.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: Constants.cornerRadius)
                    .fill(isSelected ? category.color.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Constants.cornerRadius)
                    .stroke(isSelected ? category.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category.displayName), \(category.description)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Compact category picker for inline use
struct CompactCategoryPicker: View {
    @Binding var selection: TaskCategory

    var body: some View {
        Menu {
            ForEach(TaskCategory.allCases) { category in
                Button(action: { selection = category }) {
                    Label(category.displayName, systemImage: category.iconName)
                }
            }
        } label: {
            HStack {
                CategoryBadge(category: selection, size: .medium)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Previews

#Preview("Category Picker") {
    struct PreviewWrapper: View {
        @State private var selection: TaskCategory = .flexibleTask

        var body: some View {
            VStack {
                Text("Selected: \(selection.displayName)")
                    .padding()

                CategoryPicker(selection: $selection)
                    .padding()
            }
        }
    }

    return PreviewWrapper()
}

#Preview("Compact Picker") {
    struct PreviewWrapper: View {
        @State private var selection: TaskCategory = .identityHabit

        var body: some View {
            CompactCategoryPicker(selection: $selection)
                .padding()
        }
    }

    return PreviewWrapper()
}

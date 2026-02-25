import SwiftUI

/// Reusable confirmation dialog for important actions.
struct ConfirmationSheet: View {
    let title: String
    let message: String
    let confirmTitle: String
    let confirmRole: ButtonRole?
    let onConfirm: () -> Void
    let onCancel: () -> Void

    init(
        title: String,
        message: String,
        confirmTitle: String = "Confirm",
        confirmRole: ButtonRole? = nil,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.confirmRole = confirmRole
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(spacing: 20) {

            // Header
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)  
                    .multilineTextAlignment(.center)
            }
            .padding(.top)

            // Actions
            VStack(spacing: 12) {

                // Confirm button
                Button(action: onConfirm) {
                    Text(confirmTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            confirmRole == .destructive
                            ? Color.red
                            : Color.accentColor
                        )
                        .foregroundStyle(.white)   
                        .cornerRadius(Constants.cornerRadius)
                }
                .buttonStyle(.plain)

                // Cancel button
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5)) 
                        .foregroundStyle(.primary)    
                        .cornerRadius(Constants.cornerRadius)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.systemBackground))  
        .presentationDetents([.height(250)])
        .presentationDragIndicator(.visible)
    }
}


/// Evening protection confirmation specifically
struct EveningProtectionSheet: View {
    let decision: EveningDecision
    let onKeepFree: () -> Void
    let onAllow: () -> Void

    var body: some View {
        VStack(spacing: 20) {

            // Icon
            Image(systemName: decision.iconName)
                .font(.system(size: 48))
                .foregroundStyle(.purple)
                .padding(.top)

            // Header
            VStack(spacing: 8) {
                Text("Evening Protection")
                    .font(.headline)

                Text(decision.message)
                    .font(.body)
                    .foregroundStyle(.secondary) 
                    .multilineTextAlignment(.center)
            }

            // Affected items
            if !decision.affectedItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Affected:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(decision.affectedItems, id: \.id) { item in
                        HStack {
                            CategoryBadge(
                                category: item.category,
                                size: .small,
                                showLabel: false
                            )

                            Text(item.title)
                                .font(.subheadline)

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color(.systemGray6))  
                .cornerRadius(Constants.cornerRadius)
            }

            // Actions
            VStack(spacing: 12) {

                // Keep Free button
                Button(action: onKeepFree) {
                    HStack {
                        Image(systemName: "moon.fill")
                        Text("Keep Evening Free")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundStyle(.white)  
                    .cornerRadius(Constants.cornerRadius)
                }
                .buttonStyle(.plain)

                // Allow button
                Button(action: onAllow) {
                    Text("Allow Evening Tasks")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5)) 
                        .foregroundStyle(.primary)       
                        .cornerRadius(Constants.cornerRadius)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.systemBackground)) 
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}


// MARK: - Previews

#Preview("Confirmation Sheet") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ConfirmationSheet(
                title: "Apply Changes?",
                message: "This will adjust 3 tasks and defer 2 to tomorrow.",
                confirmTitle: "Apply Changes",
                onConfirm: {},
                onCancel: {}
            )
        }
}
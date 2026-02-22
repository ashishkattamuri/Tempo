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
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top)

            // Actions
            VStack(spacing: 12) {
                Button(action: onConfirm) {
                    Text(confirmTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(confirmRole == .destructive ? Color.red : Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(Constants.cornerRadius)
                }
                .buttonStyle(.plain)

                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(Constants.cornerRadius)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .presentationDetents([.height(250)])
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

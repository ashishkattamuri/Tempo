import SwiftUI

struct ScheduleSharePreviewSheet: View {
    let date: Date
    let items: [ScheduleItem]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Preview")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                 
                    ScheduleExportView(date: date, items: items)
                        .frame(maxWidth: 390)
                        .shadow(color: .black.opacity(0.1), radius: 16, x: 0, y: 8)
                        .padding(.horizontal, 24)

         
                    Button(action: {
                        ScheduleExportService.shared.exportAndShare(date: date, items: items)
                    }) {
                        Label("Share Schedule", systemImage: "square.and.arrow.up")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.vertical, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Export Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
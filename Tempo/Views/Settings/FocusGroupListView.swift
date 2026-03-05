import SwiftUI
import FamilyControls

/// Displays all configured Focus Groups and allows creating, editing, and deleting them.
struct FocusGroupListView: View {
    @EnvironmentObject var focusBlockManager: FocusBlockManager
    @State private var showingCreate = false
    @State private var editingGroup: FocusGroup?

    var body: some View {
        List {
            authorizationSection

            if !focusBlockManager.groups.isEmpty {
                groupsSection
            }

            infoFooter
        }
        .navigationTitle("Focus Block")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingCreate = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(focusBlockManager.authorizationStatus != .approved)
            }
        }
        .sheet(isPresented: $showingCreate) {
            NavigationStack {
                FocusGroupEditView(group: nil)
                    .environmentObject(focusBlockManager)
            }
        }
        .sheet(item: $editingGroup) { group in
            NavigationStack {
                FocusGroupEditView(group: group)
                    .environmentObject(focusBlockManager)
            }
        }
        .onAppear {
            focusBlockManager.refreshAuthorizationStatus()
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var authorizationSection: some View {
        Section {
            switch focusBlockManager.authorizationStatus {
            case .approved:
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                    Text("Screen Time access granted")
                        .foregroundColor(.secondary)
                }
            default:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Screen Time Authorization Required")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Tempo needs Screen Time permission to block apps during focus sessions.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Authorize") {
                        Task { await focusBlockManager.requestAuthorization() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .padding(.top, 2)
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Permission")
        }
    }

    @ViewBuilder
    private var groupsSection: some View {
        Section {
            ForEach(focusBlockManager.groups) { group in
                Button {
                    editingGroup = group
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.indigo.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: group.symbol)
                                .font(.system(size: 16))
                                .foregroundColor(.indigo)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.name)
                                .font(.body)
                                .foregroundColor(.primary)
                            Text(group.blockedItemDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    focusBlockManager.deleteGroup(focusBlockManager.groups[index])
                }
            }
        } header: {
            Text("Groups")
        }
    }

    @ViewBuilder
    private var infoFooter: some View {
        Section {
            EmptyView()
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Label("Blocking only works on physical devices, not Simulator.", systemImage: "iphone")
                Label("App blocking activates automatically — no need to open Tempo.", systemImage: "moon.circle")
                Label("If the device is asleep at end time, apps unblock on next unlock.", systemImage: "clock.badge.exclamationmark")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        FocusGroupListView()
            .environmentObject(FocusBlockManager())
    }
}

import SwiftUI

/// Main settings menu view that provides access to all app settings.
struct SettingsMenuView: View {

    @ObservedObject var sleepManager: SleepManager
    @ObservedObject var compensationTracker: CompensationTracker
    let onDismiss: () -> Void

    // MARK: - Appearance (NEW)

    @AppStorage("appAppearance") private var appAppearanceRaw: String = AppAppearance.system.rawValue

    var body: some View {
        List {

            // Sleep Schedule Section
            Section {
                NavigationLink {
                    SleepSettingsView(sleepManager: sleepManager)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "moon.fill")
                            .foregroundStyle(.indigo)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sleep Schedule")
                                .font(.body)

                            if sleepManager.isEnabled, let schedule = sleepManager.sleepSchedule {
                                Text("\(schedule.bedtimeString) - \(schedule.wakeTimeString)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Not configured")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Time Blocking")
            }

            // Compensation Section
            Section {
                NavigationLink {
                    CompensationView(compensationTracker: compensationTracker)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .foregroundStyle(.orange)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Makeup Sessions")
                                .font(.body)

                            if compensationTracker.hasPendingCompensations {
                                Text("\(compensationTracker.formattedPendingTime) to make up")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            } else {
                                Text("All caught up")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            } header: {
                Text("Task Management")
            }

            // About Section
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("2.0")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("About")
            }

            // MARK: - Appearance Section (NEW)

            Section("Appearance") {
                Picker("Theme", selection: $appAppearanceRaw) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.displayName)
                            .tag(appearance.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", action: onDismiss)
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsMenuView(
            sleepManager: SleepManager(),
            compensationTracker: CompensationTracker(),
            onDismiss: {}
        )
    }
}
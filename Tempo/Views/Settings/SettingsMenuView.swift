import SwiftUI

/// Main settings menu view that provides access to all app settings.
struct SettingsMenuView: View {
    @ObservedObject var sleepManager: SleepManager
    @ObservedObject var compensationTracker: CompensationTracker
    let onDismiss: () -> Void

    var body: some View {
        List {
            
            // MARK: - Time Blocking
            
            Section {
                NavigationLink {
                    SleepSettingsView(sleepManager: sleepManager)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "moon.fill")
                            .foregroundColor(.indigo)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sleep Schedule")
                                .font(.body)

                            if sleepManager.isEnabled, let schedule = sleepManager.sleepSchedule {
                                Text("\(schedule.bedtimeString) - \(schedule.wakeTimeString)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Not configured")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Time Blocking")
            }
            
            // MARK: - Calendar
            
            Section {
                NavigationLink {
                    CalendarImportView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar.badge.plus")
                            .foregroundColor(.blue)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Import Apple Calendar")
                                .font(.body)
                            
                            Text("Sync events as Non-Negotiable tasks")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text("Calendar")
            }
            
            // MARK: - Task Management
            
            Section {
                NavigationLink {
                    CompensationView(compensationTracker: compensationTracker)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .foregroundColor(.orange)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Makeup Sessions")
                                .font(.body)

                            if compensationTracker.hasPendingCompensations {
                                Text("\(compensationTracker.formattedPendingTime) to make up")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            } else {
                                Text("All caught up")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            } header: {
                Text("Task Management")
            }

            // MARK: - About
            
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("2.0")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("About")
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
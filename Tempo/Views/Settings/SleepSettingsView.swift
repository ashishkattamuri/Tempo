import SwiftUI

/// Settings view for configuring sleep schedule integration.
struct SleepSettingsView: View {
    @ObservedObject var sleepManager: SleepManager

    @State private var showingManualEntry = false
    @State private var manualBedtimeHour = 22
    @State private var manualBedtimeMinute = 30
    @State private var manualWakeHour = 6
    @State private var manualWakeMinute = 30
    @State private var manualBuffer = 30

    var body: some View {
        List {
            // Enable/Disable Section
            Section {
                Toggle("Block sleep times from scheduling", isOn: Binding(
                    get: { sleepManager.isEnabled },
                    set: { sleepManager.setEnabled($0) }
                ))
            } footer: {
                Text("When enabled, Tempo will not schedule tasks during your sleep time or the wind-down buffer before bed.")
            }

            if sleepManager.isEnabled {
                // Current Schedule Section
                if let schedule = sleepManager.sleepSchedule {
                    Section("Current Sleep Schedule") {
                        HStack {
                            Label("Bedtime", systemImage: "moon.fill")
                                .foregroundColor(.indigo)
                            Spacer()
                            Text(schedule.bedtimeString)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Label("Wake time", systemImage: "sun.max.fill")
                                .foregroundColor(.orange)
                            Spacer()
                            Text(schedule.wakeTimeString)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Label("Wind-down buffer", systemImage: "clock.badge.checkmark")
                                .foregroundColor(.purple)
                            Spacer()
                            Text("\(schedule.bufferMinutes) min")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // HealthKit Section
                Section {
                    if sleepManager.isHealthKitAvailable {
                        if sleepManager.isAuthorized {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Connected to Health")
                            }

                            Button("Refresh Sleep Schedule") {
                                Task {
                                    await sleepManager.fetchSleepSchedule()
                                }
                            }
                        } else {
                            Button {
                                Task {
                                    await sleepManager.requestAuthorization()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(.red)
                                    Text("Connect to Apple Health")
                                }
                            }

                            if let error = sleepManager.authorizationError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow)
                            Text("HealthKit not available")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Apple Health Integration")
                } footer: {
                    Text("Tempo can automatically read your sleep schedule from Apple Health to block those times from scheduling.")
                }

                // Manual Entry Section
                Section {
                    Button("Set Schedule Manually") {
                        if let schedule = sleepManager.sleepSchedule {
                            manualBedtimeHour = schedule.bedtimeHour
                            manualBedtimeMinute = schedule.bedtimeMinute
                            manualWakeHour = schedule.wakeHour
                            manualWakeMinute = schedule.wakeMinute
                            manualBuffer = schedule.bufferMinutes
                        }
                        showingManualEntry = true
                    }
                } header: {
                    Text("Manual Schedule")
                } footer: {
                    Text("Use this if you don't use Apple Health or want to override the detected schedule.")
                }
            }
        }
        .navigationTitle("Sleep Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingManualEntry) {
            manualEntrySheet
        }
    }

    // MARK: - Manual Entry Sheet

    private var manualEntrySheet: some View {
        NavigationStack {
            Form {
                Section("Bedtime") {
                    Picker("Hour", selection: $manualBedtimeHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(formatHour(hour)).tag(hour)
                        }
                    }
                    .pickerStyle(.wheel)

                    Picker("Minute", selection: $manualBedtimeMinute) {
                        ForEach([0, 15, 30, 45], id: \.self) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Wake Time") {
                    Picker("Hour", selection: $manualWakeHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(formatHour(hour)).tag(hour)
                        }
                    }
                    .pickerStyle(.wheel)

                    Picker("Minute", selection: $manualWakeMinute) {
                        ForEach([0, 15, 30, 45], id: \.self) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Picker("Buffer before bed", selection: $manualBuffer) {
                        Text("15 min").tag(15)
                        Text("30 min").tag(30)
                        Text("45 min").tag(45)
                        Text("1 hour").tag(60)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Wind-down Buffer")
                } footer: {
                    Text("Tempo won't schedule tasks during this time before your bedtime, giving you time to wind down.")
                }
            }
            .navigationTitle("Set Sleep Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingManualEntry = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let schedule = SleepManager.SleepSchedule(
                            bedtimeHour: manualBedtimeHour,
                            bedtimeMinute: manualBedtimeMinute,
                            wakeHour: manualWakeHour,
                            wakeMinute: manualWakeMinute,
                            bufferMinutes: manualBuffer
                        )
                        sleepManager.setManualSchedule(schedule)
                        showingManualEntry = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Helpers

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        var components = DateComponents()
        components.hour = hour
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return "\(hour):00"
    }
}

#Preview {
    NavigationStack {
        SleepSettingsView(sleepManager: SleepManager())
    }
}

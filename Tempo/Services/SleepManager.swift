import Foundation
import HealthKit

/// Manages sleep schedule integration with HealthKit.
/// Reads the user's sleep schedule to block those times from task scheduling.
@MainActor
final class SleepManager: ObservableObject {
    private let healthStore = HKHealthStore()

    @Published var sleepSchedule: SleepSchedule?
    @Published var isAuthorized = false
    @Published var authorizationError: String?
    @Published var isEnabled = false

    /// User's sleep schedule from HealthKit or manual entry
    struct SleepSchedule: Codable, Equatable {
        var bedtimeHour: Int        // 0-23, e.g., 22 for 10 PM
        var bedtimeMinute: Int      // 0-59
        var wakeHour: Int           // 0-23, e.g., 6 for 6 AM
        var wakeMinute: Int         // 0-59
        var bufferMinutes: Int = 30 // Wind-down buffer before bed

        var bedtimeComponents: DateComponents {
            DateComponents(hour: bedtimeHour, minute: bedtimeMinute)
        }

        var wakeTimeComponents: DateComponents {
            DateComponents(hour: wakeHour, minute: wakeMinute)
        }

        var bedtimeString: String {
            formatTime(hour: bedtimeHour, minute: bedtimeMinute)
        }

        var wakeTimeString: String {
            formatTime(hour: wakeHour, minute: wakeMinute)
        }

        private func formatTime(hour: Int, minute: Int) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            if let date = Calendar.current.date(from: components) {
                return formatter.string(from: date)
            }
            return "\(hour):\(String(format: "%02d", minute))"
        }

        static let `default` = SleepSchedule(
            bedtimeHour: 22,
            bedtimeMinute: 30,
            wakeHour: 6,
            wakeMinute: 30,
            bufferMinutes: 30
        )
    }

    // MARK: - UserDefaults Keys

    private let enabledKey = "SleepManager.isEnabled"
    private let manualScheduleKey = "SleepManager.manualSchedule"

    // MARK: - Initialization

    init() {
        loadSettings()
    }

    private func loadSettings() {
        isEnabled = UserDefaults.standard.bool(forKey: enabledKey)

        if let data = UserDefaults.standard.data(forKey: manualScheduleKey),
           let schedule = try? JSONDecoder().decode(SleepSchedule.self, from: data) {
            sleepSchedule = schedule
        }
    }

    private func saveSettings() {
        UserDefaults.standard.set(isEnabled, forKey: enabledKey)

        if let schedule = sleepSchedule,
           let data = try? JSONEncoder().encode(schedule) {
            UserDefaults.standard.set(data, forKey: manualScheduleKey)
        }
    }

    // MARK: - HealthKit Authorization

    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async -> Bool {
        guard isHealthKitAvailable else {
            authorizationError = "HealthKit is not available on this device"
            return false
        }

        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            authorizationError = "Sleep analysis type not available"
            return false
        }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: [sleepType])

            let status = healthStore.authorizationStatus(for: sleepType)
            isAuthorized = status == .sharingAuthorized || status == .notDetermined

            if isAuthorized {
                await fetchSleepSchedule()
            }

            return isAuthorized
        } catch {
            authorizationError = error.localizedDescription
            return false
        }
    }

    // MARK: - Fetch Sleep Schedule

    func fetchSleepSchedule() async {
        guard isHealthKitAvailable else { return }

        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return
        }

        let now = Date()
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now

        let predicate = HKQuery.predicateForSamples(
            withStart: oneWeekAgo,
            end: now,
            options: .strictStartDate
        )

        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: 50,
                sortDescriptors: [sortDescriptor]
            ) { [weak self] _, samples, error in
                Task { @MainActor in
                    if let samples = samples as? [HKCategorySample], !samples.isEmpty {
                        self?.analyzeSleepSamples(samples)
                    }
                    continuation.resume()
                }
            }

            healthStore.execute(query)
        }
    }

    private func analyzeSleepSamples(_ samples: [HKCategorySample]) {
        let sleepSamples = samples.filter { sample in
            let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)
            return value == .inBed || value == .asleep || value == .asleepCore || value == .asleepDeep || value == .asleepREM
        }

        guard !sleepSamples.isEmpty else { return }

        let calendar = Calendar.current
        var bedtimeMinutes: [Int] = []
        var wakeMinutes: [Int] = []

        for sample in sleepSamples {
            let bedComponents = calendar.dateComponents([.hour, .minute], from: sample.startDate)
            if let hour = bedComponents.hour, let minute = bedComponents.minute {
                var minutesFromMidnight = hour * 60 + minute
                if hour < 12 { minutesFromMidnight += 24 * 60 }
                bedtimeMinutes.append(minutesFromMidnight)
            }

            let wakeComponents = calendar.dateComponents([.hour, .minute], from: sample.endDate)
            if let hour = wakeComponents.hour, let minute = wakeComponents.minute {
                wakeMinutes.append(hour * 60 + minute)
            }
        }

        if !bedtimeMinutes.isEmpty && !wakeMinutes.isEmpty {
            let avgBedtime = bedtimeMinutes.reduce(0, +) / bedtimeMinutes.count
            let avgWake = wakeMinutes.reduce(0, +) / wakeMinutes.count

            let bedHour = (avgBedtime / 60) % 24
            let bedMinute = avgBedtime % 60
            let wakeHour = avgWake / 60
            let wakeMinute = avgWake % 60

            sleepSchedule = SleepSchedule(
                bedtimeHour: bedHour,
                bedtimeMinute: (bedMinute / 15) * 15,
                wakeHour: wakeHour,
                wakeMinute: (wakeMinute / 15) * 15,
                bufferMinutes: 30
            )

            saveSettings()
        }
    }

    // MARK: - Manual Schedule

    func setManualSchedule(_ schedule: SleepSchedule) {
        sleepSchedule = schedule
        saveSettings()
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        saveSettings()
    }

    // MARK: - Sleep Block Calculation

    func getSleepBlockedRange(for date: Date) -> (bufferStart: Date, bedtime: Date, wakeTime: Date)? {
        guard isEnabled, let schedule = sleepSchedule else { return nil }

        let calendar = Calendar.current

        var bedtimeComponents = calendar.dateComponents([.year, .month, .day], from: date)
        bedtimeComponents.hour = schedule.bedtimeHour
        bedtimeComponents.minute = schedule.bedtimeMinute

        guard let bedtime = calendar.date(from: bedtimeComponents) else { return nil }

        let bufferStart = bedtime.addingTimeInterval(-Double(schedule.bufferMinutes * 60))

        var wakeComponents = calendar.dateComponents([.year, .month, .day], from: date)
        wakeComponents.hour = schedule.wakeHour
        wakeComponents.minute = schedule.wakeMinute

        guard var wakeTime = calendar.date(from: wakeComponents) else { return nil }

        if wakeTime <= bedtime {
            wakeTime = calendar.date(byAdding: .day, value: 1, to: wakeTime) ?? wakeTime
        }

        return (bufferStart, bedtime, wakeTime)
    }

    func isTimeDuringSleep(_ time: Date) -> Bool {
        guard let range = getSleepBlockedRange(for: time) else { return false }
        return time >= range.bufferStart && time < range.wakeTime
    }

    func doesRangeOverlapSleep(start: Date, end: Date) -> Bool {
        guard let range = getSleepBlockedRange(for: start) else { return false }
        return start < range.wakeTime && end > range.bufferStart
    }

    func getNextAvailableTimeAfterSleep(from time: Date) -> Date {
        guard let range = getSleepBlockedRange(for: time) else { return time }
        if time >= range.bufferStart && time < range.wakeTime {
            return range.wakeTime
        }
        return time
    }
}

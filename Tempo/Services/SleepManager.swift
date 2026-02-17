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

        /// Creates DateComponents for bedtime
        var bedtimeComponents: DateComponents {
            DateComponents(hour: bedtimeHour, minute: bedtimeMinute)
        }

        /// Creates DateComponents for wake time
        var wakeTimeComponents: DateComponents {
            DateComponents(hour: wakeHour, minute: wakeMinute)
        }

        /// Human-readable bedtime string
        var bedtimeString: String {
            formatTime(hour: bedtimeHour, minute: bedtimeMinute)
        }

        /// Human-readable wake time string
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

        /// Default sleep schedule (10:30 PM - 6:30 AM)
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

    /// Check if HealthKit is available on this device
    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Request authorization to read sleep data from HealthKit
    func requestAuthorization() async -> Bool {
        guard isHealthKitAvailable else {
            authorizationError = "HealthKit is not available on this device"
            return false
        }

        // We want to read the user's sleep schedule
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            authorizationError = "Sleep analysis type not available"
            return false
        }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: [sleepType])

            // Check authorization status
            let status = healthStore.authorizationStatus(for: sleepType)
            isAuthorized = status == .sharingAuthorized || status == .notDetermined

            if isAuthorized {
                // Fetch the sleep schedule after authorization
                await fetchSleepSchedule()
            }

            return isAuthorized
        } catch {
            authorizationError = error.localizedDescription
            return false
        }
    }

    // MARK: - Fetch Sleep Schedule

    /// Fetch the user's sleep schedule from HealthKit
    func fetchSleepSchedule() async {
        guard isHealthKitAvailable else { return }

        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return
        }

        // Look for sleep data from the past week
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

    /// Analyze sleep samples to determine typical bedtime and wake time
    private func analyzeSleepSamples(_ samples: [HKCategorySample]) {
        // Filter for "in bed" or "asleep" samples
        let sleepSamples = samples.filter { sample in
            let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)
            return value == .inBed || value == .asleep || value == .asleepCore || value == .asleepDeep || value == .asleepREM
        }

        guard !sleepSamples.isEmpty else { return }

        let calendar = Calendar.current
        var bedtimeMinutes: [Int] = []
        var wakeMinutes: [Int] = []

        for sample in sleepSamples {
            // Get bedtime (start of sleep)
            let bedComponents = calendar.dateComponents([.hour, .minute], from: sample.startDate)
            if let hour = bedComponents.hour, let minute = bedComponents.minute {
                // Convert to minutes from midnight, handling overnight
                var minutesFromMidnight = hour * 60 + minute
                // If bedtime is before noon, add 24 hours (treat as night before)
                if hour < 12 {
                    minutesFromMidnight += 24 * 60
                }
                bedtimeMinutes.append(minutesFromMidnight)
            }

            // Get wake time (end of sleep)
            let wakeComponents = calendar.dateComponents([.hour, .minute], from: sample.endDate)
            if let hour = wakeComponents.hour, let minute = wakeComponents.minute {
                wakeMinutes.append(hour * 60 + minute)
            }
        }

        // Calculate average bedtime and wake time
        if !bedtimeMinutes.isEmpty && !wakeMinutes.isEmpty {
            let avgBedtime = bedtimeMinutes.reduce(0, +) / bedtimeMinutes.count
            let avgWake = wakeMinutes.reduce(0, +) / wakeMinutes.count

            // Convert back to hours and minutes
            let bedHour = (avgBedtime / 60) % 24
            let bedMinute = avgBedtime % 60
            let wakeHour = avgWake / 60
            let wakeMinute = avgWake % 60

            // Round to nearest 15 minutes
            let roundedBedMinute = (bedMinute / 15) * 15
            let roundedWakeMinute = (wakeMinute / 15) * 15

            sleepSchedule = SleepSchedule(
                bedtimeHour: bedHour,
                bedtimeMinute: roundedBedMinute,
                wakeHour: wakeHour,
                wakeMinute: roundedWakeMinute,
                bufferMinutes: 30
            )

            saveSettings()
        }
    }

    // MARK: - Manual Schedule

    /// Set a manual sleep schedule (when HealthKit is not available or user prefers manual)
    func setManualSchedule(_ schedule: SleepSchedule) {
        sleepSchedule = schedule
        saveSettings()
    }

    /// Enable or disable sleep schedule blocking
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        saveSettings()
    }

    // MARK: - Sleep Block Calculation

    /// Get the blocked time range for sleep on a given date
    /// Returns the period from (bedtime - buffer) to wake time
    /// - Parameter date: The date to check (uses the evening of this date to morning of next day)
    /// - Returns: Tuple of (bufferStart, wakeTime) or nil if sleep blocking is disabled
    func getSleepBlockedRange(for date: Date) -> (bufferStart: Date, bedtime: Date, wakeTime: Date)? {
        guard isEnabled, let schedule = sleepSchedule else { return nil }

        let calendar = Calendar.current

        // Calculate bedtime for the given date
        var bedtimeComponents = calendar.dateComponents([.year, .month, .day], from: date)
        bedtimeComponents.hour = schedule.bedtimeHour
        bedtimeComponents.minute = schedule.bedtimeMinute

        guard let bedtime = calendar.date(from: bedtimeComponents) else { return nil }

        // If bedtime hour is late evening (after 6 PM), it's on the same day
        // If it's early morning (before 6 AM), it's actually the next day's early hours
        // But typically bedtime is in the evening, so this should work for most cases

        // Calculate buffer start (30 min before bedtime)
        let bufferStart = bedtime.addingTimeInterval(-Double(schedule.bufferMinutes * 60))

        // Calculate wake time (typically next morning)
        var wakeComponents = calendar.dateComponents([.year, .month, .day], from: date)
        wakeComponents.hour = schedule.wakeHour
        wakeComponents.minute = schedule.wakeMinute

        guard var wakeTime = calendar.date(from: wakeComponents) else { return nil }

        // If wake time is before bedtime, it's the next day
        if wakeTime <= bedtime {
            wakeTime = calendar.date(byAdding: .day, value: 1, to: wakeTime) ?? wakeTime
        }

        return (bufferStart, bedtime, wakeTime)
    }

    /// Check if a given time falls within the sleep blocked period
    func isTimeDuringSleep(_ time: Date) -> Bool {
        guard let range = getSleepBlockedRange(for: time) else { return false }
        return time >= range.bufferStart && time < range.wakeTime
    }

    /// Check if a time range overlaps with sleep
    func doesRangeOverlapSleep(start: Date, end: Date) -> Bool {
        guard let range = getSleepBlockedRange(for: start) else { return false }

        // Check if the task range overlaps with the sleep range
        return start < range.wakeTime && end > range.bufferStart
    }

    /// Get the next available time after sleep
    func getNextAvailableTimeAfterSleep(from time: Date) -> Date {
        guard let range = getSleepBlockedRange(for: time) else { return time }

        // If time is during sleep, return wake time
        if time >= range.bufferStart && time < range.wakeTime {
            return range.wakeTime
        }

        return time
    }
}

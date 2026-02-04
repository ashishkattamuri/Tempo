import Foundation

extension Date {
    // MARK: - Day Boundaries

    /// Start of the current day (midnight)
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// End of the current day (11:59:59 PM)
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
    }

    /// Start of evening (6 PM) on this day
    var eveningStart: Date {
        Calendar.current.date(
            bySettingHour: Constants.eveningStartHour,
            minute: 0,
            second: 0,
            of: self
        ) ?? self
    }

    /// End of evening / day end (11 PM) on this day
    var eveningEnd: Date {
        Calendar.current.date(
            bySettingHour: Constants.dayEndHour,
            minute: 0,
            second: 0,
            of: self
        ) ?? self
    }

    // MARK: - Time Checks

    /// Whether this time is in the evening period (6 PM - 11 PM)
    var isEvening: Bool {
        let hour = Calendar.current.component(.hour, from: self)
        return hour >= Constants.eveningStartHour && hour < Constants.dayEndHour
    }

    /// Whether this time is during typical work hours (9 AM - 5 PM)
    var isWorkHours: Bool {
        let hour = Calendar.current.component(.hour, from: self)
        return hour >= Constants.workDayStartHour && hour < Constants.workDayEndHour
    }

    /// Whether this time is in the morning (6 AM - 12 PM)
    var isMorning: Bool {
        let hour = Calendar.current.component(.hour, from: self)
        return hour >= Constants.morningStartHour && hour < 12
    }

    // MARK: - Time Components

    /// Hour component (0-23)
    var hour: Int {
        Calendar.current.component(.hour, from: self)
    }

    /// Minute component (0-59)
    var minute: Int {
        Calendar.current.component(.minute, from: self)
    }

    /// Minutes since midnight
    var minutesSinceMidnight: Int {
        hour * 60 + minute
    }

    // MARK: - Date Manipulation

    /// Returns a new date with the specified time on the same day
    func withTime(hour: Int, minute: Int = 0) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: self) ?? self
    }

    /// Returns a new date with minutes added
    func addingMinutes(_ minutes: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: minutes, to: self) ?? self
    }

    /// Returns a new date with hours added
    func addingHours(_ hours: Int) -> Date {
        Calendar.current.date(byAdding: .hour, value: hours, to: self) ?? self
    }

    /// Returns a new date with days added
    func addingDays(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }

    /// Next occurrence of this time (tomorrow if time has passed)
    var nextOccurrence: Date {
        if self > Date() {
            return self
        }
        return addingDays(1)
    }

    // MARK: - Comparisons

    /// Whether this date is on the same day as another date
    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }

    /// Whether this date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Whether this date is tomorrow
    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(self)
    }

    /// Whether this date is in the past
    var isPast: Bool {
        self < Date()
    }

    /// Whether this date is in the future
    var isFuture: Bool {
        self > Date()
    }

    // MARK: - Rounding

    /// Rounds to the nearest time slot (e.g., 15 minutes)
    func roundedToSlot(granularityMinutes: Int = Constants.timeSlotGranularityMinutes) -> Date {
        let minutes = minutesSinceMidnight
        let rounded = (minutes + granularityMinutes / 2) / granularityMinutes * granularityMinutes
        return startOfDay.addingMinutes(rounded)
    }

    /// Rounds up to the next time slot
    func roundedUpToSlot(granularityMinutes: Int = Constants.timeSlotGranularityMinutes) -> Date {
        let minutes = minutesSinceMidnight
        let rounded = ((minutes + granularityMinutes - 1) / granularityMinutes) * granularityMinutes
        return startOfDay.addingMinutes(rounded)
    }

    /// Rounds down to the previous time slot
    func roundedDownToSlot(granularityMinutes: Int = Constants.timeSlotGranularityMinutes) -> Date {
        let minutes = minutesSinceMidnight
        let rounded = (minutes / granularityMinutes) * granularityMinutes
        return startOfDay.addingMinutes(rounded)
    }
}

// MARK: - TimeInterval Extensions

extension TimeInterval {
    /// Duration in minutes
    var minutes: Int {
        Int(self / 60)
    }

    /// Duration in hours (decimal)
    var hours: Double {
        self / 3600
    }

    /// Creates a TimeInterval from minutes
    static func minutes(_ minutes: Int) -> TimeInterval {
        TimeInterval(minutes * 60)
    }

    /// Creates a TimeInterval from hours
    static func hours(_ hours: Int) -> TimeInterval {
        TimeInterval(hours * 3600)
    }
}

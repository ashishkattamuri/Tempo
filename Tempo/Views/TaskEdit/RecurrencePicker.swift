import SwiftUI

/// UI component for selecting recurrence pattern (days of week) and frequency.
struct RecurrencePicker: View {
    @Binding var isRecurring: Bool
    @Binding var selectedDays: [Int]
    @Binding var endDate: Date?

    /// Computed frequency based on selected days
    var frequency: RecurrenceFrequency {
        // All 7 days selected = daily, otherwise weekly
        selectedDays.count == 7 ? .daily : .weekly
    }

    @State private var showEndDate = false

    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]
    private let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Repeat")
                .font(.headline)

            Toggle("Repeat on specific days", isOn: $isRecurring)

            if isRecurring {
                // Day selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select days")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        ForEach(0..<7, id: \.self) { day in
                            dayButton(day)
                        }
                    }

                    // Quick selection buttons
                    HStack(spacing: 12) {
                        quickSelectButton("Weekdays", days: [1, 2, 3, 4, 5])
                        quickSelectButton("Weekends", days: [0, 6])
                        quickSelectButton("Every day", days: [0, 1, 2, 3, 4, 5, 6])
                    }
                    .padding(.top, 4)
                }

                Divider()

                // End date (optional)
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Set end date", isOn: $showEndDate)
                        .onChange(of: showEndDate) { _, newValue in
                            if !newValue {
                                endDate = nil
                            } else if endDate == nil {
                                // Default to 4 weeks from now
                                endDate = Calendar.current.date(byAdding: .weekOfYear, value: 4, to: Date())
                            }
                        }

                    if showEndDate {
                        DatePicker(
                            "End date",
                            selection: Binding(
                                get: { endDate ?? Date() },
                                set: { endDate = $0 }
                            ),
                            in: Date()...,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                    }
                }

                // Summary
                if !selectedDays.isEmpty {
                    Text(recurrenceSummary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .onAppear {
            showEndDate = endDate != nil
        }
    }

    // MARK: - Day Button

    private func dayButton(_ day: Int) -> some View {
        let isSelected = selectedDays.contains(day)

        return Button(action: {
            if isSelected {
                selectedDays.removeAll { $0 == day }
            } else {
                selectedDays.append(day)
            }
        }) {
            Text(dayLabels[day])
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .white : .primary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color(.systemGray5))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dayNames[day])
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Quick Select Button

    private func quickSelectButton(_ label: String, days: [Int]) -> some View {
        let isSelected = Set(selectedDays) == Set(days)

        return Button(action: {
            selectedDays = days
        }) {
            Text(label)
                .font(.caption)
                .foregroundColor(isSelected ? .white : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.accentColor : Color(.systemGray5))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Summary

    private var recurrenceSummary: String {
        let sortedDays = selectedDays.sorted()

        var summary: String

        if frequency == .daily {
            if sortedDays == [1, 2, 3, 4, 5] {
                summary = "Daily on weekdays"
            } else if sortedDays == [0, 6] {
                summary = "Daily on weekends"
            } else if sortedDays == [0, 1, 2, 3, 4, 5, 6] {
                summary = "Every day"
            } else {
                let dayList = sortedDays.map { dayNames[$0] }.joined(separator: ", ")
                summary = "Daily on \(dayList)"
            }
        } else {
            // Weekly - times per week is the number of selected days
            let times = sortedDays.count
            if sortedDays == [1, 2, 3, 4, 5] {
                summary = "\(times)x per week on weekdays"
            } else if sortedDays == [0, 6] {
                summary = "\(times)x per week on weekends"
            } else if sortedDays == [0, 1, 2, 3, 4, 5, 6] {
                summary = "\(times)x per week (any day)"
            } else {
                let dayList = sortedDays.map { dayNames[$0] }.joined(separator: ", ")
                summary = "\(times)x per week on \(dayList)"
            }
        }

        if let end = endDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            summary += " until \(formatter.string(from: end))"
        }

        return summary
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var isRecurring = true
        @State private var selectedDays: [Int] = [1, 3, 5]
        @State private var endDate: Date? = nil

        var body: some View {
            RecurrencePicker(
                isRecurring: $isRecurring,
                selectedDays: $selectedDays,
                endDate: $endDate
            )
            .padding()
            .background(Color(.systemGroupedBackground))
        }
    }

    return PreviewWrapper()
}

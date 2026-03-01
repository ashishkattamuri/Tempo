import SwiftUI

/// Sheet shown when a newly saved task overlaps with the user's sleep schedule.
/// Offers to move it earlier (before bedtime) or to the next available slot after wake time.
struct SleepOverlapSheet: View {
    let item: ScheduleItem
    let earlierTime: Date?
    let nextAvailableTime: Date?
    let onMoveEarlier: () -> Void
    let onMoveToNextSlot: () -> Void
    let onKeep: () -> Void

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    var body: some View {
        VStack(spacing: 20) {

            // Header
            VStack(spacing: 8) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.indigo)

                Text("Overlaps With Sleep")
                    .font(.headline)

                Text("\"\(item.title)\" runs into your sleep window. Would you like to move it?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            // Action buttons
            VStack(spacing: 10) {
                if let earlier = earlierTime {
                    Button(action: onMoveEarlier) {
                        HStack {
                            Image(systemName: "arrow.left.circle.fill")
                            Text("Move earlier to \(timeFormatter.string(from: earlier))")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.indigo)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }

                if let nextSlot = nextAvailableTime {
                    Button(action: onMoveToNextSlot) {
                        HStack {
                            Image(systemName: "sunrise.fill")
                            Text("Move to \(dateFormatter.string(from: nextSlot)) at \(timeFormatter.string(from: nextSlot))")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.indigo.opacity(0.12))
                        .foregroundColor(.indigo)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: onKeep) {
                    Text("Keep as scheduled")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
}

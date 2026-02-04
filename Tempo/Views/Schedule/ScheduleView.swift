import SwiftUI
import SwiftData

/// Main daily schedule view - Structured-inspired timeline design.
struct ScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedDate: Date
    let onAddTask: () -> Void
    let onEditTask: (ScheduleItem) -> Void
    let onReshuffle: () -> Void

    @Query private var allItems: [ScheduleItem]
    @State private var showingDatePicker = false
    @State private var selectedSlotTime: Date?
    @State private var showingAddTask = false
    @State private var selectedItem: ScheduleItem?
    @State private var showingTaskDetail = false
    @State private var showingConflictResolution = false
    @State private var conflictResolutions: [ConflictResolution] = []
    @State private var savedItem: ScheduleItem?
    @State private var pendingConflictCheck: ScheduleItem?

    private let startHour = 5   // 5 AM
    private let endHour = 24    // Midnight
    private let hourHeight: CGFloat = 80
    private let reshuffleEngine = ReshuffleEngine()

    private var itemsForSelectedDate: [ScheduleItem] {
        allItems
            .filter { $0.scheduledDate.isSameDay(as: selectedDate) }
            .sorted { $0.startTime < $1.startTime }
    }

    private var hasIssues: Bool {
        guard !itemsForSelectedDate.isEmpty else { return false }
        let engine = ReshuffleEngine()
        return engine.hasIssues(items: itemsForSelectedDate, for: selectedDate)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Week calendar header
            weekCalendarHeader

            // Timeline content
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView {
                        timelineContent(geometry: geometry)
                            .padding(.bottom, 120)
                    }
                    .onAppear {
                        scrollToRelevantTime(proxy: proxy)
                    }
                    .onChange(of: selectedDate) { _, _ in
                        scrollToRelevantTime(proxy: proxy)
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Tempo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    selectedSlotTime = nil
                    onAddTask()
                }) {
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                }
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingAddTask) {
            TaskEditView(
                item: nil,
                selectedDate: selectedDate,
                defaultStartTime: selectedSlotTime,
                onSave: { newItem in
                    pendingConflictCheck = newItem
                    showingAddTask = false
                },
                onCancel: { showingAddTask = false }
            )
        }
        .onChange(of: showingAddTask) { _, isShowing in
            if !isShowing, let newItem = pendingConflictCheck {
                pendingConflictCheck = nil
                // Delay to allow sheet dismiss animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    checkForConflicts(newItem: newItem)
                }
            }
        }
        .sheet(isPresented: $showingConflictResolution) {
            if !conflictResolutions.isEmpty {
                ConflictResolutionSheet(
                    resolutions: conflictResolutions,
                    onResolve: { resolution, action in
                        applyResolution(resolution, action: action)
                    },
                    onDismiss: {
                        showingConflictResolution = false
                        conflictResolutions = []
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showingTaskDetail) {
            if let item = selectedItem {
                TaskDetailSheet(
                    item: item,
                    onEdit: {
                        showingTaskDetail = false
                        onEditTask(item)
                    },
                    onComplete: {
                        toggleCompletion(item)
                        showingTaskDetail = false
                    },
                    onDelete: {
                        modelContext.delete(item)
                        showingTaskDetail = false
                    }
                )
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Week Calendar Header

    private var weekCalendarHeader: some View {
        VStack(spacing: 12) {
            // Month and year - centered
            HStack {
                Text(selectedDate.formatted(.dateTime.month(.wide)))
                    .font(.title2)
                    .fontWeight(.bold)
                Text(selectedDate.formatted(.dateTime.year()))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.accentColor)

                Spacer()

                // Today button if not on current day
                if !selectedDate.isToday {
                    Button(action: { selectedDate = Date() }) {
                        Text("Today")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal)

            // Swipeable week days
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(extendedDays, id: \.self) { date in
                        weekDayButton(for: date)
                            .frame(width: 44)
                    }
                }
                .padding(.horizontal, 12)
            }
            .gesture(
                DragGesture()
                    .onEnded { value in
                        if value.translation.width < -50 {
                            // Swipe left - go forward
                            withAnimation {
                                if let newDate = Calendar.current.date(byAdding: .day, value: 7, to: selectedDate) {
                                    selectedDate = newDate
                                }
                            }
                        } else if value.translation.width > 50 {
                            // Swipe right - go back
                            withAnimation {
                                if let newDate = Calendar.current.date(byAdding: .day, value: -7, to: selectedDate) {
                                    selectedDate = newDate
                                }
                            }
                        }
                    }
            )

            // Progress indicator
            if !itemsForSelectedDate.isEmpty {
                HStack {
                    ProgressView(value: Double(completedCount), total: Double(itemsForSelectedDate.count))
                        .tint(.green)
                    Text("\(completedCount)/\(itemsForSelectedDate.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    // Extended days for scrolling (3 weeks: previous, current, next)
    private var extendedDays: [Date] {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))!
        let startDate = calendar.date(byAdding: .day, value: -7, to: startOfWeek)!
        return (0..<21).compactMap { calendar.date(byAdding: .day, value: $0, to: startDate) }
    }


    private func weekDayButton(for date: Date) -> some View {
        let isSelected = date.isSameDay(as: selectedDate)
        let isToday = date.isToday
        let hasItems = allItems.contains { $0.scheduledDate.isSameDay(as: date) }

        return Button(action: { selectedDate = date }) {
            VStack(spacing: 4) {
                Text(date.formatted(.dateTime.weekday(.narrow)))
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white : .secondary)

                Text(date.formatted(.dateTime.day()))
                    .font(.callout)
                    .fontWeight(isToday ? .bold : .medium)
                    .foregroundColor(isSelected ? .white : (isToday ? .accentColor : .primary))

                // Activity indicator
                HStack(spacing: 2) {
                    Circle()
                        .fill(hasItems ? Color.green : Color.clear)
                        .frame(width: 4, height: 4)
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Timeline Content

    private func timelineContent(geometry: GeometryProxy) -> some View {
        let totalHeight = CGFloat(endHour - startHour) * hourHeight
        let taskAreaWidth = geometry.size.width - 90 // Account for time labels and padding

        return HStack(alignment: .top, spacing: 0) {
            // Left column: Time labels with dots
            VStack(spacing: 0) {
                ForEach(startHour..<endHour, id: \.self) { hour in
                    timeLabel(for: hour)
                        .id(hour)
                }
            }
            .frame(width: 60)

            // Right column: Tasks area with dashed line
            ZStack(alignment: .topLeading) {
                // Tappable hour slots (behind everything)
                VStack(spacing: 0) {
                    ForEach(startHour..<endHour, id: \.self) { hour in
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: hourHeight)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                let tappedTime = selectedDate.startOfDay.withTime(hour: hour)
                                selectedSlotTime = tappedTime
                                showingAddTask = true
                            }
                    }
                }

                // Vertical dashed line
                Path { path in
                    path.move(to: CGPoint(x: 1, y: 0))
                    path.addLine(to: CGPoint(x: 1, y: totalHeight))
                }
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .foregroundColor(Color(.systemGray4))
                .allowsHitTesting(false)

                // Hour grid lines (subtle)
                ForEach(startHour..<endHour, id: \.self) { hour in
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 0.5)
                        .offset(y: CGFloat(hour - startHour) * hourHeight)
                        .allowsHitTesting(false)
                }

                // Gap indicators
                ForEach(calculateGaps().filter { $0.durationMinutes >= 30 && $0.durationMinutes <= 300 }, id: \.start) { gap in
                    gapIndicatorView(gap: gap)
                        .frame(width: taskAreaWidth - 20)
                        .offset(x: 12, y: yPositionFromTime(gap.start) + 10)
                }

                // Task blocks - positioned absolutely
                ForEach(itemsForSelectedDate) { item in
                    taskCard(for: item)
                        .frame(width: taskAreaWidth - 20)
                        .frame(height: max(60, CGFloat(item.durationMinutes) / 60.0 * hourHeight - 8))
                        .offset(x: 12, y: yPositionFromTime(item.startTime) + 4)
                }

                // Current time indicator
                if selectedDate.isToday {
                    currentTimeIndicator
                        .offset(y: yPositionFromCurrentTime())
                        .allowsHitTesting(false)
                }
            }
            .frame(height: totalHeight)
        }
        .padding(.horizontal, 12)
    }

    private func timeLabel(for hour: Int) -> some View {
        let isCurrentHour = selectedDate.isToday && Date().hour == hour

        return HStack(spacing: 4) {
            Text(formatHour(hour))
                .font(.caption)
                .fontWeight(isCurrentHour ? .bold : .regular)
                .foregroundColor(isCurrentHour ? .accentColor : .secondary)
                .frame(width: 40, alignment: .trailing)

            // Dot on timeline
            Circle()
                .fill(isCurrentHour ? Color.accentColor : Color(.systemGray4))
                .frame(width: isCurrentHour ? 8 : 5, height: isCurrentHour ? 8 : 5)
        }
        .frame(height: hourHeight, alignment: .top)
        .padding(.top, 0)
    }

    private var currentTimeIndicator: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
            Rectangle()
                .fill(Color.red)
                .frame(height: 2)
        }
    }

    private func yPositionFromTime(_ time: Date) -> CGFloat {
        let minutesSinceStart = (time.hour - startHour) * 60 + time.minute
        return CGFloat(minutesSinceStart) / 60.0 * hourHeight
    }

    private func yPositionFromCurrentTime() -> CGFloat {
        let now = Date()
        let minutesSinceStart = (now.hour - startHour) * 60 + now.minute
        return CGFloat(minutesSinceStart) / 60.0 * hourHeight
    }

    // MARK: - Gap Indicators

    private func gapStartingAtHour(_ hour: Int) -> TimeGap? {
        let gaps = calculateGaps()
        return gaps.first { $0.start.hour == hour && $0.durationMinutes >= 30 && $0.durationMinutes <= 300 }
    }

    private func gapIndicatorView(gap: TimeGap) -> some View {
        let friendlyMessage = gapMessage(for: gap.durationMinutes)

        return Button(action: {
            selectedSlotTime = gap.start
            showingAddTask = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(.accentColor.opacity(0.6))

                Text(friendlyMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundColor(Color(.systemGray4))
            )
        }
        .buttonStyle(.plain)
    }

    private func gapMessage(for minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60

        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m available"
        } else if hours > 0 {
            return "\(hours)h available"
        } else {
            return "\(mins)m available"
        }
    }

    private func calculateGaps() -> [TimeGap] {
        var gaps: [TimeGap] = []
        let dayStart = selectedDate.startOfDay.withTime(hour: startHour)
        let dayEnd = selectedDate.startOfDay.withTime(hour: endHour)

        var currentTime = dayStart

        for item in itemsForSelectedDate {
            if item.startTime > currentTime {
                let gapMinutes = Int(item.startTime.timeIntervalSince(currentTime) / 60)
                if gapMinutes > 0 {
                    gaps.append(TimeGap(start: currentTime, durationMinutes: gapMinutes))
                }
            }
            currentTime = max(currentTime, item.endTime)
        }

        if currentTime < dayEnd {
            let gapMinutes = Int(dayEnd.timeIntervalSince(currentTime) / 60)
            if gapMinutes > 0 {
                gaps.append(TimeGap(start: currentTime, durationMinutes: gapMinutes))
            }
        }

        return gaps
    }

    // MARK: - Task Card

    private func taskCard(for item: ScheduleItem) -> some View {
        let isInProgress = selectedDate.isToday && item.startTime <= Date() && item.endTime > Date()
        let remainingMinutes = isInProgress ? Int(item.endTime.timeIntervalSince(Date()) / 60) : nil

        return Button(action: {
            selectedItem = item
            showingTaskDetail = true
        }) {
            HStack(alignment: .top, spacing: 10) {
                // Duration bar on left (spans full height)
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [item.category.color, item.category.color.opacity(0.2)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 5)

                // Circular icon
                ZStack {
                    Circle()
                        .fill(item.category.color.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: item.category.iconName)
                        .font(.system(size: 16))
                        .foregroundColor(item.category.color)
                }

                // Content
                VStack(alignment: .leading, spacing: 3) {
                    if let remaining = remainingMinutes {
                        Text("\(remaining) min remaining")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.accentColor)
                    } else {
                        Text(formatTimeRange(item))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(item.isCompleted ? .secondary : .primary)
                        .strikethrough(item.isCompleted)
                        .lineLimit(3)

                    if item.durationMinutes >= 60 {
                        Text("\(item.durationMinutes) min")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Checkbox
                Button(action: { toggleCompletion(item) }) {
                    Circle()
                        .stroke(item.isCompleted ? Color.green : item.category.color, lineWidth: 2)
                        .frame(width: 24, height: 24)
                        .overlay(
                            item.isCompleted ?
                            Image(systemName: "checkmark")
                                .font(.caption2.bold())
                                .foregroundColor(.green)
                            : nil
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(item.category.color.opacity(item.isCompleted ? 0.05 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(item.category.color.opacity(0.2), lineWidth: 1)
            )
            .opacity(item.isCompleted ? 0.7 : 1.0)
        }
        .buttonStyle(.plain)
    }

    private func formatTimeRange(_ item: ScheduleItem) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let start = formatter.string(from: item.startTime)
        let end = formatter.string(from: item.endTime)
        return "\(start) - \(end)"
    }

    // MARK: - Helpers

    private var completedCount: Int {
        itemsForSelectedDate.filter { $0.isCompleted }.count
    }

    private func formatHour(_ hour: Int) -> String {
        if hour == 0 || hour == 24 {
            return "12am"
        } else if hour == 12 {
            return "12pm"
        } else if hour > 12 {
            return "\(hour - 12)pm"
        } else {
            return "\(hour)am"
        }
    }

    private func timeFromYPosition(_ y: CGFloat) -> Date {
        let totalMinutes = Int(y / hourHeight * 60)
        let roundedMinutes = (totalMinutes / 15) * 15
        let hour = startHour + (roundedMinutes / 60)
        let minute = roundedMinutes % 60
        return selectedDate.startOfDay.withTime(hour: min(hour, endHour - 1), minute: minute)
    }

    private func toggleCompletion(_ item: ScheduleItem) {
        item.isCompleted.toggle()
        item.touch()
    }

    private func scrollToRelevantTime(proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if selectedDate.isToday {
                let targetHour = max(startHour, Date().hour - 1)
                withAnimation {
                    proxy.scrollTo(targetHour, anchor: .top)
                }
            } else if let firstItem = itemsForSelectedDate.first {
                let targetHour = max(startHour, firstItem.startTime.hour - 1)
                withAnimation {
                    proxy.scrollTo(targetHour, anchor: .top)
                }
            }
        }
    }

    // MARK: - Conflict Detection

    private func checkForConflicts(newItem: ScheduleItem) {
        // Get items for the same day as the new item, excluding the new item itself
        let existingItems = allItems.filter { item in
            item.id != newItem.id &&
            item.scheduledDate.isSameDay(as: newItem.scheduledDate) &&
            !item.isCompleted
        }

        // Find overlapping items
        let conflicts = existingItems.filter { existing in
            newItem.overlaps(with: existing)
        }

        if !conflicts.isEmpty {
            savedItem = newItem
            // Pass all items so the engine can find truly empty slots
            conflictResolutions = reshuffleEngine.suggestResolution(
                newItem: newItem,
                conflictingItems: conflicts,
                allItems: Array(allItems)
            )
            showingConflictResolution = true
        }
    }

    private func applyResolution(_ resolution: ConflictResolution, action: ConflictAction) {
        // Find the actual managed objects from allItems
        guard let conflictingItem = allItems.first(where: { $0.id == resolution.conflictingItem.id }) else {
            return
        }

        switch action {
        case .moveConflicting(let newTime):
            conflictingItem.startTime = newTime
            conflictingItem.touch()
            try? modelContext.save()

        case .moveNew(let newTime):
            if let newItemId = savedItem?.id,
               let newItem = allItems.first(where: { $0.id == newItemId }) {
                newItem.startTime = newTime
                newItem.touch()
                try? modelContext.save()
            }

        case .keepBoth:
            // Do nothing - keep overlapping
            break

        case .deleteConflicting:
            modelContext.delete(conflictingItem)
            try? modelContext.save()
        }

        // Remove this resolution from the list
        conflictResolutions.removeAll { $0.id == resolution.id }

        // If no more resolutions, dismiss
        if conflictResolutions.isEmpty {
            showingConflictResolution = false
            savedItem = nil
        }
    }
}

// MARK: - Conflict Action

enum ConflictAction {
    case moveConflicting(to: Date)
    case moveNew(to: Date)
    case keepBoth
    case deleteConflicting
}

// MARK: - Time Gap Model

struct TimeGap {
    let start: Date
    let durationMinutes: Int
}

// MARK: - Task Detail Sheet

struct TaskDetailSheet: View {
    let item: ScheduleItem
    let onEdit: () -> Void
    let onComplete: () -> Void
    let onDelete: () -> Void

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yy, h:mm a"
        return formatter
    }()

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(item.category.color.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: item.category.iconName)
                        .font(.system(size: 18))
                        .foregroundColor(item.category.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(timeFormatter.string(from: item.startTime)) (\(item.durationMinutes) min)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(item.title)
                        .font(.headline)
                }

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Divider()

            // Quick actions
            HStack(spacing: 12) {
                quickActionButton(
                    icon: "trash",
                    label: "Delete",
                    color: .red,
                    action: onDelete
                )

                quickActionButton(
                    icon: "doc.on.doc",
                    label: "Duplicate",
                    color: .blue,
                    action: {} // TODO: Implement
                )

                quickActionButton(
                    icon: "checkmark",
                    label: "Complete",
                    color: .green,
                    action: onComplete
                )
            }
            .padding(.horizontal)

            // Edit button
            Button(action: onEdit) {
                HStack {
                    Image(systemName: "square.and.pencil")
                    Text("Edit Task")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding(.horizontal)

            // Focus button
            Button(action: {}) {
                HStack {
                    Image(systemName: "scope")
                    Text("Focus Now")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accentColor)
                .cornerRadius(12)
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    private func quickActionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)

                Text(label)
                    .font(.caption)
                    .foregroundColor(color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Conflict Resolution Sheet

struct ConflictResolutionSheet: View {
    let resolutions: [ConflictResolution]
    let onResolve: (ConflictResolution, ConflictAction) -> Void
    let onDismiss: () -> Void

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.orange)

                        Text("Schedule Conflict")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("The new task overlaps with existing tasks. How would you like to resolve this?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()

                    // Conflict cards
                    ForEach(resolutions) { resolution in
                        conflictCard(resolution)
                    }
                }
                .padding()
            }
            .navigationTitle("Resolve Conflict")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Keep Both") {
                        for resolution in resolutions {
                            onResolve(resolution, .keepBoth)
                        }
                        onDismiss()
                    }
                }
            }
        }
    }

    private func conflictCard(_ resolution: ConflictResolution) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Conflict description
            HStack(spacing: 12) {
                // New task
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(resolution.newItem.category.color.opacity(0.2))
                            .frame(width: 40, height: 40)
                        Image(systemName: resolution.newItem.category.iconName)
                            .foregroundColor(resolution.newItem.category.color)
                    }
                    Text(resolution.newItem.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    Text(timeFormatter.string(from: resolution.newItem.startTime))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                Image(systemName: "arrow.left.arrow.right")
                    .foregroundColor(.orange)

                // Conflicting task
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(resolution.conflictingItem.category.color.opacity(0.2))
                            .frame(width: 40, height: 40)
                        Image(systemName: resolution.conflictingItem.category.iconName)
                            .foregroundColor(resolution.conflictingItem.category.color)
                    }
                    Text(resolution.conflictingItem.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    Text(timeFormatter.string(from: resolution.conflictingItem.startTime))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            // Reason
            Text(resolution.reason)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .cornerRadius(6)

            // Action buttons based on suggestion
            VStack(spacing: 10) {
                switch resolution.suggestion {
                case .moveConflicting(let newTime):
                    Button(action: {
                        onResolve(resolution, .moveConflicting(to: newTime))
                    }) {
                        HStack {
                            Image(systemName: "arrow.right")
                            Text("Move \"\(resolution.conflictingItem.title)\" to \(timeFormatter.string(from: newTime))")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .cornerRadius(10)
                    }

                    Button(action: {
                        onResolve(resolution, .deleteConflicting)
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Remove \"\(resolution.conflictingItem.title)\"")
                        }
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                    }

                case .moveNew(let newTime):
                    Button(action: {
                        onResolve(resolution, .moveNew(to: newTime))
                    }) {
                        HStack {
                            Image(systemName: "arrow.right")
                            Text("Move new task to \(timeFormatter.string(from: newTime))")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .cornerRadius(10)
                    }

                case .userDecision(let moveConflictingTo, let moveNewTo):
                    Button(action: {
                        onResolve(resolution, .moveConflicting(to: moveConflictingTo))
                    }) {
                        HStack {
                            Image(systemName: "arrow.right")
                            Text("Move \"\(resolution.conflictingItem.title)\" to \(timeFormatter.string(from: moveConflictingTo))")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .cornerRadius(10)
                    }

                    Button(action: {
                        onResolve(resolution, .moveNew(to: moveNewTo))
                    }) {
                        HStack {
                            Image(systemName: "arrow.right")
                            Text("Move \"\(resolution.newItem.title)\" to \(timeFormatter.string(from: moveNewTo))")
                        }
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Previews

#Preview("Schedule View") {
    NavigationStack {
        ScheduleView(
            selectedDate: .constant(Date()),
            onAddTask: {},
            onEditTask: { _ in },
            onReshuffle: {}
        )
    }
    .modelContainer(for: ScheduleItem.self, inMemory: true)
}

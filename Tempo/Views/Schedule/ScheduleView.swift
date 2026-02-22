import SwiftUI
import SwiftData

/// Wrapper to make conflict resolutions identifiable for sheet presentation
struct ConflictResolutionData: Identifiable {
    let id = UUID()
    let resolutions: [ConflictResolution]
}

/// Main daily schedule view - Structured-inspired timeline design.
struct ScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedDate: Date
    let onAddTask: () -> Void
    let onEditTask: (ScheduleItem) -> Void
    let onReshuffle: () -> Void
    var onSettings: (() -> Void)? = nil

    @Query private var allItems: [ScheduleItem]
    @State private var showingDatePicker = false
    @State private var selectedSlotTime: Date?
    @State private var showingAddTask = false
    @State private var selectedItem: ScheduleItem?
    @State private var conflictData: ConflictResolutionData?
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

    /// Calculate layout info for overlapping tasks (side-by-side display)
    private var taskLayoutInfo: [UUID: (column: Int, totalColumns: Int)] {
        let items = itemsForSelectedDate
        guard !items.isEmpty else { return [:] }

        var layoutInfo: [UUID: (column: Int, totalColumns: Int)] = [:]
        var overlapGroups: [[ScheduleItem]] = []

        // Group overlapping items
        for item in items {
            var addedToGroup = false
            for i in 0..<overlapGroups.count {
                // Check if this item overlaps with any item in the group
                let groupOverlaps = overlapGroups[i].contains { existing in
                    item.startTime < existing.endTime && item.endTime > existing.startTime
                }
                if groupOverlaps {
                    overlapGroups[i].append(item)
                    addedToGroup = true
                    break
                }
            }
            if !addedToGroup {
                overlapGroups.append([item])
            }
        }

        // Merge groups that have overlapping items
        var mergedGroups: [[ScheduleItem]] = []
        for group in overlapGroups {
            var merged = false
            for i in 0..<mergedGroups.count {
                let hasOverlap = group.contains { item in
                    mergedGroups[i].contains { existing in
                        item.startTime < existing.endTime && item.endTime > existing.startTime
                    }
                }
                if hasOverlap {
                    mergedGroups[i].append(contentsOf: group)
                    merged = true
                    break
                }
            }
            if !merged {
                mergedGroups.append(group)
            }
        }

        // Assign columns within each group
        for group in mergedGroups {
            let sortedGroup = group.sorted { $0.startTime < $1.startTime }
            var columns: [[ScheduleItem]] = []

            for item in sortedGroup {
                var placed = false
                for colIndex in 0..<columns.count {
                    // Check if item can fit in this column (no overlap with last item in column)
                    if let lastInColumn = columns[colIndex].last {
                        if item.startTime >= lastInColumn.endTime {
                            columns[colIndex].append(item)
                            layoutInfo[item.id] = (column: colIndex, totalColumns: 0) // totalColumns set later
                            placed = true
                            break
                        }
                    }
                }
                if !placed {
                    columns.append([item])
                    layoutInfo[item.id] = (column: columns.count - 1, totalColumns: 0)
                }
            }

            // Update totalColumns for all items in this group
            let totalCols = columns.count
            for item in sortedGroup {
                if let info = layoutInfo[item.id] {
                    layoutInfo[item.id] = (column: info.column, totalColumns: totalCols)
                }
            }
        }

        return layoutInfo
    }

    private var hasIssues: Bool {
        guard !itemsForSelectedDate.isEmpty else { return false }
        let engine = ReshuffleEngine()
        return engine.hasIssues(items: itemsForSelectedDate, for: selectedDate)
    }

    /// True when today is selected and at least one incomplete task's start time has passed.
    private var hasPastIncompleteItems: Bool {
        guard selectedDate.isToday else { return false }
        let now = Date()
        return itemsForSelectedDate.contains { !$0.isCompleted && $0.startTime < now }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Week calendar header
            weekCalendarHeader

            // "Fix My Day" banner — visible when today has past incomplete tasks
            if hasPastIncompleteItems {
                fixMyDayBanner
            }

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
            ToolbarItem(placement: .topBarLeading) {
                if let onSettings = onSettings {
                    Button(action: onSettings) {
                        Image(systemName: "gearshape")
                    }
                }
            }

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
        .sheet(item: $conflictData) { data in
            ConflictResolutionSheet(
                resolutions: data.resolutions,
                onResolve: { resolution, action in
                    applyResolution(resolution, action: action)
                },
                onDismiss: {
                    conflictData = nil
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedItem) { item in
            TaskDetailSheet(
                item: item,
                onEdit: {
                    selectedItem = nil
                    onEditTask(item)
                },
                onComplete: {
                    toggleCompletion(item)
                    selectedItem = nil
                },
                onDelete: {
                    modelContext.delete(item)
                    selectedItem = nil
                }
            )
            .presentationDetents([.height(280)])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Week Calendar Header

    private var weekCalendarHeader: some View {
        VStack(spacing: 12) {
            // Month and year - centered
            HStack {
                Text((currentWeekDays.last ?? selectedDate).formatted(.dateTime.month(.wide)))
                    .font(.title2)
                    .fontWeight(.bold)
                Text((currentWeekDays.last ?? selectedDate).formatted(.dateTime.year()))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.accentColor)

                Spacer()

                // Today button when today is not in the currently displayed week
                if !currentWeekDays.contains(where: { $0.isToday }) {
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

            // Week strip — always shows the 7 days of the current week.
            // DragGesture detects a horizontal swipe and advances selectedDate by one week.
            // selectedDate is the sole source of truth; month label and today button derive
            // directly from currentWeekDays, so they update the moment selectedDate changes.
            HStack(spacing: 0) {
                ForEach(currentWeekDays, id: \.self) { date in
                    weekDayButton(for: date)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 72)
            .gesture(
                DragGesture(minimumDistance: 30, coordinateSpace: .local)
                    .onEnded { value in
                        // Ignore mostly-vertical drags (let the timeline scroll handle those)
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        let cal = Calendar.current
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if value.translation.width < 0 {
                                selectedDate = cal.date(byAdding: .weekOfYear, value: 1, to: currentWeekSunday) ?? selectedDate
                            } else {
                                selectedDate = cal.date(byAdding: .weekOfYear, value: -1, to: currentWeekSunday) ?? selectedDate
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

    // MARK: - Fix My Day Banner

    private var fixMyDayBanner: some View {
        Button(action: onReshuffle) {
            HStack(spacing: 12) {
                Image(systemName: "wand.and.stars")
                    .font(.subheadline)
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Some earlier tasks are unchecked")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text("Reschedule or mark them as done")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.accentColor)
        }
        .buttonStyle(.plain)
    }

    // Sunday of the week containing selectedDate.
    private var currentWeekSunday: Date {
        let calendar = Calendar.current
        return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))!
    }

    // The 7 days (Sun–Sat) of the current week. Everything — month label, today button,
    // the strip itself — derives from this so they all stay in sync automatically.
    private var currentWeekDays: [Date] {
        let calendar = Calendar.current
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: currentWeekSunday) }
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

                // Task blocks - positioned absolutely with side-by-side for overlaps
                ForEach(itemsForSelectedDate) { item in
                    let layout = taskLayoutInfo[item.id] ?? (column: 0, totalColumns: 1)
                    let baseWidth = taskAreaWidth - 20
                    let itemWidth = layout.totalColumns > 1 ? (baseWidth - CGFloat(layout.totalColumns - 1) * 4) / CGFloat(layout.totalColumns) : baseWidth
                    let xOffset: CGFloat = 12 + CGFloat(layout.column) * (itemWidth + 4)
                    // Height exactly proportional to duration - no adjustments
                    let itemHeight = CGFloat(item.durationMinutes) / 60.0 * hourHeight

                    taskCard(for: item)
                        .frame(width: itemWidth)
                        .frame(height: itemHeight)
                        .clipped() // Clip any overflow from internal padding
                        .offset(x: xOffset, y: yPositionFromTime(item.startTime))
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
        let isCompact = item.durationMinutes <= 30

        return Button(action: {
            selectedItem = item
        }) {
            HStack(alignment: .center, spacing: isCompact ? 6 : 10) {
                // Duration bar on left (spans full height)
                RoundedRectangle(cornerRadius: 2)
                    .fill(item.category.color)
                    .frame(width: 4)

                // Circular icon - smaller for compact view
                if !isCompact {
                    ZStack {
                        Circle()
                            .fill(item.category.color.opacity(0.15))
                            .frame(width: 40, height: 40)

                        Image(systemName: item.category.iconName)
                            .font(.system(size: 16))
                            .foregroundColor(item.category.color)
                    }
                }

                // Content - simplified for compact view
                if isCompact {
                    // Compact: single line with title and time
                    HStack(spacing: 6) {
                        Image(systemName: item.category.iconName)
                            .font(.system(size: 12))
                            .foregroundColor(item.category.color)

                        Text(item.title)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(item.isCompleted ? .secondary : .primary)
                            .strikethrough(item.isCompleted)
                            .lineLimit(1)

                        Spacer()

                        Text(formatTimeRange(item))
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        // Checkbox - smaller for compact view
                        Button(action: { toggleCompletion(item) }) {
                            Circle()
                                .stroke(item.isCompleted ? Color.green : item.category.color, lineWidth: 1.5)
                                .frame(width: 18, height: 18)
                                .overlay(
                                    item.isCompleted ?
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.green)
                                    : nil
                                )
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    // Full view
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

                    // Checkbox - only in full view
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
            }
            .padding(.horizontal, isCompact ? 6 : 10)
            .padding(.vertical, isCompact ? 4 : 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isCompact ? .center : .topLeading)
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
            let resolutions = reshuffleEngine.suggestResolution(
                newItem: newItem,
                conflictingItems: conflicts,
                allItems: Array(allItems)
            )
            conflictData = ConflictResolutionData(resolutions: resolutions)
        }
    }

    private func applyResolution(_ resolution: ConflictResolution, action: ConflictAction) {
        switch action {
        case .moveConflicting(let newTime):
            // Find and move the conflicting item
            if let conflictingItem = allItems.first(where: { $0.id == resolution.conflictingItem.id }) {
                conflictingItem.startTime = newTime
                // CRITICAL: Also update scheduledDate if moving to a different day
                conflictingItem.scheduledDate = Calendar.current.startOfDay(for: newTime)
                conflictingItem.touch()
                try? modelContext.save()
            }

        case .moveNew(let newTime):
            // Move the new item - this resolves ALL conflicts at once
            if let newItemId = savedItem?.id,
               let newItem = allItems.first(where: { $0.id == newItemId }) {
                newItem.startTime = newTime
                // CRITICAL: Also update scheduledDate if moving to a different day
                newItem.scheduledDate = Calendar.current.startOfDay(for: newTime)
                newItem.touch()
                try? modelContext.save()
            }
            // Clear ALL resolutions and dismiss since moving the new item fixes everything
            conflictData = nil
            savedItem = nil
            return

        case .keepBoth:
            // Just skip this conflict
            break

        case .deleteConflicting:
            if let conflictingItem = allItems.first(where: { $0.id == resolution.conflictingItem.id }) {
                modelContext.delete(conflictingItem)
                try? modelContext.save()
            }
        }

        // Recalculate remaining conflicts with updated schedule
        recalculateRemainingConflicts(excludingResolved: resolution)
    }

    private func recalculateRemainingConflicts(excludingResolved resolved: ConflictResolution) {
        guard let newItem = savedItem,
              let actualNewItem = allItems.first(where: { $0.id == newItem.id }),
              let currentData = conflictData else {
            conflictData = nil
            savedItem = nil
            return
        }

        // Fetch fresh items from the model context to get the latest state
        let freshItems = fetchFreshItems(for: actualNewItem.scheduledDate)

        // Get remaining conflicting item IDs (exclude the one we just resolved)
        let remainingConflictIds = currentData.resolutions
            .filter { $0.id != resolved.id }
            .map { $0.conflictingItem.id }

        // Check which items still actually conflict with the new item (using fresh data)
        let stillConflicting = freshItems.filter { item in
            remainingConflictIds.contains(item.id) &&
            !item.isCompleted &&
            actualNewItem.overlaps(with: item)
        }

        if stillConflicting.isEmpty {
            // No more conflicts - we're done
            conflictData = nil
            savedItem = nil
        } else {
            // Recalculate resolutions with fresh slot suggestions using fresh items
            let resolutions = reshuffleEngine.suggestResolution(
                newItem: actualNewItem,
                conflictingItems: stillConflicting,
                allItems: freshItems
            )
            conflictData = ConflictResolutionData(resolutions: resolutions)
        }
    }

    private func fetchFreshItems(for date: Date) -> [ScheduleItem] {
        // Fetch items for a week to ensure we see moved items on future days
        let startOfDay = date.startOfDay
        let endOfWeek = Calendar.current.date(byAdding: .day, value: 7, to: date)?.endOfDay ?? date.endOfDay

        let predicate = #Predicate<ScheduleItem> { item in
            item.scheduledDate >= startOfDay && item.scheduledDate <= endOfWeek
        }

        let descriptor = FetchDescriptor<ScheduleItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startTime)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            return Array(allItems.filter { $0.scheduledDate.isSameDay(as: date) })
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

    private let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter
    }()

    /// Format time, showing date if it's not today
    private func formatTime(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return timeFormatter.string(from: date)
        } else {
            return dateTimeFormatter.string(from: date)
        }
    }

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
                            Text("Move \"\(resolution.conflictingItem.title)\" to \(formatTime(newTime))")
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
                            Text("Move new task to \(formatTime(newTime))")
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
                            Text("Move \"\(resolution.conflictingItem.title)\" to \(formatTime(moveConflictingTo))")
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
                            Text("Move \"\(resolution.newItem.title)\" to \(formatTime(moveNewTo))")
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

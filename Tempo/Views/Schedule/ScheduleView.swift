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
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var sleepManager: SleepManager
    @EnvironmentObject private var focusBlockManager: FocusBlockManager
    @Binding var selectedDate: Date
    let onAddTask: () -> Void
    let onEditTask: (ScheduleItem) -> Void
    let onReshuffle: () -> Void
    var onSettings: (() -> Void)? = nil

    @Query private var allItems: [ScheduleItem]
    @Query(sort: \HabitDefinition.createdAt) private var habitDefs: [HabitDefinition]
    @Query(sort: \GoalDefinition.createdAt) private var goalDefs: [GoalDefinition]
    @Query(sort: \TaskDefinition.createdAt) private var taskDefs: [TaskDefinition]
    @State private var showingDatePicker = false
    @State private var selectedSlotTime: Date?
    @State private var nowPulse = false
    @State private var showingAddTask = false
    @State private var selectedItem: ScheduleItem?
    @State private var conflictData: ConflictResolutionData?
    @State private var savedItem: ScheduleItem?
    @State private var pendingConflictCheck: ScheduleItem?

    // Recommendation confirmation sheet
    @State private var pendingSchedule: PendingScheduleInfo?

    // Sleep overlap state (for tasks created via timeline tap)
    @State private var sleepOverlapItem: ScheduleItem?
    @State private var sleepEarlierSuggestion: Date?
    @State private var sleepNextSlotSuggestion: Date?

    private let reshuffleEngine = ReshuffleEngine()

    // MARK: - Timeline Row Model

    enum TimelineRow: Identifiable {
        case task(ScheduleItem)
        case nowIndicator
        case freeSlot(TimeGap)
        case wakeUp(Date)
        case windDown(Date)

        var id: String {
            switch self {
            case .task(let item):   return "task-\(item.id)"
            case .nowIndicator:     return "now"
            case .freeSlot(let g):  return "gap-\(g.start.timeIntervalSince1970)"
            case .wakeUp(let d):    return "wakeup-\(d.timeIntervalSince1970)"
            case .windDown(let d):  return "winddown-\(d.timeIntervalSince1970)"
            }
        }
    }

    /// Merged and sorted rows for the timeline list.
    private var timelineRows: [TimelineRow] {
        let items = itemsForSelectedDate
        var rows: [TimelineRow] = []
        let now = Date()
        var nowInserted = false

        // Compute sleep marker times for the selected date
        var wakeUpTime: Date? = nil
        var windDownTime: Date? = nil
        if sleepManager.isEnabled, let schedule = sleepManager.sleepSchedule {
            let cal = Calendar.current
            var wakeComps = cal.dateComponents([.year, .month, .day], from: selectedDate)
            wakeComps.hour = schedule.wakeHour
            wakeComps.minute = schedule.wakeMinute
            wakeUpTime = cal.date(from: wakeComps)

            var bedComps = cal.dateComponents([.year, .month, .day], from: selectedDate)
            bedComps.hour = schedule.bedtimeHour
            bedComps.minute = schedule.bedtimeMinute
            if let bedtime = cal.date(from: bedComps) {
                windDownTime = bedtime.addingTimeInterval(-Double(schedule.bufferMinutes * 60))
            }
        }
        var wakeUpInserted = false
        var windDownInserted = false

        let dayStart = wakeUpTime ?? selectedDate.startOfDay.withTime(hour: 6)
        let dayEnd   = windDownTime ?? selectedDate.startOfDay.withTime(hour: 22)

        for (i, item) in items.enumerated() {
            // Insert wake up marker before the first task that starts at or after wake time
            if let wakeUp = wakeUpTime, !wakeUpInserted, item.startTime >= wakeUp {
                rows.append(.wakeUp(wakeUp))
                wakeUpInserted = true
            }

            // Wind down must be inserted before the now indicator so chronological
            // order is preserved (e.g. wind-down at 9:30 PM comes before now at 10:29 PM).
            if let windDown = windDownTime, !windDownInserted, item.startTime > windDown {
                rows.append(.windDown(windDown))
                windDownInserted = true
            }

            // Only insert a standalone now indicator before a future task.
            // If the current item is in-progress, skip the row — the task card
            // itself renders the now line as an overlay.
            let itemIsInProgress = item.startTime <= now && item.endTime > now
            if !nowInserted && selectedDate.isToday && !itemIsInProgress && item.startTime > now {
                rows.append(.nowIndicator)
                nowInserted = true
            }
            if itemIsInProgress && selectedDate.isToday {
                nowInserted = true
            }

            // Find end of last task (scan backward so sleep/now markers don't confuse prevEnd)
            let prevEnd: Date = {
                for row in rows.reversed() {
                    if case .task(let p) = row { return p.endTime }
                }
                return dayStart
            }()
            let gapMinutes = Int(item.startTime.timeIntervalSince(prevEnd) / 60)
            let isFutureGap = !selectedDate.isToday || item.startTime > now
            if gapMinutes >= 30 && isFutureGap {
                rows.append(.freeSlot(TimeGap(start: prevEnd, durationMinutes: gapMinutes)))
            }

            rows.append(.task(item))

            // After last item, insert now indicator if still not inserted
            if !nowInserted && selectedDate.isToday && i == items.count - 1 {
                rows.append(.nowIndicator)
                nowInserted = true
            }
        }

        // Append wake-up marker if it hasn't been inserted yet
        if let wakeUp = wakeUpTime, !wakeUpInserted { rows.append(.wakeUp(wakeUp)) }

        // End-of-day free slot: last task → dayEnd (must come before wind-down marker)
        if let lastTask = items.last {
            let endGapMins = Int(dayEnd.timeIntervalSince(lastTask.endTime) / 60)
            let isFuture = !selectedDate.isToday || dayEnd > now
            if endGapMins >= 30 && isFuture {
                rows.append(.freeSlot(TimeGap(start: lastTask.endTime, durationMinutes: endGapMins)))
            }
        }

        // Wind-down marker goes after the free slot so it bookends the evening
        if let windDown = windDownTime, !windDownInserted { rows.append(.windDown(windDown)) }

        // If no items and today, show now indicator
        if items.isEmpty && selectedDate.isToday {
            rows.append(.nowIndicator)
        }

        return rows
    }

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

    /// Free slots available for the selected date (empty day = entire day is free).
    private var hasFreeSlots: Bool {
        if itemsForSelectedDate.isEmpty { return true }
        return timelineRows.contains { if case .freeSlot = $0 { return true }; return false }
    }

    /// Pending library tasks sorted by deadline (soonest first, nil last), then oldest created.
    private var taskRecommendations: [TaskDefinition] {
        guard selectedDate.isToday || !selectedDate.isPast, hasFreeSlots else { return [] }
        let scheduledIds = Set(allItems.compactMap { $0.taskDefinitionId })
        return taskDefs
            .filter { !$0.isCompleted && !scheduledIds.contains($0.id) }
            .sorted {
                switch ($0.deadline, $1.deadline) {
                case (nil, nil):   return $0.createdAt < $1.createdAt
                case (nil, _):     return false
                case (_, nil):     return true
                case (let a, let b): return a! < b!
                }
            }
            .map { $0 }
    }

    /// True when today is selected and at least one incomplete task's start time has passed.
    private var hasPastIncompleteItems: Bool {
        guard selectedDate.isToday else { return false }
        let now = Date()
        return itemsForSelectedDate.contains { !$0.isCompleted && $0.startTime < now }
    }

    /// The currently active focus block task (if any) for today.
    private var activeFocusTask: ScheduleItem? {
        guard selectedDate.isToday else { return nil }
        let now = Date()
        return allItems.first {
            $0.isFocusBlock && !$0.isCompleted && $0.startTime <= now && $0.endTime > now
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Week calendar header
            weekCalendarHeader

            // Focus active banner — shown when a focus block task is currently running
            if let focusTask = activeFocusTask {
                focusBanner(task: focusTask)
            }

            // "Fix My Day" banner — visible when today has past incomplete tasks
            if hasPastIncompleteItems {
                fixMyDayBanner
            }

            // Task recommendations — shown when pending library tasks + free slots exist
            if !taskRecommendations.isEmpty {
                taskRecommendationBanner
            }

            // Timeline content — dot-and-card list layout
            ScrollViewReader { proxy in
                ScrollView {
                    if itemsForSelectedDate.isEmpty {
                        emptyDayPlaceholder
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(timelineRows) { row in
                                switch row {
                                case .task(let item):
                                    TaskTimelineRow(
                                        item: item,
                                        isCurrentTask: item.startTime <= Date() && item.endTime > Date() && selectedDate.isToday,
                                        displayColor: displayColor(for: item),
                                        displayIconName: displayIconName(for: item),
                                        onTap: { selectedItem = item },
                                        onToggleComplete: { toggleCompletion(item) }
                                    )
                                    .id("task-\(item.id)")
                                case .nowIndicator:
                                    NowIndicatorRow()
                                        .id("now")
                                case .freeSlot(let gap):
                                    FreeSlotRow(gap: gap) {
                                        selectedSlotTime = gap.start
                                        showingAddTask = true
                                    }
                                case .wakeUp(let time):
                                    WakeUpRow(time: time)
                                case .windDown(let time):
                                    WindDownRow(time: time)
                                }
                            }
                        }
                        .padding(.top, 16)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 120)
                    }
                }
                .onAppear { scrollToFirstItem(proxy: proxy) }
                .onChange(of: selectedDate) { _, _ in scrollToFirstItem(proxy: proxy) }
            }
        }
        .background(Color(.systemGroupedBackground))
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                focusBlockManager.syncShields(for: Array(allItems))
                // Shield extension diagnostic
                if let ud = UserDefaults(suiteName: "group.com.scheduler.tempo") {
                    let initTs = ud.double(forKey: "shieldExtension.initTimestamp")
                    let invokeKind = ud.string(forKey: "shieldExtension.lastInvocationKind") ?? "never"
                    let invokeTarget = ud.string(forKey: "shieldExtension.lastInvocationTarget") ?? "-"
                    print("🛡️ Shield ext init: \(initTs > 0 ? "YES" : "NO") | last: \(invokeKind) | target: \(invokeTarget)")
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
        .sheet(isPresented: Binding(
            get: { sleepOverlapItem != nil },
            set: { if !$0 { sleepOverlapItem = nil } }
        )) {
            if let item = sleepOverlapItem {
                SleepOverlapSheet(
                    item: item,
                    earlierTime: sleepEarlierSuggestion,
                    nextAvailableTime: sleepNextSlotSuggestion,
                    onMoveEarlier: {
                        if let newTime = sleepEarlierSuggestion {
                            applySleepSuggestion(to: item, newStartTime: newTime)
                        }
                        sleepOverlapItem = nil
                    },
                    onMoveToNextSlot: {
                        if let newTime = sleepNextSlotSuggestion {
                            applySleepSuggestion(to: item, newStartTime: newTime)
                        }
                        sleepOverlapItem = nil
                    },
                    onKeep: { sleepOverlapItem = nil }
                )
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
            }
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
        .sheet(item: $pendingSchedule) { info in
            ScheduleConfirmationSheet(info: info) {
                commitSchedule(info)
            }
            .presentationDetents([.height(260)])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Week Calendar Header

    private var weekCalendarHeader: some View {
        VStack(spacing: 12) {
            // Month and year - with settings and add buttons
            HStack(alignment: .bottom) {
                if let onSettings = onSettings {
                    Button(action: onSettings) {
                        Image(systemName: "gearshape")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                Text((currentWeekDays.last ?? selectedDate).formatted(.dateTime.month(.wide)))
                    .font(.title2)
                    .fontWeight(.bold)
                Text((currentWeekDays.last ?? selectedDate).formatted(.dateTime.year()))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.accentColor)

                Spacer()

                // Today button when today is not in the currently displayed week
                if !currentWeekDays.contains(where: { $0.isToday }) {
                    Button(action: { selectedDate = Date() }) {
                        Text("Today")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(8)
                    }
                }

                Button(action: {
                    selectedSlotTime = nil
                    onAddTask()
                }) {
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.accentColor)
                        .clipShape(Circle())
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
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    // MARK: - Fix My Day Banner

    @ViewBuilder
    private func focusBanner(task: ScheduleItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "moon.circle.fill")
                .foregroundColor(.indigo)

            VStack(alignment: .leading, spacing: 2) {
                Text("Focus active")
                    .font(.caption2)
                    .foregroundColor(.indigo.opacity(0.8))
                Text(task.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.indigo)
            }

            Spacer()

            Text("until \(task.endTime, style: .time)")
                .font(.caption)
                .foregroundColor(.indigo.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.indigo.opacity(0.08))
    }

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

    private var taskRecommendationBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Schedule from your tasks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(taskRecommendations) { task in
                        taskRecommendationPill(task)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }
        }
        .padding(.top, 8)
    }

    private func taskRecommendationPill(_ task: TaskDefinition) -> some View {
        let color = Color(hex: task.colorHex) ?? .blue
        let slot = bestSlot(for: task)
        return Button {
            confirmSchedule(task)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: task.iconName)
                    .font(.caption)
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 1) {
                    Text(task.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        if let slot {
                            Text(slot, format: .dateTime.hour().minute())
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(color)
                            Text("·")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(task.durationMinutes)m")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if let deadline = task.deadline {
                            Text("·")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(deadline, format: .dateTime.month(.abbreviated).day())
                                .font(.caption2)
                                .foregroundStyle(deadline < Date() ? .red : .secondary)
                        }
                    }
                }
                Image(systemName: slot != nil ? "plus.circle.fill" : "clock.badge.xmark")
                    .font(.callout)
                    .foregroundStyle(slot != nil ? color : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(slot == nil)
    }

    /// Wake-up and wind-down boundaries for the selected date, respecting sleep schedule.
    private var dayBoundaries: (start: Date, end: Date) {
        let cal = Calendar.current
        var dayStart = selectedDate.startOfDay.withTime(hour: 6)
        var dayEnd   = selectedDate.startOfDay.withTime(hour: 22)
        if sleepManager.isEnabled, let schedule = sleepManager.sleepSchedule {
            var wakeComps = DateComponents(hour: schedule.wakeHour, minute: schedule.wakeMinute)
            wakeComps.year  = cal.component(.year,  from: selectedDate)
            wakeComps.month = cal.component(.month, from: selectedDate)
            wakeComps.day   = cal.component(.day,   from: selectedDate)
            if let wake = cal.date(from: wakeComps) { dayStart = wake }
            var bedComps = DateComponents(hour: schedule.bedtimeHour, minute: schedule.bedtimeMinute)
            bedComps.year  = cal.component(.year,  from: selectedDate)
            bedComps.month = cal.component(.month, from: selectedDate)
            bedComps.day   = cal.component(.day,   from: selectedDate)
            if let bed = cal.date(from: bedComps) {
                dayEnd = bed.addingTimeInterval(-Double(schedule.bufferMinutes * 60))
            }
        }
        return (dayStart, dayEnd)
    }

    /// Best sleep-aware start time for scheduling a task, nil if no slot fits.
    private func bestSlot(for task: TaskDefinition) -> Date? {
        let bounds = dayBoundaries
        let taskDuration = TimeInterval(task.durationMinutes * 60)

        // Build candidate slots from timeline free gaps
        var candidates = timelineRows.compactMap { row -> Date? in
            guard case .freeSlot(let gap) = row else { return nil }
            let start = max(gap.start, bounds.start)
            let end   = min(gap.start.addingTimeInterval(TimeInterval(gap.durationMinutes * 60)), bounds.end)
            guard end.timeIntervalSince(start) >= taskDuration else { return nil }
            return start
        }

        // Empty day — whole window is free
        if candidates.isEmpty && itemsForSelectedDate.isEmpty {
            let start = max(bounds.start, Date()) // don't schedule in the past on today
            if bounds.end.timeIntervalSince(start) >= taskDuration {
                candidates.append(start)
            }
        }

        return candidates.first
    }

    private func confirmSchedule(_ task: TaskDefinition) {
        guard let start = bestSlot(for: task) else { return }
        pendingSchedule = PendingScheduleInfo(task: task, startTime: start)
    }

    private func commitSchedule(_ info: PendingScheduleInfo) {
        let item = ScheduleItem(
            title: info.task.title,
            category: .flexibleTask,
            startTime: info.startTime,
            durationMinutes: info.task.durationMinutes,
            scheduledDate: selectedDate,
            taskDefinitionId: info.task.id
        )
        modelContext.insert(item)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        pendingSchedule = nil
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
        let dotCategories = Array(
            Set(allItems.filter { $0.scheduledDate.isSameDay(as: date) }.map { $0.category })
        ).sorted { $0.priority < $1.priority }.prefix(3)

        return Button(action: { selectedDate = date }) {
            VStack(spacing: 4) {
                Text(date.formatted(.dateTime.weekday(.narrow)))
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white : .secondary)

                Text(date.formatted(.dateTime.day()))
                    .font(.callout)
                    .fontWeight(isToday ? .bold : .medium)
                    .foregroundStyle(isSelected ? .white : (isToday ? .accentColor : .primary))

                // Category-colored activity dots
                HStack(spacing: 2) {
                    if dotCategories.isEmpty {
                        Circle().fill(Color.clear).frame(width: 4, height: 4)
                    } else {
                        ForEach(Array(dotCategories), id: \.self) { cat in
                            Circle()
                                .fill(isSelected ? Color.white.opacity(0.85) : cat.color)
                                .frame(width: 4, height: 4)
                        }
                    }
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

    // MARK: - Timeline Helpers

    private var emptyDayPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.4))
            Text("Nothing scheduled")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            Text("Tap + to add your first block for the day.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    func displayColor(for item: ScheduleItem) -> Color {
        if let habId = item.habitDefinitionId,
           let def = habitDefs.first(where: { $0.id == habId }) {
            return Color(hex: def.colorHex) ?? item.category.color
        }
        if let goalId = item.goalDefinitionId,
           let def = goalDefs.first(where: { $0.id == goalId }) {
            return Color(hex: def.colorHex) ?? item.category.color
        }
        return item.category.color
    }

    func displayIconName(for item: ScheduleItem) -> String {
        if let habId = item.habitDefinitionId,
           let def = habitDefs.first(where: { $0.id == habId }) {
            return def.iconName
        }
        if let goalId = item.goalDefinitionId,
           let def = goalDefs.first(where: { $0.id == goalId }) {
            return def.iconName
        }
        return item.category.iconName
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes >= 60 && minutes % 60 == 0 {
            return "\(minutes / 60)h"
        } else if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }

    // MARK: - Task Card (old compact style - retained for TaskDetailSheet compatibility)

    private func taskCard_unused(for item: ScheduleItem) -> some View {
        let isInProgress = selectedDate.isToday && item.startTime <= Date() && item.endTime > Date()
        let isCompact = item.durationMinutes <= 20
        let elapsed: Double = isInProgress
            ? min(1.0, max(0, Date().timeIntervalSince(item.startTime) / item.endTime.timeIntervalSince(item.startTime)))
            : 0

        return Button(action: { selectedItem = item }) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(item.category.color.opacity(item.isCompleted ? 0.38 : 0.84))

                if isInProgress && elapsed > 0 {
                    GeometryReader { geo in
                        VStack(spacing: 0) {
                            Color.black.opacity(0.15)
                                .frame(height: geo.size.height * elapsed)
                            Color.clear
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .allowsHitTesting(false)
                }

                if isCompact {
                    HStack(spacing: 5) {
                        Image(systemName: item.category.iconName)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                        Text(item.title)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .strikethrough(item.isCompleted)
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        taskCheckbox(for: item, size: 15)
                    }
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .top, spacing: 4) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .strikethrough(item.isCompleted)
                                    .lineLimit(2)
                                Text("\(formatTime(item.startTime)) - \(formatTime(item.endTime))")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.72))
                            }
                            Spacer(minLength: 4)
                            taskCheckbox(for: item, size: 20)
                        }
                        if isInProgress {
                            Text("\(max(0, Int(item.endTime.timeIntervalSince(Date()) / 60))) min left")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(.white.opacity(0.88))
                                .padding(.top, 2)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 7)
                    .padding(.bottom, 5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: item.category.color.opacity(item.isCompleted ? 0 : 0.28), radius: 4, x: 0, y: 2)
            .opacity(item.isCompleted ? 0.72 : 1.0)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func taskCheckbox(for item: ScheduleItem, size: CGFloat) -> some View {
        Button(action: { toggleCompletion(item) }) {
            ZStack {
                Circle()
                    .fill(.white.opacity(item.isCompleted ? 0.9 : 0.22))
                    .frame(width: size, height: size)
                if item.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.46, weight: .bold))
                        .foregroundStyle(item.category.color)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var completedCount: Int {
        itemsForSelectedDate.filter { $0.isCompleted }.count
    }

    private func toggleCompletion(_ item: ScheduleItem) {
        item.isCompleted.toggle()
        item.touch()
        if item.isCompleted {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        // Sync shields on both complete and un-complete for focus block tasks
        if item.isFocusBlock {
            focusBlockManager.syncShields(for: Array(allItems))
        }
        // Sync completion back to the library TaskDefinition if linked
        if let taskId = item.taskDefinitionId,
           let def = taskDefs.first(where: { $0.id == taskId }) {
            def.isCompleted = item.isCompleted
        }
    }

    private func scrollToFirstItem(proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                if selectedDate.isToday {
                    proxy.scrollTo("now", anchor: .center)
                } else if let firstItem = itemsForSelectedDate.first {
                    proxy.scrollTo("task-\(firstItem.id)", anchor: .top)
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
            return
        }

        // No task conflict — check for sleep overlap
        checkForSleepOverlap(newItem: newItem)
    }

    private func checkForSleepOverlap(newItem: ScheduleItem) {
        guard sleepManager.isEnabled else { return }
        guard sleepManager.doesRangeOverlapSleep(start: newItem.startTime, end: newItem.endTime) else { return }
        guard let range = sleepManager.getSleepBlockedRange(for: newItem.scheduledDate) else { return }

        let earlierStart = range.bufferStart.addingTimeInterval(-Double(newItem.durationMinutes * 60))
        let calendar = Calendar.current
        let dayStart = calendar.date(bySettingHour: 5, minute: 0, second: 0, of: newItem.scheduledDate) ?? newItem.scheduledDate
        sleepEarlierSuggestion = (earlierStart >= dayStart && earlierStart > Date()) ? earlierStart : nil
        sleepNextSlotSuggestion = findFirstFreeSlotAfterWake(wakeTime: range.wakeTime, durationMinutes: newItem.durationMinutes)
        sleepOverlapItem = newItem
    }

    /// Returns the first start time after `wakeTime` where `durationMinutes` fit without overlapping existing items.
    private func findFirstFreeSlotAfterWake(wakeTime: Date, durationMinutes: Int) -> Date {
        let wakeDay = Calendar.current.startOfDay(for: wakeTime)
        let duration = TimeInterval(durationMinutes * 60)
        let itemsOnWakeDay = allItems
            .filter { $0.scheduledDate.isSameDay(as: wakeDay) && !$0.isCompleted }
            .sorted { $0.startTime < $1.startTime }
        var candidate = wakeTime
        for item in itemsOnWakeDay {
            if item.endTime <= candidate { continue }
            if item.startTime >= candidate.addingTimeInterval(duration) { break }
            candidate = item.endTime
        }
        return candidate
    }

    private func applySleepSuggestion(to item: ScheduleItem, newStartTime: Date) {
        guard let liveItem = allItems.first(where: { $0.id == item.id }) else { return }
        liveItem.startTime = newStartTime
        liveItem.scheduledDate = Calendar.current.startOfDay(for: newStartTime)
        liveItem.touch()
        try? modelContext.save()
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

// MARK: - Timeline Row Views

struct TaskTimelineRow: View {
    let item: ScheduleItem
    let isCurrentTask: Bool
    let displayColor: Color
    let displayIconName: String
    let onTap: () -> Void
    let onToggleComplete: () -> Void

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left: time + dot + vertical line
            VStack(spacing: 0) {
                Text(timeFormatter.string(from: item.startTime))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: true, vertical: false)

                Circle()
                    .fill(displayColor)
                    .frame(width: 10, height: 10)
                    .padding(.top, 6)

                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(width: 1.5)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 66)

            // Right: card, with now-line overlay when task is active
            taskCard
                .padding(.bottom, 6)
                .overlay(alignment: .top) {
                    if isCurrentTask {
                        nowOverlay
                    }
                }
        }
    }

    private var nowOverlay: some View {
        HStack(spacing: 6) {
            Text(Date(), format: .dateTime.hour().minute())
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.orange)
            Circle()
                .fill(Color.orange)
                .frame(width: 8, height: 8)
            Rectangle()
                .fill(Color.orange.opacity(0.6))
                .frame(height: 1.5)
        }
        .padding(.horizontal, 10)
        .offset(y: -1)
    }

    private var taskCard: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon square
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(displayColor.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: displayIconName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(displayColor)
                }

                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .strikethrough(item.isCompleted)
                        .lineLimit(2)

                    // Category label + duration
                    HStack(spacing: 4) {
                        Text(item.category.displayName.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(displayColor)
                        Text("• \(formatDuration(item.durationMinutes))")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }

                    // Tag chips
                    if item.isFocusBlock || item.isRecurring {
                        HStack(spacing: 6) {
                            if item.isFocusBlock  { TagChip("FOCUS") }
                            if item.isRecurring   { TagChip("RECURRING") }
                        }
                    }
                }

                Spacer()

                // Completion circle
                taskCheckboxView
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 2)
            )
            .opacity(item.isCompleted ? 0.65 : 1.0)
        }
        .buttonStyle(.plain)
    }

    private var taskCheckboxView: some View {
        Button(action: onToggleComplete) {
            ZStack {
                Circle()
                    .stroke(displayColor.opacity(0.5), lineWidth: 2)
                    .frame(width: 26, height: 26)
                if item.isCompleted {
                    Circle()
                        .fill(displayColor)
                        .frame(width: 26, height: 26)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes >= 60 && minutes % 60 == 0 { return "\(minutes/60)h" }
        if minutes >= 60 { return "\(minutes/60)h \(minutes%60)m" }
        return "\(minutes)m"
    }
}

// MARK: - Schedule Confirmation

struct PendingScheduleInfo: Identifiable {
    let id = UUID()
    let task: TaskDefinition
    let startTime: Date
}

struct ScheduleConfirmationSheet: View {
    let info: PendingScheduleInfo
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var endTime: Date {
        info.startTime.addingTimeInterval(TimeInterval(info.task.durationMinutes * 60))
    }

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                let color = Color(hex: info.task.colorHex) ?? .blue
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 56, height: 56)
                    Image(systemName: info.task.iconName)
                        .font(.title2)
                        .foregroundStyle(color)
                }
                Text(info.task.title)
                    .font(.headline)
                Text("\(timeFormatter.string(from: info.startTime)) – \(timeFormatter.string(from: endTime))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(info.task.durationMinutes) min")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                Button("Schedule") { onConfirm() }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
        }
        .padding(.top, 28)
        .padding(.bottom, 12)
    }
}

struct NowIndicatorRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Text(Date(), format: .dateTime.hour().minute())
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.orange)
                .frame(width: 44, alignment: .trailing)
                .frame(width: 66)

            Circle()
                .fill(Color.orange)
                .frame(width: 10, height: 10)

            Rectangle()
                .fill(Color.orange.opacity(0.6))
                .frame(height: 1.5)
        }
        .padding(.vertical, 8)
    }
}

struct WakeUpRow: View {
    let time: Date

    var body: some View {
        HStack(spacing: 12) {
            Text(time, format: .dateTime.hour().minute())
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.orange)
                .frame(width: 54, alignment: .trailing)
                .frame(width: 66)

            Image(systemName: "sunrise.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.orange.opacity(0.85))

            Text("Wake up")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.orange.opacity(0.85))

            Rectangle()
                .fill(Color.orange.opacity(0.2))
                .frame(height: 1)
        }
        .padding(.vertical, 8)
        // Gradient is purely visual — zero layout height, extends above without pushing content
        .background(alignment: .top) {
            LinearGradient(
                colors: [Color.orange.opacity(0.07), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 1000)
            .offset(y: -980) // bottom of gradient lands at ~20pt into row (separator line level)
            .padding(.horizontal, -16)
            .allowsHitTesting(false)
        }
    }
}

struct WindDownRow: View {
    let time: Date

    var body: some View {
        HStack(spacing: 12) {
            Text(time, format: .dateTime.hour().minute())
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.indigo)
                .frame(width: 54, alignment: .trailing)
                .frame(width: 66)

            Image(systemName: "moon.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.indigo.opacity(0.85))

            Text("Wind down")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.indigo.opacity(0.85))

            Rectangle()
                .fill(Color.indigo.opacity(0.2))
                .frame(height: 1)
        }
        .padding(.vertical, 8)
        // Gradient is purely visual — zero layout height, extends below without pushing content
        .background(alignment: .bottom) {
            LinearGradient(
                colors: [Color.clear, Color.indigo.opacity(0.06)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 1000)
            .offset(y: 980) // top of gradient lands at ~20pt from row bottom (separator line level)
            .padding(.horizontal, -16)
            .allowsHitTesting(false)
        }
    }
}

struct FreeSlotRow: View {
    let gap: TimeGap
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Color.clear.frame(width: 66)

            Button(action: onTap) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor.opacity(0.6))
                    Text(gapMessage)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray5), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 8)
    }

    private var gapMessage: String {
        let m = gap.durationMinutes
        let h = m / 60, rem = m % 60
        if h > 0 && rem > 0 { return "\(h)h \(rem)m free" }
        if h > 0 { return "\(h)h free" }
        return "\(m)m free"
    }
}

struct TagChip: View {
    let label: String
    init(_ label: String) { self.label = label }
    var body: some View {
        Text(label)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(.systemGray5))
            .cornerRadius(4)
    }
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
                        .foregroundStyle(item.category.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(timeFormatter.string(from: item.startTime)) (\(item.durationMinutes) min)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

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
                .foregroundStyle(Color.accentColor)
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
                    .foregroundStyle(color)

                Text(label)
                    .font(.caption)
                    .foregroundStyle(color)
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
                            .foregroundStyle(.orange)

                        Text("Schedule Conflict")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("The new task overlaps with existing tasks. How would you like to resolve this?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
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
                            .foregroundStyle(resolution.newItem.category.color)
                    }
                    Text(resolution.newItem.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    Text(timeFormatter.string(from: resolution.newItem.startTime))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Image(systemName: "arrow.left.arrow.right")
                    .foregroundStyle(.orange)

                // Conflicting task
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(resolution.conflictingItem.category.color.opacity(0.2))
                            .frame(width: 40, height: 40)
                        Image(systemName: resolution.conflictingItem.category.iconName)
                            .foregroundStyle(resolution.conflictingItem.category.color)
                    }
                    Text(resolution.conflictingItem.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    Text(timeFormatter.string(from: resolution.conflictingItem.startTime))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            // Reason
            Text(resolution.reason)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .cornerRadius(6)

            // Action buttons based on suggestion
            VStack(spacing: 10) {
                switch resolution.suggestion {
                case .moveConflicting(let options):
                    ForEach(options, id: \.self) { date in
                        Button(action: {
                            onResolve(resolution, .moveConflicting(to: date))
                        }) {
                            HStack {
                                Image(systemName: "arrow.right")
                                Text("Move \"\(resolution.conflictingItem.title)\" to \(formatTime(date))")
                            }
                            .font(.subheadline)
                            .fontWeight(options.count == 1 ? .medium : .regular)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.accentColor)
                            .cornerRadius(10)
                        }
                    }

                    Button(action: {
                        onResolve(resolution, .deleteConflicting)
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Remove \"\(resolution.conflictingItem.title)\"")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                    }

                case .moveNew(let options):
                    ForEach(options, id: \.self) { date in
                        Button(action: {
                            onResolve(resolution, .moveNew(to: date))
                        }) {
                            HStack {
                                Image(systemName: "arrow.right")
                                Text("Move new task to \(formatTime(date))")
                            }
                            .font(.subheadline)
                            .fontWeight(options.count == 1 ? .medium : .regular)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.accentColor)
                            .cornerRadius(10)
                        }
                    }

                case .userDecision(let conflictingOptions, let newOptions):
                    if !conflictingOptions.isEmpty {
                        Text("Move \"\(resolution.conflictingItem.title)\"")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(conflictingOptions, id: \.self) { date in
                            Button(action: {
                                onResolve(resolution, .moveConflicting(to: date))
                            }) {
                                HStack {
                                    Image(systemName: "arrow.right")
                                    Text("\(formatTime(date))")
                                }
                                .font(.subheadline)
                                .fontWeight(conflictingOptions.count == 1 ? .medium : .regular)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.accentColor)
                                .cornerRadius(10)
                            }
                        }
                    }

                    if !newOptions.isEmpty {
                        Text("Move \"\(resolution.newItem.title)\"")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, conflictingOptions.isEmpty ? 0 : 4)
                        ForEach(newOptions, id: \.self) { date in
                            Button(action: {
                                onResolve(resolution, .moveNew(to: date))
                            }) {
                                HStack {
                                    Image(systemName: "arrow.right")
                                    Text("\(formatTime(date))")
                                }
                                .font(.subheadline)
                                .fontWeight(newOptions.count == 1 ? .medium : .regular)
                                .foregroundColor(.accentColor)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.accentColor.opacity(0.1))
                                .cornerRadius(10)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
       .shadow(color: Color.primary.opacity(0.08), radius: 8, x: 0, y: 2)
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

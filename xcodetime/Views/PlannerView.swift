import SwiftData
import SwiftUI

struct PlannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allTasks: [TaskItem]
    @Query private var habits: [Habit]

    @StateObject private var notificationManager = NotificationManager.shared

    @State private var selectedDate = Date()
    @State private var showingAddTask = false
    @State private var showingAddHabit = false
    @State private var selectedTaskType: TaskType = .task
    @State private var isMonthViewExpanded = false

    var tasksForSelectedDate: [TaskItem] {
        allTasks.filter { Calendar.current.isDate($0.scheduledDate, inSameDayAs: selectedDate) }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.gray.opacity(0.05)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Custom Header
                    HStack {
                        Button(action: { withAnimation { isMonthViewExpanded.toggle() } }) {
                            VStack(alignment: .leading) {
                                HStack {
                                    Text(selectedDate, format: .dateTime.month(.wide))
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.primary)
                                    Image(systemName: "chevron.down")
                                        .rotationEffect(.degrees(isMonthViewExpanded ? 180 : 0))
                                        .foregroundStyle(.secondary)
                                }
                                Text(selectedDate, format: .dateTime.year())
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()

                        Button(action: {
                            withAnimation {
                                selectedDate = Date()
                                isMonthViewExpanded = false
                            }
                        }) {
                            Text("Сегодня")
                                .font(.callout)
                                .fontWeight(.medium)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.blue.opacity(0.1)))
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding()
                    .background(Material.ultraThinMaterial)

                    // Calendar Area
                    Group {
                        if isMonthViewExpanded {
                            MonthCalendarView(selectedDate: $selectedDate)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        } else {
                            CalendarStrip(selectedDate: $selectedDate)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .padding(.bottom, 20)
                    .background(
                        Rectangle()
                            .fill(Material.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                            .mask(Rectangle().padding(.bottom, -20))
                    )

                    ScrollView {
                        VStack(spacing: 24) {
                            // Habits Section
                            if !habits.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Привычки")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal)

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            ForEach(habits) { habit in
                                                HabitCard(
                                                    habit: habit,
                                                    isCompletedOnDate: habit.isCompleted(
                                                        on: selectedDate),
                                                    onTap: { toggleHabit(habit) }
                                                )
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }

                            // Tasks Section
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("Расписание")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Menu {
                                        Button(action: {
                                            selectedTaskType = .task
                                            showingAddTask = true
                                        }) { Label("Задача", systemImage: "checklist") }
                                        Button(action: {
                                            selectedTaskType = .workout
                                            showingAddTask = true
                                        }) { Label("Тренировка", systemImage: "figure.run") }
                                        Button(action: {
                                            selectedTaskType = .event
                                            showingAddTask = true
                                        }) { Label("Событие", systemImage: "calendar") }
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(.blue)
                                            .symbolEffect(.bounce, value: showingAddTask)
                                    }
                                }
                                .padding(.horizontal)

                                if tasksForSelectedDate.isEmpty {
                                    ContentUnavailableView {
                                        Label(
                                            "Нет планов",
                                            systemImage: "calendar.badge.exclamationmark")
                                    } description: {
                                        Text("Нажмите +, чтобы добавить.")
                                    }
                                    .padding(.top, 40)
                                } else {
                                    LazyVStack(spacing: 0) {
                                        ForEach(tasksForSelectedDate) { task in
                                            TimelineTaskRow(
                                                task: task, onToggle: { toggleTask(task) }
                                            )
                                            .contextMenu {
                                                Button("Удалить", role: .destructive) {
                                                    NotificationManager.shared.removeNotification(
                                                        for: task)
                                                    modelContext.delete(task)
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.bottom, 100)
                        }
                        .padding(.top)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddTask) {
                AddTaskView(preselectedType: selectedTaskType, preselectedDate: selectedDate)
            }
            .sheet(isPresented: $showingAddHabit) {
                AddHabitView()
            }
            .onAppear {
                notificationManager.requestAuthorization()
            }
        }
    }

    private func toggleHabit(_ habit: Habit) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            if habit.isCompleted(on: selectedDate) {
                // Remove log for selected date
                if let index = habit.logs.firstIndex(where: {
                    Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
                }) {
                    habit.logs.remove(at: index)
                }
                // Recalculate streak logic strictly if needed, but for now simple toggle
                habit.streak = max(0, habit.streak - 1)
            } else {
                // Add log for selected date
                habit.logs.append(HabitLog(date: selectedDate))
                habit.lastCompletionDate = selectedDate
                habit.streak += 1
            }
        }
    }

    private func toggleTask(_ task: TaskItem) {
        withAnimation {
            task.isCompleted.toggle()
        }
    }
}

// MARK: - Subviews

struct MonthCalendarView: View {
    @Binding var selectedDate: Date
    private let calendar = Calendar.current
    private let days: [Date]

    init(selectedDate: Binding<Date>) {
        _selectedDate = selectedDate

        // Generate days for the current month view
        // Ideally this should be dynamic based on selectedDate's month
        let date = selectedDate.wrappedValue
        let interval = calendar.dateInterval(of: .month, for: date)!
        let firstDay = interval.start

        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let offsetDays = firstWeekday - calendar.firstWeekday

        let startDate = calendar.date(byAdding: .day, value: -offsetDays, to: firstDay)!

        var tempDays: [Date] = []
        for i in 0..<42 {  // 6 weeks
            if let d = calendar.date(byAdding: .day, value: i, to: startDate) {
                tempDays.append(d)
            }
        }
        self.days = tempDays
    }

    var body: some View {
        VStack(spacing: 15) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                // Weekday Headers
                ForEach(["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"], id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                }

                // Days
                ForEach(days, id: \.self) { date in
                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                    let isToday = calendar.isDateInToday(date)
                    let isCurrentMonth = calendar.isDate(
                        date, equalTo: selectedDate, toGranularity: .month)

                    Text("\(calendar.component(.day, from: date))")
                        .font(.body)
                        .fontWeight(isSelected || isToday ? .bold : .regular)
                        .foregroundStyle(
                            isSelected
                                ? .white
                                : (isToday ? .blue : (isCurrentMonth ? .primary : .secondary))
                        )
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(isSelected ? Color.blue.gradient : Color.clear.gradient)
                        )
                        .onTapGesture {
                            withAnimation {
                                selectedDate = date
                            }
                        }
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom)
    }
}

struct CalendarStrip: View {
    @Binding var selectedDate: Date
    private let calendar = Calendar.current
    private let daysToPreload = 15  // +/- 15 days

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ScrollViewReader { proxy in
                HStack(spacing: 12) {
                    ForEach(-daysToPreload...daysToPreload, id: \.self) { offset in
                        if let date = calendar.date(byAdding: .day, value: offset, to: Date()) {
                            DateCell(
                                date: date,
                                isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                isToday: calendar.isDateInToday(date)
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedDate = date
                                    proxy.scrollTo(offset, anchor: .center)
                                }
                            }
                            .id(offset)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .onAppear {
                    // Scroll to today (id 0)
                    proxy.scrollTo(0, anchor: .center)
                }
            }
        }
    }
}

struct DateCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(date, format: .dateTime.weekday(.abbreviated))
                .font(.caption)
                .fontWeight(.medium)
                .textCase(.uppercase)
                .foregroundStyle(isSelected ? .white.opacity(0.8) : (isToday ? .blue : .secondary))

            Text(date, format: .dateTime.day())
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(isSelected ? .white : (isToday ? .blue : .primary))

            // Indicator dot
            Circle()
                .fill(isSelected ? .white : (isToday ? .blue : .clear))
                .frame(width: 4, height: 4)
        }
        .frame(width: 55, height: 85)
        .background(
            ZStack {
                if isSelected {
                    Capsule()
                        .fill(Color.blue.gradient)
                        .shadow(color: .blue.opacity(0.4), radius: 8, x: 0, y: 4)
                } else {
                    Capsule()
                        .fill(Color(.secondarySystemGroupedBackground))
                        .overlay(
                            Capsule().strokeBorder(
                                isToday ? Color.blue.opacity(0.3) : .clear, lineWidth: 1)
                        )
                }
            }
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
    }
}

struct TimelineTaskRow: View {
    let task: TaskItem
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Time Column
            VStack(alignment: .trailing, spacing: 0) {
                Text(task.scheduledDate, format: .dateTime.hour().minute())
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 50, alignment: .trailing)
            .padding(.top, 4)

            // Timeline Line
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)

                Circle()
                    .fill(task.isCompleted ? Color.gray : Color.blue)
                    .frame(width: 10, height: 10)
                    .background(Circle().fill(.background).padding(-2))
                    .padding(.top, 8)
            }

            // Task Card
            Button(action: onToggle) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title)
                                .font(.body)
                                .fontWeight(.semibold)
                                .strikethrough(task.isCompleted)
                                .foregroundStyle(task.isCompleted ? .secondary : .primary)

                            if !task.notes.isEmpty {
                                Text(task.notes)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }

                        Spacer()

                        if task.type != .task {
                            Image(systemName: task.type.icon)
                                .font(.caption)
                                .padding(6)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Circle())
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            task.isCompleted
                                ? Color(.secondarySystemGroupedBackground).opacity(0.5)
                                : Color(.secondarySystemGroupedBackground)
                        )
                        .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.gray.opacity(0.1), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

struct HabitCard: View {
    let habit: Habit
    let isCompletedOnDate: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isCompletedOnDate ? .white.opacity(0.2) : .blue.opacity(0.1))
                        .frame(width: 44, height: 44)

                    Image(systemName: habit.icon)
                        .font(.title3)
                        .foregroundStyle(isCompletedOnDate ? .white : .blue)
                }

                Text(habit.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isCompletedOnDate ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(width: 90, height: 110)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        isCompletedOnDate
                            ? Color.blue.gradient
                            : Color(.secondarySystemGroupedBackground).gradient
                    )
                    .shadow(
                        color: isCompletedOnDate ? .blue.opacity(0.3) : .black.opacity(0.05),
                        radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isCompletedOnDate ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isCompletedOnDate)
    }
}

struct AddTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var preselectedType: TaskType = .task
    var preselectedDate: Date = Date()

    @State private var title = ""
    @State private var notes = ""
    @State private var date: Date
    @State private var priority = 1
    @State private var type: TaskType

    init(preselectedType: TaskType, preselectedDate: Date) {
        self.preselectedType = preselectedType
        self.preselectedDate = preselectedDate
        _type = State(initialValue: preselectedType)
        _date = State(initialValue: preselectedDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Название", text: $title)
                    TextField("Заметки", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }

                Section {
                    pickerSection
                    DatePicker("Дата", selection: $date)
                    Picker("Приоритет", selection: $priority) {
                        Text("Низкий").tag(0)
                        Text("Средний").tag(1)
                        Text("Высокий").tag(2)
                    }
                }
            }
            .navigationTitle("Новая \(type.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let task = TaskItem(
                            title: title, scheduledDate: date, notes: notes, priority: priority,
                            type: type)
                        modelContext.insert(task)
                        NotificationManager.shared.scheduleTaskNotification(task: task)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }

    var pickerSection: some View {
        Picker("Тип", selection: $type) {
            ForEach(TaskType.allCases, id: \.self) { type in
                Label(type.displayName, systemImage: type.icon).tag(type)
            }
        }
    }
}

struct AddHabitView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var icon = "star.fill"

    let icons = [
        "star.fill", "flame.fill", "drop.fill", "book.fill", "figure.run", "bed.double.fill",
        "leaf.fill",
        "heart.fill", "bolt.fill",
    ]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Название привычки", text: $name)

                Section("Иконка") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: 15) {
                        ForEach(icons, id: \.self) { iconName in
                            Image(systemName: iconName)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle().fill(
                                        icon == iconName
                                            ? Color.blue.opacity(0.2) : Color.clear)
                                )
                                .onTapGesture {
                                    icon = iconName
                                }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Новая привычка")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let habit = Habit(name: name, icon: icon)
                        modelContext.insert(habit)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

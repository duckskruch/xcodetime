import SwiftData
import SwiftUI

struct DashboardView: View {
    @Query private var profiles: [UserProfile]
    @Query private var allFood: [FoodEntry]
    @Query private var habits: [Habit]
    @Query(sort: \TaskItem.scheduledDate) private var tasks: [TaskItem]

    var userProfile: UserProfile? { profiles.first }

    var averageQuality: Double {
        let todayFood = allFood.filter { Calendar.current.isDateInToday($0.date) }
        let scores = todayFood.compactMap { $0.qualityScore }
        guard !scores.isEmpty else { return 0 }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }

    var todaysCalories: Int {
        allFood.filter { Calendar.current.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.calories }
    }

    var dailyGoal: Int {
        userProfile?.dailyCalories ?? 2000
    }

    var progress: Double {
        guard dailyGoal > 0 else { return 0 }
        return Double(todaysCalories) / Double(dailyGoal)
    }

    var habitsDone: Int {
        habits.filter { $0.isCompleted(on: selectedDate) }.count
    }

    var unfinishedTasks: [TaskItem] {
        tasks.filter {
            !$0.isCompleted && Calendar.current.isDate($0.scheduledDate, inSameDayAs: selectedDate)
        }
        .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    // State variables for the new calendar header (assuming they are defined elsewhere or will be added)
    @State private var isMonthViewExpanded: Bool = false
    @State private var selectedDate: Date = Date()

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
                            // Summary Cards
                            HStack(spacing: 16) {
                                // Calories
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("Калории")
                                            .font(.headline)
                                        Spacer()
                                        Image(systemName: "flame.fill")
                                            .foregroundStyle(.orange)
                                    }

                                    HStack(alignment: .bottom, spacing: 4) {
                                        Text("\(todaysCalories)")
                                            .font(
                                                .system(size: 32, weight: .bold, design: .rounded))
                                        Text("/ \(dailyGoal)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .padding(.bottom, 6)
                                    }

                                    ProgressView(value: Double(todaysCalories) / Double(dailyGoal))
                                        .tint(.orange)
                                }
                                .padding()
                                .background(Material.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                            }
                            .padding(.horizontal)

                            // Food Quality Index Card
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Индекс качества питания")
                                        .font(.headline)
                                    Spacer()
                                    Image(systemName: "leaf.fill")
                                        .foregroundStyle(.green)
                                }

                                HStack(alignment: .bottom, spacing: 4) {
                                    Text(String(format: "%.1f", averageQuality))
                                        .font(.system(size: 32, weight: .bold, design: .rounded))
                                        .foregroundStyle(
                                            averageQuality >= 8
                                                ? .green : (averageQuality >= 5 ? .orange : .red))
                                    Text("/ 10")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .padding(.bottom, 6)

                                    Spacer()

                                    Text(
                                        averageQuality >= 8
                                            ? "Отлично"
                                            : (averageQuality >= 5 ? "Нормально" : "Плохо")
                                    )
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule().fill(
                                            averageQuality >= 8
                                                ? Color.green.gradient
                                                : (averageQuality >= 5
                                                    ? Color.orange.gradient : Color.red.gradient)))
                                }

                                ProgressView(value: averageQuality / 10.0)
                                    .tint(
                                        averageQuality >= 8
                                            ? .green : (averageQuality >= 5 ? .orange : .red))
                            }
                            .padding()
                            .background(Material.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .padding(.horizontal)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Material.thinMaterial)
                                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                            )
                            .padding(.horizontal)

                            // Info Grid
                            LazyVGrid(
                                columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15
                            ) {
                                // Habits Status
                                DashboardCard(
                                    title: "Привычки",
                                    icon: "star.fill",
                                    color: .blue,
                                    content: {
                                        VStack(alignment: .leading, spacing: 5) {
                                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                                Text("\(habitsDone)")
                                                    .font(
                                                        .system(
                                                            size: 28, weight: .bold,
                                                            design: .rounded))
                                                Text("/ \(habits.count)")
                                                    .font(.subheadline)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Text(
                                                habitsDone >= habits.count
                                                    ? "Все выполнено!" : "Продолжайте!"
                                            )
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        }
                                    }
                                )

                                // Quick Stats (Macros/Water/Steps placeholder)
                                DashboardCard(
                                    title: "Активность",
                                    icon: "figure.run",
                                    color: .green,
                                    content: {
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text("Норма")
                                                .font(.title3)
                                                .bold()
                                            Text("Уровень: \(userProfile?.activityLevel ?? "N/A")")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                )
                            }
                            .padding(.horizontal)

                            // Next Task Preview
                            if let nextTask = unfinishedTasks.first {
                                VStack(alignment: .leading, spacing: 15) {
                                    Text("Далее по плану")
                                        .font(.headline)
                                        .padding(.horizontal)

                                    HStack(spacing: 15) {
                                        Rectangle()
                                            .fill(Color.blue)
                                            .frame(width: 4)
                                            .cornerRadius(2)

                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(nextTask.title)
                                                .font(.headline)
                                            HStack {
                                                Image(systemName: nextTask.type.icon)
                                                Text(nextTask.scheduledDate, style: .time)
                                            }
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if nextTask.type == .workout {
                                            Image(systemName: "dumbbell.fill")
                                                .font(.largeTitle)
                                                .foregroundStyle(.orange.opacity(0.2))
                                        }
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                            .shadow(
                                                color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                                    )
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.top)
                    }
                }
                .navigationTitle("Сегодня")
                .navigationBarHidden(true)
            }
        }
    }
}

struct DashboardCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
        )
    }
}

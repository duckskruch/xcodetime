import Foundation
import SwiftData

@Model
final class UserProfile {
    var height: Double  // cm
    var weight: Double  // kg
    var age: Int
    var gender: String  // "Male", "Female", "Other"
    var activityLevel: String  // "Sedentary", "Light", "Moderate", "Active", "Very Active"
    var goal: String  // "Lose", "Maintain", "Gain"
    var apiKey: String  // For OpenRouter

    // Calculated computed properties can be transient or just logic computed on fly.
    // For storage, we keep raw data.

    init(
        height: Double = 170, weight: Double = 70, age: Int = 30, gender: String = "Male",
        activityLevel: String = "Moderate", goal: String = "Maintain", apiKey: String = ""
    ) {
        self.height = height
        self.weight = weight
        self.age = age
        self.gender = gender
        self.activityLevel = activityLevel
        self.goal = goal
        self.apiKey = apiKey
    }

    var bmr: Double {
        let base = (10 * weight) + (6.25 * height) - (5 * Double(age))
        return gender == "Male" ? base + 5 : base - 161
    }

    var dailyCalories: Int {
        let multiplier: Double
        switch activityLevel {
        case "Sedentary": multiplier = 1.2
        case "Light": multiplier = 1.375
        case "Moderate": multiplier = 1.55
        case "Active": multiplier = 1.725
        case "Very Active": multiplier = 1.9
        default: multiplier = 1.2
        }

        let tdee = bmr * multiplier

        switch goal {
        case "Lose": return Int(tdee - 500)
        case "Gain": return Int(tdee + 500)
        default: return Int(tdee)
        }
    }
}

@Model
final class Habit {
    var id: UUID
    var name: String
    var icon: String  // SF Symbol name
    var frequency: String  // "Daily", "Weekly"
    var streak: Int
    var lastCompletionDate: Date?
    var logs: [HabitLog]

    init(name: String, icon: String = "star.fill", frequency: String = "Daily") {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.frequency = frequency
        self.streak = 0
        self.logs = []
    }

    var isCompletedToday: Bool {
        guard let last = lastCompletionDate else { return false }
        return Calendar.current.isDateInToday(last)
    }
}

@Model
final class HabitLog {
    var date: Date
    var habit: Habit?

    init(date: Date) {
        self.date = date
    }
}

@Model
final class TaskItem {
    var id: UUID
    var title: String
    var notes: String
    var scheduledDate: Date
    var isCompleted: Bool
    var priority: Int  // 0: Low, 1: Medium, 2: High
    var typeString: String  // "Task", "Workout", "Event"

    var type: TaskType {
        get { TaskType(rawValue: typeString) ?? .task }
        set { typeString = newValue.rawValue }
    }

    init(
        title: String, scheduledDate: Date = Date(), notes: String = "", priority: Int = 1,
        type: TaskType = .task
    ) {
        self.id = UUID()
        self.title = title
        self.scheduledDate = scheduledDate
        self.notes = notes
        self.isCompleted = false
        self.priority = priority
        self.typeString = type.rawValue
    }
}

enum TaskType: String, CaseIterable, Codable {
    case task = "Task"
    case workout = "Workout"
    case event = "Event"

    var icon: String {
        switch self {
        case .task: return "checklist"
        case .workout: return "figure.run"
        case .event: return "calendar"
        }
    }

    var displayName: String {
        switch self {
        case .task: return "Задача"
        case .workout: return "Тренировка"
        case .event: return "Событие"
        }
    }
}

@Model
final class FoodEntry {
    var id: UUID
    var name: String
    var calories: Int
    var protein: Int
    var fat: Int
    var carbs: Int
    var date: Date
    var imagePath: String?
    var qualityScore: Int?  // 1-10
    var micronutrients: String?  // "Vitamin C, Iron, etc."

    init(
        name: String, calories: Int, protein: Int = 0, fat: Int = 0, carbs: Int = 0,
        date: Date = Date(), qualityScore: Int? = nil, micronutrients: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.calories = calories
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.date = date
        self.qualityScore = qualityScore
        self.micronutrients = micronutrients
    }
}

extension Habit {
    func isCompleted(on date: Date) -> Bool {
        return logs.contains { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
}

// MARK: - Chat Models
struct ChatMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String
    var attachments: [MessageAttachment] = []
}

enum MessageRole {
    case user
    case assistant
    case system
}

enum MessageAttachment {
    case task(TaskItem)
    case habit(Habit)
    case food(FoodEntry)
    // Add id for ForEach
    var id: String {
        switch self {
        case .task(let item): return item.id.uuidString
        case .habit(let item): return item.id.uuidString
        case .food(let item): return item.id.uuidString
        }
    }
}

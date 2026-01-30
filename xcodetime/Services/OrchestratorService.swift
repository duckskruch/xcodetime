import Foundation
import SwiftData

struct AICommandResponse: Codable {
    let responseText: String
    let actions: [AIAction]
}

struct AIAction: Codable {
    let type: String  // "create_task", "create_habit", "log_food"
    let taskData: TaskData?
    let habitData: HabitData?
    let foodData: FoodData?
}

struct TaskData: Codable {
    let title: String
    let date: Date?
    let priority: Int?
    let type: String?  // "Task", "Workout", "Event"
    let notes: String?
}

struct HabitData: Codable {
    let name: String
    let icon: String?
    let frequency: String?  // "Daily", "Weekly"
}

struct FoodData: Codable {
    let name: String
    let calories: Int?
    let protein: Int?
    let carbs: Int?
    let fat: Int?
}

class OrchestratorService {
    let openRouter: OpenRouterClient

    init(apiKey: String) {
        self.openRouter = OpenRouterClient(apiKey: apiKey)
    }

    func processRequest(_ text: String, history: [ChatMessage] = []) async throws
        -> AICommandResponse
    {
        let systemPrompt = """
            Ты - персональный ассистент "Оркестратор".
            Текущая дата: \(Date().formatted(.iso8601))

            Твоя задача - помогать пользователю управлять задачами, привычками и питанием.

            Проанализируй запрос и историю диалога, затем верни JSON объект:
            1. "responseText": Полезный, дружелюбный ответ на РУССКОМ языке.
            2. "actions": Массив действий (если нужны). Структура каждого действия:
               - "type": Одно из ["create_task", "create_habit", "log_food"]
               - "taskData": { "title": "...", "date": "ISO8601", "priority": 0-2 (1=med), "type": "Task"|"Workout"|"Event", "notes": "..." }
               - "habitData": { "name": "...", "icon": "sf symbol", "frequency": "Daily"|"Weekly" }
               - "foodData": { "name": "...", "calories": int, "protein": int, "fat": int, "carbs": int }

            Пример JSON:
            {
              "responseText": "Готово, я добавил задачу.",
              "actions": [ { "type": "create_task", "taskData": { "title": "Купить хлеб", "type": "Task" } } ]
            }

            Отвечай ТОЛЬКО валидным JSON. Не используй markdown блоки.
            """

        var apiMessages: [[String: Any]] = []

        // 1. System Message
        apiMessages.append(["role": "system", "content": systemPrompt])

        // 2. Chat History
        // Take last 10 messages to save context window
        let recentHistory = history.suffix(10)
        for msg in recentHistory {
            let role = (msg.role == .user) ? "user" : "assistant"
            apiMessages.append(["role": role, "content": msg.content])
        }

        // 3. Current User Message
        apiMessages.append(["role": "user", "content": text])

        return try await openRouter.pSendMessage(messages: apiMessages)
    }
}

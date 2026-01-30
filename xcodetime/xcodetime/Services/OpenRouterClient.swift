import Foundation

struct FoodAnalysisResult: Codable {
    let name: String
    let calories: Int
    let protein: Int
    let fat: Int
    let carbs: Int
    let qualityScore: Int
    let micronutrients: String

    enum CodingKeys: String, CodingKey {
        case name, calories, protein, fat, carbs, qualityScore, micronutrients
    }

    init(
        name: String, calories: Int, protein: Int, fat: Int, carbs: Int, qualityScore: Int,
        micronutrients: String
    ) {
        self.name = name
        self.calories = calories
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.qualityScore = qualityScore
        self.micronutrients = micronutrients
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        micronutrients = try container.decode(String.self, forKey: .micronutrients)

        // Helper to decode Int or String -> Int
        func decodeInt(forKey key: CodingKeys) -> Int {
            if let val = try? container.decode(Int.self, forKey: key) { return val }
            if let valStr = try? container.decode(String.self, forKey: key) {
                // Remove non-digits (e.g. "100 kcal" -> 100)
                let digits = valStr.components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .joined()
                return Int(digits) ?? 0
            }
            return 0
        }

        calories = decodeInt(forKey: .calories)
        protein = decodeInt(forKey: .protein)
        fat = decodeInt(forKey: .fat)
        carbs = decodeInt(forKey: .carbs)
        qualityScore = decodeInt(forKey: .qualityScore)
    }
}

class OpenRouterClient {
    private let apiKey: String
    private let baseURL = URL(string: "https://openrouter.ai/api/v1/chat/completions")!

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // Generic method to send chat messages and decode JSON response
    func pSendMessage<T: Decodable>(messages: [[String: Any]]) async throws -> T {
        // Mock response if key is empty
        if apiKey.isEmpty || apiKey == "YOUR_KEY" {
            throw URLError(.userAuthenticationRequired)
        }

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // Using google/gemini-2.0-flash-lite-001 via OpenRouter
        let model = "google/gemini-2.0-flash-lite-001"

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            if let str = String(data: data, encoding: .utf8) {
                print("API Error: \(str)")
            }
            throw URLError(.badServerResponse)
        }

        let wrapper = try JSONDecoder().decode(OpenRouterResponse.self, from: data)
        guard let contentString = wrapper.choices.first?.message.content else {
            throw URLError(.cannotDecodeContentData)
        }

        // Clean markdown code blocks if present
        let cleanJSON = contentString.replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "").trimmingCharacters(
                in: .whitespacesAndNewlines)

        guard let jsonData = cleanJSON.data(using: .utf8) else {
            throw URLError(.cannotDecodeRawData)
        }

        return try JSONDecoder().decode(T.self, from: jsonData)
    }

    func analyzeFoodText(text: String) async throws -> FoodAnalysisResult {
        if apiKey.isEmpty || apiKey == "YOUR_KEY" {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            return FoodAnalysisResult(
                name: text, calories: 100, protein: 5, fat: 2, carbs: 10, qualityScore: 5,
                micronutrients: "-")
        }

        let prompt = """
            Проанализируй описание еды: "\(text)".
            Определи название, калории и БЖУ (белки, жиры, углеводы) примерное.
            Оцени качество (qualityScore 1-10) и витамины (micronutrients).
            Верни JSON с ЧИСЛОВЫМИ значениями (без кавычек для чисел):
            { "name": "...", "calories": 100, "protein": 10, "fat": 5, "carbs": 20, "qualityScore": 5, "micronutrients": "..." }
            """

        let messages: [[String: Any]] = [
            ["role": "user", "content": prompt]
        ]

        return try await pSendMessage(messages: messages)
    }

    func analyzeFood(imageBase64: String) async throws -> FoodAnalysisResult {
        // Mock response if key is empty or placeholder
        if apiKey.isEmpty || apiKey == "YOUR_KEY" {
            // Return a delay and a mock
            try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
            return FoodAnalysisResult(
                name: "Тестовое Яблоко", calories: 95, protein: 0, fat: 0, carbs: 25,
                qualityScore: 8, micronutrients: "Витамин C")
        }

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // Construct the prompt for Gemini 2.0 Flash Lite via OpenRouter
        let model = "google/gemini-2.0-flash-lite-001"

        let prompt = """
            Проанализируй это фото еды. Определи блюдо, оцени калории и БЖУ (белки, жиры, углеводы) для всей порции.
            Также оцени "Качество питания" (qualityScore) от 1 до 10 (где 10 - очень полезно, много витаминов, 1 - фастфуд/сахар).
            Кратко перечисли основные витамины и микроэлементы (micronutrients) на русском языке.

            Верни ТОЛЬКО валидный JSON без markdown форматирования:
            {
                "name": "Название блюда",
                "calories": 123,
                "protein": 12,
                "fat": 5,
                "carbs": 20,
                "qualityScore": 8,
                "micronutrients": "Витамин C, Калий"
            }
            """

        let body: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": prompt,
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(imageBase64)"
                            ],
                        ],
                    ],
                ]
            ],
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        // Parse the nested JSON structure from OpenRouter/OpenAI
        // Response -> choices[0] -> message -> content -> String (JSON)
        // We need to decode the wrapper first, then the content string.

        let wrapper = try JSONDecoder().decode(OpenRouterResponse.self, from: data)
        guard let contentString = wrapper.choices.first?.message.content else {
            throw URLError(.cannotDecodeContentData)
        }

        // Clean markdown code blocks if present
        let cleanJSON = contentString.replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "").trimmingCharacters(
                in: .whitespacesAndNewlines)

        guard let jsonData = cleanJSON.data(using: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }

        return try JSONDecoder().decode(FoodAnalysisResult.self, from: jsonData)
    }
}

// Helper structs for decoding OpenRouter response
struct OpenRouterResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

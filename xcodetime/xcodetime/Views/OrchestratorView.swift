import AVFoundation
import SwiftData
import SwiftUI

struct OrchestratorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isProcessing = false

    // TTS Synthesizer
    private let synthesizer = AVSpeechSynthesizer()

    private var orchestrator: OrchestratorService? {
        if let apiKey = profiles.first?.apiKey, !apiKey.isEmpty {
            return OrchestratorService(apiKey: apiKey)
        }
        if !Config.openRouterAPIKey.isEmpty && Config.openRouterAPIKey.count > 10 {
            return OrchestratorService(apiKey: Config.openRouterAPIKey)
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Gradient
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.1), .clear], startPoint: .top,
                            endPoint: .bottom)
                    )
                    .frame(height: 1)

                // Chat History
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            if messages.isEmpty {
                                emptyStateView
                            }
                            ForEach(messages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                        .padding(.bottom, 100)  // Space for input area
                    }
                    .onChange(of: messages.count) { _ in
                        if let last = messages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Input Area
                inputArea
            }
            .navigationTitle("Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                speechRecognizer.requestAuthorization()
            }
        }
    }

    var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(.blue.gradient)
                .symbolEffect(.bounce, options: .repeating)

            Text("Я ваш AI Ассистент")
                .font(.title2)
                .bold()

            Text("Попросите меня спланировать день, записать еду или создать привычки.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 10) {
                SuggestionPill(text: "Спланируй тренировку на завтра в 8 утра")
                SuggestionPill(text: "Я съел салат Цезарь только что")
                SuggestionPill(text: "Напомни позвонить маме в воскресенье")
            }
            .padding(.top)
        }
        .padding(.top, 50)
        .opacity(0.8)
    }

    var inputArea: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: 12) {
                // Mic Button
                Button(action: toggleRecording) {
                    ZStack {
                        Circle()
                            .fill(
                                speechRecognizer.isRecording
                                    ? Color.red.gradient : Color.blue.gradient
                            )
                            .frame(width: 44, height: 44)

                        Image(systemName: speechRecognizer.isRecording ? "stop.fill" : "mic.fill")
                            .foregroundStyle(.white)
                            .font(.title3)
                    }
                }

                // Text Input
                TextField("Введите или скажите...", text: $inputText, axis: .vertical)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(20)
                    .lineLimit(1...5)
                    .onChange(of: speechRecognizer.transcript) { newValue in
                        if speechRecognizer.isRecording {
                            inputText = newValue
                        }
                    }

                // Send Button
                Button(action: sendMessage) {
                    ZStack {
                        Circle()
                            .fill(inputText.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                            .frame(width: 44, height: 44)

                        Image(systemName: "arrow.up")
                            .foregroundStyle(.white)
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                }
                .disabled(inputText.isEmpty || isProcessing)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }

    private func toggleRecording() {
        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
            inputText = speechRecognizer.transcript
        } else {
            do {
                try speechRecognizer.startRecording()
            } catch {
                print("Recording error: \(error)")
            }
        }
    }

    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        let userText = inputText
        inputText = ""
        messages.append(ChatMessage(role: .user, content: userText))

        guard let service = orchestrator else {
            messages.append(
                ChatMessage(
                    role: .assistant,
                    content:
                        "Пожалуйста, установите API Ключ в профиле для использования Оркестратора.")
            )
            return
        }

        isProcessing = true
        Task {
            do {
                let response = try await service.processRequest(userText, history: messages)
                try await handleAIResponse(response)
            } catch {
                messages.append(
                    ChatMessage(role: .assistant, content: "Ошибка: \(error.localizedDescription)"))
            }
            isProcessing = false
        }
    }

    @MainActor
    private func handleAIResponse(_ response: AICommandResponse) throws {
        // Did not speak the response as per user preference

        var attachments: [MessageAttachment] = []

        // Perform actions and create attachments
        for action in response.actions {
            switch action.type {
            case "create_task":
                if let data = action.taskData {
                    let newTask = TaskItem(
                        title: data.title,
                        scheduledDate: data.date ?? Date(),
                        notes: data.notes ?? "",
                        priority: data.priority ?? 1,
                        type: TaskType(rawValue: data.type ?? "Task") ?? .task
                    )
                    modelContext.insert(newTask)
                    attachments.append(.task(newTask))
                }

            case "create_habit":
                if let data = action.habitData {
                    let newHabit = Habit(
                        name: data.name, icon: data.icon ?? "star.fill",
                        frequency: data.frequency ?? "Daily")
                    modelContext.insert(newHabit)
                    attachments.append(.habit(newHabit))
                }

            case "log_food":
                if let data = action.foodData {
                    let newFood = FoodEntry(
                        name: data.name,
                        calories: data.calories ?? 0,
                        protein: data.protein ?? 0,
                        fat: data.fat ?? 0,
                        carbs: data.carbs ?? 0,
                        date: Date()
                    )
                    modelContext.insert(newFood)
                    attachments.append(.food(newFood))
                }

            default:
                break
            }
        }

        // Append message with attachments
        messages.append(
            ChatMessage(role: .assistant, content: response.responseText, attachments: attachments))
    }
}

// MARK: - Models & Subviews

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom) {
            if message.role == .user {
                Spacer()
                Text(message.content)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 16,
                            bottomLeadingRadius: 16,
                            bottomTrailingRadius: 2,
                            topTrailingRadius: 16
                        )
                    )
            } else if message.role == .assistant {
                VStack(alignment: .leading, spacing: 12) {
                    Text(message.content)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .foregroundStyle(.primary)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 16,
                                bottomLeadingRadius: 2,
                                bottomTrailingRadius: 16,
                                topTrailingRadius: 16
                            )
                        )

                    if !message.attachments.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Выполненные действия:")
                                .font(.caption2)
                                .textCase(.uppercase)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 8)

                            ForEach(message.attachments, id: \.id) { attachment in
                                AttachmentView(attachment: attachment)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
                }
                Spacer()
            }
        }
    }
}

struct AttachmentView: View {
    let attachment: MessageAttachment

    var body: some View {
        Group {
            switch attachment {
            case .task(let task):
                HStack {
                    Image(systemName: task.type.icon)
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.blue.gradient)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.title).fontWeight(.medium)
                        Text(task.scheduledDate, format: .dateTime.weekday().hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.green)
                }
            case .habit(let habit):
                HStack {
                    Image(systemName: habit.icon)
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.orange.gradient)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(habit.name).fontWeight(.medium)
                        Text("Привычка создана")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "star.fill")
                        .foregroundStyle(.orange)
                }
            case .food(let food):
                HStack {
                    Image(systemName: "fork.knife")
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.green.gradient)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(food.name).fontWeight(.medium)
                        Text("\(food.calories) ккал")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("Записано")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .foregroundStyle(.green)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

struct SuggestionPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(20)
    }
}

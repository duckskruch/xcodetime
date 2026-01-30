import PhotosUI
import SwiftData
import SwiftUI

struct NutritionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allFood: [FoodEntry]
    @Query private var profiles: [UserProfile]

    @State private var showingAddFood = false

    var userProfile: UserProfile? { profiles.first }

    var todaysEntries: [FoodEntry] {
        allFood.filter { Calendar.current.isDateInToday($0.date) }
    }

    var totalCalories: Int {
        todaysEntries.reduce(0) { $0 + $1.calories }
    }

    var todaysQualityScore: Double {
        let scores = todaysEntries.compactMap { $0.qualityScore }
        guard !scores.isEmpty else { return 0 }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Summary Card
                        NutritionSummaryCard(
                            total: totalCalories,
                            goal: userProfile?.dailyCalories ?? 2000
                        )
                        .padding(.horizontal)

                        // Quality Score Card
                        if todaysQualityScore > 0 {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Индекс качества")
                                        .font(.headline)
                                    Text("В среднем")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(String(format: "%.1f", todaysQualityScore))
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundStyle(
                                        todaysQualityScore >= 8
                                            ? .green : (todaysQualityScore >= 5 ? .orange : .red))
                                Text("/ 10")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                            )
                            .padding(.horizontal)
                        }

                        // Add Button
                        Button(action: { showingAddFood = true }) {
                            HStack {
                                Image(systemName: "fork.knife.circle.fill")
                                    .font(.title2)
                                Text("Добавить / Скан")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.gradient)
                            .foregroundStyle(.white)
                            .cornerRadius(16)
                            .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 3)
                        }
                        .padding(.horizontal)

                        // List of Food
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Сегодняшние приемы пищи")
                                .font(.headline)
                                .padding(.horizontal)

                            if todaysEntries.isEmpty {
                                ContentUnavailableView(
                                    "Нет записей", systemImage: "fork.knife",
                                    description: Text("Добавьте прием пищи для отслеживания.")
                                )
                                .padding(.top, 40)
                            } else {
                                ForEach(todaysEntries) { food in
                                    FoodRow(food: food)
                                        .contextMenu {
                                            Button("Delete", role: .destructive) {
                                                modelContext.delete(food)
                                            }
                                        }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("Nutrition")
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddFood) {
                AddFoodView()
            }
        }
    }
}

struct NutritionSummaryCard: View {
    let total: Int
    let goal: Int

    var progress: Double {
        guard goal > 0 else { return 0 }
        return Double(total) / Double(goal)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("Калории")
                    .font(.headline)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(total)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(progress > 1 ? .red : .primary)
                    Text("/ \(goal)")
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            ZStack {
                Circle()
                    .stroke(lineWidth: 8)
                    .opacity(0.1)
                    .foregroundStyle(.primary)
                Circle()
                    .trim(from: 0, to: min(progress, 1))
                    .stroke(Color.green.gradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 60, height: 60)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
}

struct FoodRow: View {
    let food: FoodEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(food.name)
                    .font(.headline)
                if let micros = food.micronutrients, !micros.isEmpty {
                    Text(micros)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 10) {
                    Label("\(food.protein)г Б", systemImage: "circle.fill")
                        .font(.caption2).foregroundStyle(.red)
                    Label("\(food.fat)г Ж", systemImage: "circle.fill")
                        .font(.caption2).foregroundStyle(.yellow)
                    Label("\(food.carbs)г У", systemImage: "circle.fill")
                        .font(.caption2).foregroundStyle(.green)
                }
            }
            Spacer()
            Text("\(food.calories)")
                .fontWeight(.bold)
            Text("kcal")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
        )
    }
}

struct AddFoodView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]

    @State private var name = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var fat = ""
    @State private var carbs = ""
    @State private var quickAddText = ""

    @State private var selectedItem: PhotosPickerItem?
    @State private var isAnalyzing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if isAnalyzing {
                        HStack {
                            ProgressView()
                                .padding(.trailing)
                            Text("Анализ...")
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                    } else {
                        // 1. Photo Picker
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            HStack {
                                Image(systemName: "camera.viewfinder")
                                    .font(.title2)
                                Text("Сканировать фото")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .foregroundStyle(.blue)
                        }
                        .onChange(of: selectedItem) { newItem in
                            Task {
                                await analyzeImage(item: newItem)
                            }
                        }

                        // 2. Text Input Analysis
                        HStack {
                            Image(systemName: "text.magnifyingglass")
                                .foregroundStyle(.blue)
                            TextField("Или опишите еду (например: 'Банан')", text: $quickAddText)
                                .submitLabel(.go)
                                .onSubmit {
                                    Task { await analyzeText() }
                                }
                            if !quickAddText.isEmpty {
                                Button(action: { Task { await analyzeText() } }) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.title2)
                                }
                            }
                        }
                        .padding(.vertical, 4)

                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }

                Section {
                    TextField("Название блюда", text: $name)
                    TextField("Калории", text: $calories)
                        .keyboardType(.numberPad)
                }

                Section {
                    HStack {
                        Text("Белки")
                        Spacer()
                        TextField("0", text: $protein)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .frame(width: 60)
                        Text("г")
                    }
                    HStack {
                        Text("Жиры")
                        Spacer()
                        TextField("0", text: $fat)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .frame(width: 60)
                        Text("г")
                    }
                    HStack {
                        Text("Углеводы")
                        Spacer()
                        TextField("0", text: $carbs)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .frame(width: 60)
                        Text("г")
                    }
                }
            }
            .navigationTitle("Добавить еду")
            .toolbar {
                Button("Отмена") { dismiss() }
                Button("Добавить") {
                    let cal = Int(calories) ?? 0
                    let p = Int(protein) ?? 0
                    let f = Int(fat) ?? 0
                    let c = Int(carbs) ?? 0

                    let food = FoodEntry(name: name, calories: cal, protein: p, fat: f, carbs: c)
                    modelContext.insert(food)
                    dismiss()
                }
                .disabled(name.isEmpty || calories.isEmpty)
            }
        }
    }

    private func analyzeText() async {
        guard !quickAddText.isEmpty else { return }
        withAnimation {
            isAnalyzing = true
            errorMessage = nil
        }

        do {
            var apiKey = profiles.first?.apiKey ?? ""
            if apiKey.isEmpty { apiKey = Config.openRouterAPIKey }

            // Simple mock for preview/no key
            if apiKey.isEmpty {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                // Mock
                self.name = quickAddText
                self.calories = "250"
                self.protein = "5"
                self.fat = "2"
                self.carbs = "40"
                isAnalyzing = false
                return
            }

            let client = OpenRouterClient(apiKey: apiKey)
            // Reuse analyzeFood logic? Not exactly, analyzeFood takes Image.
            // We need a analyzeFoodText.
            // Let's implement a quick inline call or add to OpenRouterClient.
            // For stability, let's add `analyzeFoodText` to OpenRouterClient in the next step.
            // Here I assume it exists or I will add it.
            let result = try await client.analyzeFoodText(text: quickAddText)

            withAnimation {
                self.name = result.name
                self.calories = String(result.calories)
                self.protein = String(result.protein)
                self.fat = String(result.fat)
                self.carbs = String(result.carbs)
            }
        } catch {
            errorMessage = "Ошибка AI: \(error.localizedDescription)"
        }

        withAnimation { isAnalyzing = false }
    }

    private func analyzeImage(item: PhotosPickerItem?) async {
        guard let item = item else { return }
        withAnimation {
            isAnalyzing = true
            errorMessage = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                errorMessage = "Не удалось загрузить данные изображения"
                isAnalyzing = false
                return
            }

            let base64 = data.base64EncodedString()
            var apiKey = profiles.first?.apiKey ?? ""
            if apiKey.isEmpty {
                apiKey = Config.openRouterAPIKey
            }

            // Simple mock for preview if key is empty, to show UX
            if apiKey.isEmpty {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                // Just proceed, OpenRouterClient handles the mock/empty key case too
            }

            let client = OpenRouterClient(apiKey: apiKey)
            let result = try await client.analyzeFood(imageBase64: base64)

            // Populate fields
            withAnimation {
                self.name = result.name
                self.calories = String(result.calories)
                self.protein = String(result.protein)
                self.fat = String(result.fat)
                self.carbs = String(result.carbs)
            }

        } catch {
            errorMessage = "Ошибка AI: \(error.localizedDescription)"
        }

        withAnimation {
            isAnalyzing = false
        }
    }
}

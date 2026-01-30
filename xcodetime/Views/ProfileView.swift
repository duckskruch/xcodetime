import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    var userProfile: UserProfile? {
        profiles.first
    }

    var body: some View {
        NavigationStack {
            Group {
                if let profile = userProfile {
                    ProfileFormView(profile: profile)
                } else {
                    ContentUnavailableView(
                        "Нет профиля", systemImage: "person.crop.circle.badge.questionmark",
                        description: Text("Создайте профиль, чтобы начать отслеживание."))
                    Button("Создать профиль") {
                        let newProfile = UserProfile()
                        modelContext.insert(newProfile)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Профиль")
        }
    }
}

struct ProfileFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var profile: UserProfile

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundStyle(.blue.gradient)
                        Text("Мой Профиль")
                            .font(.headline)
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section("Статистика") {
                HStack {
                    Text("Цель калорий")
                    Spacer()
                    Text("\(profile.dailyCalories) ккал")
                        .bold()
                        .foregroundStyle(.green)
                }

                Picker("Цель", selection: $profile.goal) {
                    Text("Похудение (-500)").tag("Lose")
                    Text("Поддержание").tag("Maintain")
                    Text("Набор (+500)").tag("Gain")
                }
            }

            Section("Личные данные") {
                HStack {
                    Text("Возраст")
                    Spacer()
                    TextField("Возраст", value: $profile.age, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 50)
                }

                Picker("Пол", selection: $profile.gender) {
                    Text("Мужской").tag("Male")
                    Text("Женский").tag("Female")
                }

                HStack {
                    Text("Рост (см)")
                    Spacer()
                    TextField("Рост", value: $profile.height, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                }

                HStack {
                    Text("Вес (кг)")
                    Spacer()
                    TextField("Вес", value: $profile.weight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                }

                Picker("Активность", selection: $profile.activityLevel) {
                    Text("Сидячий").tag("Sedentary")
                    Text("Легкая").tag("Light")
                    Text("Умеренная").tag("Moderate")
                    Text("Высокая").tag("Active")
                    Text("Очень высокая").tag("Very Active")
                }
            }

            Section("Настройки Ассистента") {
                SecureField("API Ключ", text: $profile.apiKey)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
    }
}

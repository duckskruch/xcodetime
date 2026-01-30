//
//  ContentView.swift
//  xcodetime
//
//  Created by Георгий Клецков on 29.01.2026.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Сегодня", systemImage: "sun.max.fill")
                }

            PlannerView()
                .tabItem {
                    Label("План", systemImage: "calendar")
                }

            NutritionView()
                .tabItem {
                    Label("Питание", systemImage: "fork.knife")
                }

            OrchestratorView()
                .tabItem {
                    Label("Ассистент", systemImage: "sparkles")
                }

            ProfileView()
                .tabItem {
                    Label("Профиль", systemImage: "person.circle.fill")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [UserProfile.self, Habit.self, TaskItem.self, FoodEntry.self], inMemory: true)
}

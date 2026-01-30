//
//  xcodetimeApp.swift
//  xcodetime
//
//  Created by Георгий Клецков on 29.01.2026.
//

import SwiftData
import SwiftUI

@main
struct xcodetimeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, Locale(identifier: "ru_RU"))
        }
        .modelContainer(for: [UserProfile.self, Habit.self, TaskItem.self, FoodEntry.self])
    }
}

//
//  WeatherApp.swift
//  Weather
//
//  Created by Sayan  Maity  on 11/12/25.
//

import SwiftUI
import CoreData

@main
struct WeatherApp: App {
    // Initialize the Database
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Inject the database context (The "Connection")
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

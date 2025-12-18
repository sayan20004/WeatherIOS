//
//  Persistence.swift
//  Weather
//
//  Created by Sayan  Maity  on 18/12/25.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init() {
        // This name must match the filename you created in Step 1 (WeatherModel)
        container = NSPersistentContainer(name: "Weather")
        
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
    }
}

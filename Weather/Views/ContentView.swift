//
//  ContentView.swift
//  Weather
//
//  Created by Sayan Maity on 11/12/25.
//

import SwiftUI
import CoreLocation
import CoreData // Import Core Data
import Lottie

struct ContentView: View {
    @StateObject var locationManager = LocationManager()
    
    // Connect to the Database
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var cityInput: String = ""
    @State private var forecast: Forecast?
    @State private var errorMessage: String = ""
    
    // Control for showing the History Sheet
    @State private var showHistory = false
    
    var body: some View {
        NavigationView { // Wrap in NavigationView for navigation
            VStack(spacing: 20) {
                Text("Weather Search")
                    .font(.largeTitle)
                    .bold()
                
                TextField("Enter city name", text: $cityInput)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .autocorrectionDisabled()
                
                HStack {
                    Button("Search City") {
                        fetchWeatherByCity()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(cityInput.isEmpty)
                    
                    Button(action: {
                        locationManager.requestLocation()
                    }) {
                        Image(systemName: "location.fill")
                    }
                    .buttonStyle(.bordered)
                    
                    // --- NEW: History Button ---
                    Button(action: {
                        showHistory = true
                    }) {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .buttonStyle(.bordered)
                    // ---------------------------
                }
                
                Divider()
                
                if locationManager.isLoading {
                    ProgressView("Finding you...")
                } else if let forecast = forecast {
                    // ... (Your Existing UI Code) ...
                    VStack(spacing: 10) {
                        Text("📍 \(forecast.name ?? "Unknown")")
                            .font(.headline)
                        
                        Text(formatDate(date: forecast.dt, timeZoneOffset: forecast.timezone))
                            .font(.caption)
                            .foregroundStyle(.gray)
                        
                        if let weather = forecast.weather.first {
                            // Pass the icon code (e.g., "01d") to our helper function
                            LottieView(filename: getLottieAnimation(for: weather.icon)) // Or whatever exact filename you have
                        }
                        let tempCelsius = forecast.main.min - 273.15
                        Text("\(String(format: "%.1f", tempCelsius))°C")
                            .font(.system(size: 50, weight: .bold))
                        
                        Text(forecast.weather.first?.description.capitalized ?? "")
                            .font(.title2)
                        
                        HStack(spacing: 20) {
                            VStack {
                                Text("Humidity")
                                Text("\(forecast.main.humidity)%").bold()
                            }
                            VStack {
                                Text("Clouds")
                                Text("\(forecast.clouds.cloudM)%").bold()
                            }
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    
                } else if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
                
                Spacer()
            }
            .padding()
            // Present the History Page
            .sheet(isPresented: $showHistory) {
                NavigationView {
                    HistoryView()
                    
                    // Add close button to sheet
                    .toolbar {
                         Button("Close") { showHistory = false }
                    }
                }
            }
            .onAppear {
                locationManager.requestLocation()
            }
            .onChange(of: locationManager.location) { newLocation in
                if let loc = newLocation {
                    fetchWeatherByLocation(lat: loc.latitude, lon: loc.longitude)
                }
            }
        }
    }
    
    // ... (fetch functions same as before) ...
    // Logic 1: Search by City Name
        func fetchWeatherByCity() {
            self.errorMessage = ""
            self.forecast = nil
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            
            APIservice.shared.getWeather(city: cityInput) { result in
                // ❌ FALSE: Do NOT save manual city searches
                handleResult(result, shouldSave: false)
            }
        }
        
        // Logic 2: Search by GPS
        func fetchWeatherByLocation(lat: Double, lon: Double) {
            self.errorMessage = ""
            self.cityInput = ""
            
            APIservice.shared.getWeatherByCoordinates(lat: lat, lon: lon) { result in
                // ✅ TRUE: Only save when it comes from GPS
                handleResult(result, shouldSave: true)
            }
        }
        
        // --- UPDATED HANDLER ---
        func handleResult(_ result: Result<Forecast, APIservice.APIError>, shouldSave: Bool) {
            switch result {
            case .success(let data):
                self.forecast = data
                
                // Check the flag before saving
                if shouldSave {
                    saveToCoreData(forecast: data)
                }
                
            case .failure(let error):
                switch error {
                case .error(let str): self.errorMessage = str
                }
            }
        }
    
    
    // New Helper Function to Save
    // Helper Function to Save (With Anti-Bloat Logic)
        func saveToCoreData(forecast: Forecast) {
            // 1. Anti-Bloat: Check if we saved this city recently (e.g., in the last 1 hour)
            let fetchRequest: NSFetchRequest<SavedForecast> = SavedForecast.fetchRequest()
            // Check for records with the same city name
            fetchRequest.predicate = NSPredicate(format: "cityName == %@", forecast.name)
            // Sort by newest first
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            // We only need to check the very last one
            fetchRequest.fetchLimit = 1

            do {
                let recentRecords = try viewContext.fetch(fetchRequest)
                if let lastRecord = recentRecords.first, let lastDate = lastRecord.timestamp {
                    // If the last record was saved less than 1 hour ago (3600 seconds)
                    if Date().timeIntervalSince(lastDate) < 3600 {
                        print("⚠️ Data for \(forecast.name) was saved recently. Skipping to prevent bloat.")
                        return // <--- STOP HERE, DO NOT SAVE
                    }
                }
            } catch {
                print("Error checking history: \(error)")
            }

            // 2. If no recent record exists, proceed to save
            let newRecord = SavedForecast(context: viewContext)
            newRecord.timestamp = Date()
            newRecord.cityName = forecast.name
            newRecord.temp = forecast.main.min - 273.15
            newRecord.icon = forecast.weather.first?.icon
            newRecord.descriptionText = forecast.weather.first?.description
            
            do {
                try viewContext.save()
                print("✅ New data saved to History!")
                
                // 3. Cleanup: Remove data older than 7 days
                deleteOldData()
            } catch {
                print("❌ Failed to save: \(error)")
            }
        }
        
        // Helper to delete records older than 7 days
        func deleteOldData() {
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = SavedForecast.fetchRequest()
            
            // Calculate the date 7 days ago
            let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            
            // Predicate: "timestamp is less than (older than) 7 days ago"
            fetchRequest.predicate = NSPredicate(format: "timestamp < %@", sevenDaysAgo as NSDate)
            
            // Batch delete request
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try viewContext.execute(deleteRequest)
                try viewContext.save()
                print("🗑️ Old history cleaned up.")
            } catch {
                print("Error cleaning up old data: \(error)")
            }
        }
    
    func formatDate(date: Date, timeZoneOffset: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, h:mm a"
        formatter.timeZone = TimeZone(secondsFromGMT: timeZoneOffset)
        return formatter.string(from: date)
    }
    // Helper to map OpenWeatherMap "icon codes" to your Lottie files
        func getLottieAnimation(for iconCode: String) -> String {
            var animationName = "sunny" // Default
            
            switch iconCode {
            case "01d": animationName = "sunny"            // Clear Sky (Day)
            case "01n": animationName = "moon"             // Clear Sky (Night)
            case "02d", "02n", "03d", "03n", "04d", "04n": animationName = "cloudy" // Clouds
            case "09d", "09n", "10d", "10n": animationName = "rain"   // Rain
            case "11d", "11n": animationName = "storm"     // Thunderstorm
            case "13d", "13n": animationName = "snow"      // Snow
            case "50d", "50n": animationName = "mist"      // Mist
            default: animationName = "sunny"
            }
            
            // --- DEBUG PRINT ---
            print("🔍 API Icon: \(iconCode) | Looking for Lottie file: '\(animationName)'")
            return animationName
        }
}

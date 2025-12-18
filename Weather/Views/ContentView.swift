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
        NavigationView {
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
                    
                    Button(action: {
                        showHistory = true
                    }) {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .buttonStyle(.bordered)
                }
                
                Divider()
                
                if locationManager.isLoading {
                    ProgressView("Finding you...")
                } else if let forecast = forecast {
                    VStack(spacing: 10) {
                        Text("📍 \(forecast.name ?? "Unknown")")
                            .font(.headline)
                        
                        Text(formatDate(date: forecast.dt, timeZoneOffset: forecast.timezone))
                            .font(.caption)
                            .foregroundStyle(.gray)
                        
                        if let weather = forecast.weather.first {
                            LottieView(filename: getLottieAnimation(for: weather.icon))
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
            .sheet(isPresented: $showHistory) {
                NavigationView {
                    HistoryView()
                    
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
    
        func fetchWeatherByCity() {
            self.errorMessage = ""
            self.forecast = nil
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            
            APIservice.shared.getWeather(city: cityInput) { result in
                handleResult(result, shouldSave: false)
            }
        }
        
        func fetchWeatherByLocation(lat: Double, lon: Double) {
            self.errorMessage = ""
            self.cityInput = ""
            
            APIservice.shared.getWeatherByCoordinates(lat: lat, lon: lon) { result in
                handleResult(result, shouldSave: true)
            }
        }
        
        func handleResult(_ result: Result<Forecast, APIservice.APIError>, shouldSave: Bool) {
            switch result {
            case .success(let data):
                self.forecast = data
                
                if shouldSave {
                    saveToCoreData(forecast: data)
                }
                
            case .failure(let error):
                switch error {
                case .error(let str): self.errorMessage = str
                }
            }
        }
    
    

        func saveToCoreData(forecast: Forecast) {
            let fetchRequest: NSFetchRequest<SavedForecast> = SavedForecast.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "cityName == %@", forecast.name)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            fetchRequest.fetchLimit = 1

            do {
                let recentRecords = try viewContext.fetch(fetchRequest)
                if let lastRecord = recentRecords.first, let lastDate = lastRecord.timestamp {
                    if Date().timeIntervalSince(lastDate) < 3600 {
                        print("⚠️ Data for \(forecast.name) was saved recently. Skipping to prevent bloat.")
                        return
                    }
                }
            } catch {
                print("Error checking history: \(error)")
            }

            let newRecord = SavedForecast(context: viewContext)
            newRecord.timestamp = Date()
            newRecord.cityName = forecast.name
            newRecord.temp = forecast.main.min - 273.15
            newRecord.icon = forecast.weather.first?.icon
            newRecord.descriptionText = forecast.weather.first?.description
            
            do {
                try viewContext.save()
                print("✅ New data saved to History!")
                
                deleteOldData()
            } catch {
                print("❌ Failed to save: \(error)")
            }
        }
        
        func deleteOldData() {
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = SavedForecast.fetchRequest()
            
            let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            
            fetchRequest.predicate = NSPredicate(format: "timestamp < %@", sevenDaysAgo as NSDate)
            
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

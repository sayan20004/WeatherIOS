//
//  ContentView.swift
//  Weather
//
//  Created by Sayan Maity on 11/12/25.
//

import SwiftUI
import CoreLocation


struct ContentView: View {
    @StateObject var locationManager = LocationManager()
    @State private var cityInput: String = ""
    @State private var forecast: Forecast?
    @State private var errorMessage: String = ""
    
    var body: some View {
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
                        AsyncImage(url: weather.weatherIconURL) { image in
                            image.resizable().aspectRatio(contentMode: .fit)
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 100, height: 100)
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
        .onAppear {
            
            locationManager.requestLocation()
        }
        
        .onChange(of: locationManager.location) { newLocation in
            if let loc = newLocation {
                print("Location found: \(loc.latitude), \(loc.longitude)")
                fetchWeatherByLocation(lat: loc.latitude, lon: loc.longitude)
            }
        }
    }
    
    
    func fetchWeatherByCity() {
        self.errorMessage = ""
        self.forecast = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        APIservice.shared.getWeather(city: cityInput) { result in
            handleResult(result)
        }
    }
    
    
    func fetchWeatherByLocation(lat: Double, lon: Double) {
        self.errorMessage = ""
        self.cityInput = ""
        
        APIservice.shared.getWeatherByCoordinates(lat: lat, lon: lon) { result in
            handleResult(result)
        }
    }
    
    
    func handleResult(_ result: Result<Forecast, APIservice.APIError>) {
        switch result {
        case .success(let data):
            self.forecast = data
        case .failure(let error):
            switch error {
            case .error(let str): self.errorMessage = str
            }
        }
    }
    
    func formatDate(date: Date, timeZoneOffset: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, h:mm a"
        formatter.timeZone = TimeZone(secondsFromGMT: timeZoneOffset)
        return formatter.string(from: date)
    }
}

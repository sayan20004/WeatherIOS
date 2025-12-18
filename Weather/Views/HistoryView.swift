//
//  HistoryView.swift
//  Weather
//
//  Created by Sayan  Maity  on 18/12/25.
//
import SwiftUI
import CoreData

struct HistoryView: View {
    @FetchRequest(
        entity: SavedForecast.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \SavedForecast.timestamp, ascending: false)]
    ) var savedForecasts: FetchedResults<SavedForecast>
    
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        List {
            ForEach(savedForecasts) { item in
                HStack {
                    // Weather Icon
                    if let iconCode = item.icon {
                        LottieView(filename: getLottieAnimation(for: iconCode))
                            .frame(width: 40, height: 40)
                    }
                    
                    VStack(alignment: .leading) {
                        Text(item.cityName ?? "Unknown")
                            .font(.headline)
                        Text(item.descriptionText?.capitalized ?? "")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("\(String(format: "%.1f", item.temp))°C")
                            .bold()
                        
                        // --- UPDATED: Shows Date AND Time ---
                        if let date = item.timestamp {
                            Text(formatTimestamp(date))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        // ------------------------------------
                    }
                }
            }
            .onDelete(perform: deleteItems)
        }
        .navigationTitle("History")
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { savedForecasts[$0] }.forEach(viewContext.delete)
            do {
                try viewContext.save()
            } catch {
                print("Error deleting: \(error)")
            }
        }
    }
    
    // Helper to format "Dec 12, 10:30 AM"
    func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a" // <--- Format String
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

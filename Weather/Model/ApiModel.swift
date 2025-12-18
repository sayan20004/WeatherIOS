//
//  ApiModel.swift
//  Weather
//
//  Created by Sayan  Maity  on 11/12/25.
//
import Foundation

struct Forecast: Codable {
    let name: String
    let dt: Date
    let timezone: Int
    
    struct Main: Codable {
        let min: Double
        let max: Double
        let humidity: Int
        
        enum CodingKeys: String, CodingKey {
            case min = "temp_min"
            case max = "temp_max"
            case humidity
        }
    }
    let main: Main
    
    struct Weather: Codable {
        let id: Int
        let description: String
        let icon: String
        
        var weatherIconURL: URL {
            let urlString = "https://openweathermap.org/img/wn/\(icon)@2x.png"
            return URL(string: urlString)!
        }
    }
    let weather: [Weather]
    
    struct Clouds: Codable {
        let cloudM: Int
        enum CodingKeys: String, CodingKey {
            case cloudM = "all"
        }
    }
    let clouds: Clouds
}

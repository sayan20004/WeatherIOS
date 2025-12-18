//
//  APIservice.swift
//  Weather
//
//  Created by Sayan Maity on 12/12/25.
//

import Foundation

class APIservice {
    static let shared = APIservice()
    private let apiKey = "ebaadf244dc6f14920c90d34db4111d8"
    
    enum APIError: Error {
        case error(_ errorString: String)
    }
    
    
    func getWeather(city: String, completion: @escaping (Result<Forecast, APIError>) -> Void) {
        guard let encodedCity = city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            completion(.failure(.error("Invalid city name")))
            return
        }
        let urlString = "https://api.openweathermap.org/data/2.5/weather?q=\(encodedCity)&appid=\(apiKey)"
        getJSON(urlString: urlString, completion: completion)
    }
    
    
    func getWeatherByCoordinates(lat: Double, lon: Double, completion: @escaping (Result<Forecast, APIError>) -> Void) {
        let urlString = "https://api.openweathermap.org/data/2.5/weather?lat=\(lat)&lon=\(lon)&appid=\(apiKey)"
        getJSON(urlString: urlString, completion: completion)
    }
    
    
    func getJSON(urlString: String, completion: @escaping (Result<Forecast, APIError>) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(.failure(.error("Error: Invalid URL")))
            return
        }
        
        let request = URLRequest(url: url)
        
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                completion(.failure(.error("Error: \(error.localizedDescription)")))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 404 {
                    DispatchQueue.main.async {
                        completion(.failure(.error("City not found. Please check spelling.")))
                    }
                    return
                }
            }
            
            guard let data = data else {
                completion(.failure(.error("Error: Data is invalid")))
                return
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            
            do {
                let decodedData = try decoder.decode(Forecast.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(decodedData))
                }
            } catch let decodingError {
                DispatchQueue.main.async {
                    print("Decoding Error: \(decodingError)")
                    completion(.failure(APIError.error("Error: \(decodingError.localizedDescription)")))
                }
            }
        }.resume()
    }
}

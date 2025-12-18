//
//  LocationManager.swift
//  Weather
//
//  Created by Sayan  Maity  on 12/12/25.
//

import Foundation
import CoreLocation
import Combine


class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    
    @Published var location: CLLocationCoordinate2D?
    @Published var isLoading = false
    
    override init() {
        super.init()
        manager.delegate = self
    }
    
    func requestLocation() {
        isLoading = true
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }
    
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.first?.coordinate
        isLoading = false
    }
    
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
        isLoading = false
    }
}
extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

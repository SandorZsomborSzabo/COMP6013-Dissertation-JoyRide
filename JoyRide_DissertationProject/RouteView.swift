//
//  RouteView.swift
//  JoyRide_DissertationProject
//
//  Created by macbook on 27/01/2025.
//

import SwiftUI
import MapKit
import CoreLocation

/// Wrap CLLocationCoordinate2D so it can be used in `annotationItems:`
struct IdentifiableCoordinate: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

class RouteLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var lastLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to find user’s location: \(error.localizedDescription)")
    }
}

struct RouteView: View {
    @StateObject private var locationManager = LocationManager()

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var selectedTime: Int = 30
    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    
    // We keep the annotation items in an array of IdentifiableCoordinate
    @State private var annotationItems: [IdentifiableCoordinate] = []

    var body: some View {
        VStack {
            Picker("Trip Duration", selection: $selectedTime) {
                Text("30 Min").tag(30)
                Text("60 Min").tag(60)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            Button("Generate Round Trip") {
                generateRoundTrip()
            }
            .padding()

            // Use annotationItems array:
            Map(coordinateRegion: $region,
                showsUserLocation: true,
                annotationItems: annotationItems
            ) { item in
                MapMarker(coordinate: item.coordinate, tint: .blue)
            }
            .overlay(
                // Just a placeholder overlay showing how many route points we have
                Text("Route has \(routeCoordinates.count) points.")
                    .foregroundColor(.red)
                    .padding(),
                alignment: .top
            )
            .edgesIgnoringSafeArea(.bottom)
        }
        .onAppear {
            locationManager.requestLocation()
        }
    }

    private func generateRoundTrip() {
        guard let userLocation = locationManager.lastLocation else {
            print("No user location available yet.")
            return
        }

        // We'll do a basic approach as in the previous example.
        // This is purely to show how to fix the Identifiable requirement.

        // 1) Suppose we just want to place a "destination" 1 mile away for demo
        let milesAway = (selectedTime == 30) ? 5.0 : 10.0
        let destination = randomCoordinate(from: userLocation.coordinate, withinMiles: milesAway)

        // For demo, let's just store these two points as "annotations"
        annotationItems = [
            IdentifiableCoordinate(coordinate: userLocation.coordinate),
            IdentifiableCoordinate(coordinate: destination)
        ]
        
        // We'll skip actual route logic for brevity, or you can do your MKDirections request here
        routeCoordinates = [userLocation.coordinate, destination]
        
        // Optionally recenter the map
        region = regionThatFitsAll(coords: routeCoordinates)
    }

    // Helper to produce a random coordinate ~X miles from origin
    private func randomCoordinate(from origin: CLLocationCoordinate2D, withinMiles distanceMiles: Double) -> CLLocationCoordinate2D {
        // ... same logic from the earlier example ...
        let distanceMeters = distanceMiles * 1609.34
        let bearing = Double.random(in: 0..<360) * .pi / 180
        let earthRadius: Double = 6378137
        let angularDistance = distanceMeters / earthRadius

        let lat1 = origin.latitude * .pi / 180
        let lon1 = origin.longitude * .pi / 180

        let lat2 = asin(sin(lat1) * cos(angularDistance)
                        + cos(lat1) * sin(angularDistance) * cos(bearing))
        let lon2 = lon1 + atan2(sin(bearing) * sin(angularDistance) * cos(lat1),
                                cos(angularDistance) - sin(lat1) * sin(lat2))

        return CLLocationCoordinate2D(latitude: lat2 * 180 / .pi,
                                      longitude: lon2 * 180 / .pi)
    }

    private func regionThatFitsAll(coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coords.isEmpty else { return region }
        
        var minLat = coords[0].latitude
        var maxLat = coords[0].latitude
        var minLon = coords[0].longitude
        var maxLon = coords[0].longitude
        
        for c in coords {
            if c.latitude < minLat { minLat = c.latitude }
            if c.latitude > maxLat { maxLat = c.latitude }
            if c.longitude < minLon { minLon = c.longitude }
            if c.longitude > maxLon { maxLon = c.longitude }
        }
        
        let spanLat = maxLat - minLat
        let spanLon = maxLon - minLon
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(latitudeDelta: spanLat * 1.4, longitudeDelta: spanLon * 1.4)
        
        return MKCoordinateRegion(center: center, span: span)
    }
}


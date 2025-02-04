//
//  RouteView.swift
//  JoyRide_DissertationProject
//
//  Created by macbook on 27/01/2025.
//

import SwiftUI
import GoogleMaps
import GoogleMapsUtils
import GooglePlaces

/// **ViewModel for Google Maps Navigation**
class GoogleNavigationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var isNavigating = false
    @Published var polyline: GMSPolyline?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func startNavigation(to destination: CLLocationCoordinate2D, on mapView: GMSMapView) {
        guard let userLocation = userLocation else {
            print("User location not available.")
            return
        }
        
        let origin = "\(userLocation.latitude),\(userLocation.longitude)"
        let dest = "\(destination.latitude),\(destination.longitude)"
        
        // Replace with your real Google Directions API key
        let urlString = "https://maps.googleapis.com/maps/api/directions/json?origin=\(origin)&destination=\(dest)&mode=driving&key=AIzaSyCR4UzC0O1xZRP2Jf8A6LIShdThU4Znir0"
        
        guard let url = URL(string: urlString) else {
            print("Invalid Google Directions API URL.")
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                print("Error fetching directions: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else { return }
            
            do {
                let result = try JSONDecoder().decode(GoogleDirectionsResponse.self, from: data)
                
                // Check if the API request was successful
                guard result.status == "OK", let route = result.routes?.first else {
                    print("Directions API error: \(result.status)")
                    return
                }
                
                // Proceed with the valid route
                let overviewPolyline = route.overviewPolyline.points
                
                DispatchQueue.main.async {
                    let path = GMSPath(fromEncodedPath: overviewPolyline)
                    self.polyline = GMSPolyline(path: path)
                    self.polyline?.strokeColor = .blue
                    self.polyline?.strokeWidth = 5
                    self.polyline?.map = mapView
                    self.isNavigating = true
                }
            } catch {
                print("Failed to decode directions response: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    func stopNavigation() {
        DispatchQueue.main.async {
            self.polyline?.map = nil
            self.isNavigating = false
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.last?.coordinate
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to get location: \(error.localizedDescription)")
    }
}

/// **SwiftUI View for Route Navigation**
struct RouteView: View {
    @StateObject private var navManager = GoogleNavigationManager()
    @State private var mapView = GMSMapView()
    @State private var selectedTime: Int = 30
    @State private var destination: CLLocationCoordinate2D?
    
    var body: some View {
        VStack {
            Picker("Trip Duration", selection: $selectedTime) {
                Text("30 Min").tag(30)
                Text("60 Min").tag(60)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            HStack {
                Button("Generate Route") {
                    generateRoute()
                }
                .padding()
                
                Button(navManager.isNavigating ? "Stop Navigation" : "Start Navigation") {
                    if navManager.isNavigating {
                        navManager.stopNavigation()
                    } else if let destination = destination {
                        navManager.startNavigation(to: destination, on: mapView)
                    }
                }
                .padding()
                .background(navManager.isNavigating ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            GoogleMapView(mapView: $mapView, userLocation: $navManager.userLocation)
                .edgesIgnoringSafeArea(.bottom)
                .onAppear {
                    navManager.requestPermission()
                }
        }
    }
    
    private func generateRoute() {
        guard let userLocation = navManager.userLocation else {
            print("User location not available yet.")
            return
        }
        
        let milesAway = (selectedTime == 30) ? 5.0 : 10.0
        let randomDest = randomCoordinate(from: userLocation, withinMiles: milesAway)
        destination = randomDest
    }
    
    private func randomCoordinate(from origin: CLLocationCoordinate2D, withinMiles distanceMiles: Double) -> CLLocationCoordinate2D {
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
}

/// **Google Maps UIView Wrapper for SwiftUI**
struct GoogleMapView: UIViewRepresentable {
    @Binding var mapView: GMSMapView
    @Binding var userLocation: CLLocationCoordinate2D?
    
    func makeUIView(context: Context) -> GMSMapView {
        mapView.settings.myLocationButton = true
        mapView.isMyLocationEnabled = true
        return mapView
    }
    
    func updateUIView(_ mapView: GMSMapView, context: Context) {
        if let userLocation = userLocation {
            let camera = GMSCameraPosition.camera(withLatitude: userLocation.latitude, longitude: userLocation.longitude, zoom: 14)
            mapView.camera = camera
        }
    }
}

/// **Google Directions API Response**
struct GoogleDirectionsResponse: Codable {
    let routes: [Route]?
    let status: String
}

struct Route: Codable {
    let overviewPolyline: OverviewPolyline
    
    enum CodingKeys: String, CodingKey {
        case overviewPolyline = "overview_polyline"
    }
}

struct OverviewPolyline: Codable {
    let points: String
}

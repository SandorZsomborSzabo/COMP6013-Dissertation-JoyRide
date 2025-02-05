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
import AVFoundation   // For spoken instructions
import CoreLocation
// Import the Navigation SDK module – ensure your project is configured to use it.
import GoogleNavigation

// MARK: - GoogleDirectionsResponse Models
// (Retained for backwards compatibility; not used with the Navigation SDK.)
struct GoogleDirectionsResponse: Codable {
    let routes: [Route]?
    let status: String
}

struct Route: Codable {
    let legs: [Leg]?
    let overviewPolyline: OverviewPolyline
    
    enum CodingKeys: String, CodingKey {
        case legs
        case overviewPolyline = "overview_polyline"
    }
}

struct Leg: Codable {
    let steps: [Step]?
    let startLocation: Coordinate?
    let endLocation: Coordinate?
    
    enum CodingKeys: String, CodingKey {
        case steps
        case startLocation = "start_location"
        case endLocation = "end_location"
    }
}

struct Step: Codable {
    let htmlInstructions: String?
    let distance: Value?
    let duration: Value?
    let startLocation: Coordinate?
    let endLocation: Coordinate?
    let polyline: OverviewPolyline?
    
    enum CodingKeys: String, CodingKey {
        case htmlInstructions = "html_instructions"
        case distance
        case duration
        case startLocation = "start_location"
        case endLocation = "end_location"
        case polyline
    }
}

struct Value: Codable {
    let text: String
    let value: Int
}

struct Coordinate: Codable {
    let lat: Double
    let lng: Double
}

struct OverviewPolyline: Codable {
    let points: String
}

// MARK: - GoogleNavigationManager (using Navigation SDK)
class GoogleNavigationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    // Published properties used by SwiftUI
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var isNavigating = false
    
    // The following properties are retained from your previous implementation.
    @Published var steps: [Step] = []
    @Published var currentStepIndex: Int = 0
    @Published var polyline: GMSPolyline?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    // MARK: - Location Authorisation
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    // MARK: - Start Navigation using the Navigation SDK
    func startNavigation(to destination: CLLocationCoordinate2D, on mapView: GMSMapView) {
        // Unwrap the optional waypoint
        guard let waypoint = GMSNavigationWaypoint(location: destination, title: "Destination") else {
            print("Failed to create navigation waypoint.")
            return
        }
        let destinations = [waypoint]
        
        // Set the destinations; the Navigation SDK will calculate the route.
        mapView.navigator?.setDestinations(destinations) { routeStatus in
            guard routeStatus == .OK else {
                print("Route error: \(routeStatus)")
                return
            }
            
            // Activate guidance mode to start turn-by-turn navigation.
            mapView.navigator?.isGuidanceActive = true
            
            // Set the camera mode to following for a third-person view.
            mapView.cameraMode = .following
            
            DispatchQueue.main.async {
                self.isNavigating = true
            }
        }
    }

    // MARK: - Stop Navigation using the Navigation SDK
    func stopNavigation(on mapView: GMSMapView) {
        // Deactivate guidance mode
        mapView.navigator?.isGuidanceActive = false
        
        // Revert camera mode to free, which gives control back to the user.
        mapView.cameraMode = .free
        
        DispatchQueue.main.async {
            self.isNavigating = false
            // Clear any leftover polyline or step data (if applicable)
            self.polyline?.map = nil
            self.polyline = nil
            self.steps = []
            self.currentStepIndex = 0
        }
    }
    
    // MARK: - CLLocationManagerDelegate Methods
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.last?.coordinate
        // Additional location tracking logic can be added here.
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to get location: \(error.localizedDescription)")
    }
    
}

// MARK: - GoogleMapView (SwiftUI Wrapper)
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
            let camera = GMSCameraPosition.camera(
                withLatitude: userLocation.latitude,
                longitude: userLocation.longitude,
                zoom: 14
            )
            mapView.animate(to: camera)
        }
    }
}

// MARK: - Main SwiftUI View
struct RouteView: View {
    @StateObject private var navManager = GoogleNavigationManager()
    @State private var mapView = GMSMapView()
    @State private var selectedTime: Int = 30
    @State private var destination: CLLocationCoordinate2D?
    
    var body: some View {
        VStack {
            // Picker for choosing route duration/distance
            Picker("Trip Duration", selection: $selectedTime) {
                Text("30 Min").tag(30)
                Text("60 Min").tag(60)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // Buttons for generating a route and starting/stopping navigation
            HStack {
                Button("Generate Route") {
                    generateRoute()
                }
                .padding()
                
                Button(navManager.isNavigating ? "Stop Navigation" : "Start Navigation") {
                    if navManager.isNavigating {
                        navManager.stopNavigation(on: mapView)
                    } else if let destination = destination {
                        navManager.startNavigation(to: destination, on: mapView)
                    }
                }
                .padding()
                .background(navManager.isNavigating ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            // Display the Google Map
            GoogleMapView(mapView: $mapView, userLocation: $navManager.userLocation)
                .edgesIgnoringSafeArea(.bottom)
                .onAppear {
                    // Present T&C on first appearance
                    let companyName = "Your Company Name"
                    GMSNavigationServices.showTermsAndConditionsDialogIfNeeded(withCompanyName: companyName) { accepted in
                        if accepted {
                            print("User accepted the Navigation Terms and Conditions.")
                            // Enable navigation once user accepts T&C
                            mapView.isNavigationEnabled = true
                        } else {
                            print("User did not accept the Navigation Terms and Conditions.")
                            // Handle rejection if needed
                            mapView.isNavigationEnabled = false
                        }
                    }
                    
                    navManager.requestPermission()
                }
        }
        // Optional overlay to show current navigation state
        .overlay(
            VStack {
                if navManager.isNavigating {
                    Text("Navigating...")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                }
            }
            .padding()
            .background(Color.black.opacity(0.7))
            .cornerRadius(8)
            .padding(),
            alignment: .top
        )
    }
    
    // MARK: - Generate a Random Destination
    private func generateRoute() {
        guard let userLocation = navManager.userLocation else {
            print("User location not available yet.")
            return
        }
        
        // Estimate distance based on selected duration:
        // 30 minutes ~ 5 miles, 60 minutes ~ 10 miles.
        let milesAway = (selectedTime == 30) ? 5.0 : 10.0
        destination = randomCoordinate(from: userLocation, withinMiles: milesAway)
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
        
        return CLLocationCoordinate2D(
            latitude: lat2 * 180 / .pi,
            longitude: lon2 * 180 / .pi
        )
    }
}

// MARK: - Preview
struct RouteView_Previews: PreviewProvider {
    static var previews: some View {
        RouteView()
    }
}

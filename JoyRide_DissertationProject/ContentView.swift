//
//  ContentView.swift
//  JoyRide_DissertationProject
//
//  Created by macbook on 29/12/2024.
//  Updated to use Google Maps in HomeView on 11/02/2025.
//

import SwiftUI
import GoogleMaps
import CoreLocation

struct ContentView: View {
    let username: String
    @State private var selectedTab: AppTab = .home // Tracks the currently selected tab
    @State private var isAuthenticated: Bool = true // Tracks authentication status

    var body: some View {
        VStack(spacing: 0) {
            // Display the content of the selected tab
            switch selectedTab {
            case .home:
                HomeView()   // Updated HomeView uses GoogleMapView
            case .route:
                RouteView()
            case .social:
                SocialView(currentUsername: username)
            case .settings:
                SettingsView(username: username, isAuthenticated: $isAuthenticated)
            }

            // Tab bar with dark background and green-themed buttons
            HStack(spacing: 0) {
                TabButton(title: "Home", isActive: selectedTab == .home) {
                    selectedTab = .home
                }
                Divider().background(Color.green)
                TabButton(title: "Route", isActive: selectedTab == .route) {
                    selectedTab = .route
                }
                Divider().background(Color.green)
                TabButton(title: "Social", isActive: selectedTab == .social) {
                    selectedTab = .social
                }
                Divider().background(Color.green)
                TabButton(title: "Settings", isActive: selectedTab == .settings) {
                    selectedTab = .settings
                }
            }
            .frame(height: 100) // Height of the tab bar
            .background(Color.black)
            .border(Color.green, width: 1)
        }
        .edgesIgnoringSafeArea(.bottom) // Ensure the tab bar sits at the bottom
    }
}

// Define the tabs (no changes needed here)
enum AppTab {
    case home
    case route
    case social
    case settings
}

// Custom button for the tab bar with dark mode styling and green theme
struct TabButton: View {
    let title: String
    let isActive: Bool // Indicates if this is the active tab
    let action: () -> Void

    // Define a green gradient similar to the one used in RouteView
    private var greenGradient: LinearGradient {
        LinearGradient(gradient: Gradient(colors: [Color.green.opacity(0.7), Color.green]),
                       startPoint: .leading, endPoint: .trailing)
    }
    
    // Computed property to return an AnyShapeStyle so both branches of the ternary operator match
    private var fillStyle: AnyShapeStyle {
        if isActive {
            return AnyShapeStyle(greenGradient)
        } else {
            return AnyShapeStyle(Color.clear)
        }
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Rectangle()
                    .fill(fillStyle)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text(title)
                    .font(.headline)
                    .foregroundColor(isActive ? Color.white : Color.green)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Updated HomeView using GoogleMapView with dark header styling
struct HomeView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var mapView = GMSMapView()  // Google Maps view instance
    @State private var userLocation: CLLocationCoordinate2D?

    var body: some View {
        VStack(spacing: 0) {
            // Header with real-time date and time in dark mode
            HStack {
                Text(getDayOfWeek())
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.leading)
                
                Spacer()
                
                Text(getCurrentDate())
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(getCurrentTime())
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.trailing)
            }
            .padding()
            .background(Color.black)
            .border(Color.green, width: 1)
            
            // Google Map view using the SwiftUI wrapper defined in your RouteView file.
            GoogleMapView(mapView: $mapView, userLocation: $userLocation)
                .border(Color.black, width: 1)
                .onReceive(locationManager.$lastLocation) { newLocation in
                    if let newLocation = newLocation {
                        userLocation = newLocation.coordinate
                        // Animate the camera to the updated user location with a zoom level of 15.
                        let camera = GMSCameraPosition.camera(withLatitude: newLocation.coordinate.latitude,
                                                              longitude: newLocation.coordinate.longitude,
                                                              zoom: 15)
                        mapView.animate(to: camera)
                    }
                }
        }
        .onAppear {
            locationManager.requestLocation() // Request user location on view appearance
        }
    }
    
    // Function to get the current day of the week
    func getDayOfWeek() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE" // Full name of the day
        return formatter.string(from: Date())
    }
    
    // Function to get the current date in MM/dd/yyyy format
    func getCurrentDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.string(from: Date())
    }
    
    // Function to get the current time in HH:mm:ss format
    func getCurrentTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
}

// LocationManager (unchanged)
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var lastLocation: CLLocation?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocation() {
        let status = manager.authorizationStatus
        
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        } else {
            print("Location permission not granted. Please enable it in Settings.")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        } else if status == .denied || status == .restricted {
            print("Location access denied. Please enable it in Settings.")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to find user’s location: \(error.localizedDescription)")
    }
}

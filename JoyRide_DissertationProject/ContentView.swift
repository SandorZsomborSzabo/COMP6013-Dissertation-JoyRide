//
//  ContentView.swift
//  JoyRide_DissertationProject
//
//  Created by macbook on 29/12/2024.
//

import SwiftUI
import MapKit
import CoreLocation // Import CoreLocation for location services

struct ContentView: View {
    @State private var selectedTab: AppTab = .home // Tracks the currently selected tab

    var body: some View {
        VStack(spacing: 0) {
            // Display the content of the selected tab
            switch selectedTab {
            case .home:
                HomeView()
            case .route:
                PlaceholderView(title: "Route")
            case .social:
                PlaceholderView(title: "Social")
            case .settings:
                PlaceholderView(title: "Settings")
            }

            // Tab bar
            HStack(spacing: 0) {
                TabButton(title: "Home", isActive: selectedTab == .home) {
                    selectedTab = .home
                }
                Divider()
                TabButton(title: "Route", isActive: selectedTab == .route) {
                    selectedTab = .route
                }
                Divider()
                TabButton(title: "Social", isActive: selectedTab == .social) {
                    selectedTab = .social
                }
                Divider()
                TabButton(title: "Settings", isActive: selectedTab == .settings) {
                    selectedTab = .settings
                }
            }
            .frame(height: 75) // Height of the tab bar
            .background(Color(UIColor.systemGray5))
            .border(Color.black, width: 1)
        }
        .edgesIgnoringSafeArea(.bottom) // Ensure the tab bar sits at the bottom
    }
}

// Define the tabs
enum AppTab {
    case home
    case route
    case social
    case settings
}

// Custom button for the tab bar
struct TabButton: View {
    let title: String
    let isActive: Bool // Indicates if this is the active tab
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Rectangle()
                    .fill(isActive ? Color.gray : Color.clear) // Active tab is slightly darker
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.black)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Home View with Dynamic Date, Time, and Exact Location
struct HomeView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // Default location
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05) // Zoom level
    )

    var body: some View {
        VStack(spacing: 0) {
            // Header with real-time date and time
            HStack {
                Text(getDayOfWeek())
                    .font(.headline)
                    .padding(.leading)
                
                Spacer()
                
                Text(getCurrentDate())
                    .font(.headline)
                
                Spacer()
                
                Text(getCurrentTime())
                    .font(.headline)
                    .padding(.trailing)
            }
            .padding()
            .background(Color(UIColor.systemGray5)) // Light gray background
            .border(Color.black, width: 1)

            // Interactive Map with user location
            Map(coordinateRegion: $region, showsUserLocation: true)
                .onAppear {
                    if let location = locationManager.lastLocation {
                        region.center = location.coordinate // Update region to user's location
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .border(Color.black, width: 1)
        }
        .onAppear {
            locationManager.requestLocation() // Request user location
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
        formatter.dateFormat = "MM/dd/yyyy" // Format for the date
        return formatter.string(from: Date())
    }
    
    // Function to get the current time in HH:mm:ss format
    func getCurrentTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss" // 24-hour format for time with seconds
        return formatter.string(from: Date())
    }
}

// Location Manager to Handle User Location
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
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

// Placeholder View for other tabs
struct PlaceholderView: View {
    let title: String

    var body: some View {
        VStack {
            Spacer()
            Text("\(title) Page")
                .font(.largeTitle)
                .foregroundColor(.gray)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .border(Color.black, width: 1)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}




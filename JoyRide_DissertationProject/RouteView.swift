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
import CoreLocation
import AVFoundation
import GoogleNavigation

// MARK: - CurvatureOption (Picker)
/// Added a "noCurve" option
enum CurvatureOption: String, CaseIterable {
    case noCurve = "No Curve"
    case lessCurved = "Less Curved"   // c_300 (≥300)
    case moreCurved = "More Curved"   // c_1000 (≥1000)
}

// MARK: - RoadSegment Model
struct RoadSegment {
    let coordinates: [CLLocationCoordinate2D]
    
    // Midpoint for approximate distance checking
    var midpoint: CLLocationCoordinate2D {
        guard !coordinates.isEmpty else {
            return .init(latitude: 0, longitude: 0)
        }
        let midIndex = coordinates.count / 2
        return coordinates[midIndex]
    }
    
    /// Return a random coordinate along this segment
    func randomCoordinate() -> CLLocationCoordinate2D? {
        guard coordinates.count > 1 else {
            return coordinates.first
        }
        let index = Int.random(in: 0..<coordinates.count)
        return coordinates[index]
    }
    
    /// Create a RoadSegment from a KML <coordinates> string
    static func fromKMLLineString(_ lineString: String) -> RoadSegment? {
        // Typical KML: "longitude,latitude,alt ... longitude,latitude,alt"
        let pairs = lineString.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        var coords: [CLLocationCoordinate2D] = []
        for pair in pairs {
            let nums = pair.split(separator: ",").compactMap { Double($0) }
            if nums.count >= 2 {
                let lon = nums[0]
                let lat = nums[1]
                coords.append(.init(latitude: lat, longitude: lon))
            }
        }
        return coords.isEmpty ? nil : RoadSegment(coordinates: coords)
    }
}

// MARK: - KMLParser (Minimal)
/// Simple parser extracting <coordinates> from <LineString> in a KML
class KMLParser: NSObject, XMLParserDelegate {
    private var currentElement: String = ""
    private var currentCoordinates: String = ""
    private var lineStrings: [String] = []
    
    func parseKML(from url: URL) -> [String]? {
        guard let parser = XMLParser(contentsOf: url) else {
            return nil
        }
        parser.delegate = self
        let success = parser.parse()
        return success ? lineStrings : nil
    }
    
    // MARK: - XMLParserDelegate
    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if currentElement == "coordinates" {
            currentCoordinates += string
        }
    }
    
    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {
        if elementName == "coordinates" {
            let coords = currentCoordinates.trimmingCharacters(in: .whitespacesAndNewlines)
            lineStrings.append(coords)
            currentCoordinates = ""
        }
        currentElement = ""
    }
}

// MARK: - Distance Helper (Haversine)
func distanceBetween(_ lat1: Double, _ lon1: Double,
                     _ lat2: Double, _ lon2: Double) -> Double {
    let R = 6378137.0 // Earth radius in meters
    let dLat = (lat2 - lat1) * .pi / 180
    let dLon = (lon2 - lon1) * .pi / 180
    let a = sin(dLat/2) * sin(dLat/2) +
            cos(lat1 * .pi/180) * cos(lat2 * .pi/180) *
            sin(dLon/2) * sin(dLon/2)
    let c = 2 * atan2(sqrt(a), sqrt(1-a))
    return R * c
}

// MARK: - GoogleDirectionsResponse Models (unused placeholders)
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

// MARK: - GoogleNavigationManager
class GoogleNavigationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var isNavigating = false
    
    // Retained from older code
    @Published var steps: [Step] = []
    @Published var currentStepIndex: Int = 0
    @Published var polyline: GMSPolyline?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    // Request location permission
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    // Start navigation (Google Navigation SDK)
    func startNavigation(to destination: CLLocationCoordinate2D, on mapView: GMSMapView) {
        guard let waypoint = GMSNavigationWaypoint(location: destination, title: "Destination") else {
            print("Failed to create navigation waypoint.")
            return
        }
        
        mapView.navigator?.setDestinations([waypoint]) { routeStatus in
            guard routeStatus == .OK else {
                print("Route error: \(routeStatus)")
                return
            }
            
            mapView.navigator?.isGuidanceActive = true
            mapView.cameraMode = .following
            
            DispatchQueue.main.async {
                self.isNavigating = true
            }
        }
    }
    
    // Stop navigation
    func stopNavigation(on mapView: GMSMapView) {
        mapView.navigator?.isGuidanceActive = false
        mapView.cameraMode = .free
        
        DispatchQueue.main.async {
            self.isNavigating = false
            self.polyline?.map = nil
            self.polyline = nil
            self.steps = []
            self.currentStepIndex = 0
        }
    }
    
    // MARK: CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.last?.coordinate
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

// MARK: - RouteView
struct RouteView: View {
    @StateObject private var navManager = GoogleNavigationManager()
    @State private var mapView = GMSMapView()
    
    // Time selection
    @State private var selectedTime: Int = 30
    
    // Curvature selection
    // NOTE: Now includes "noCurve"
    @State private var selectedCurvatureThreshold: CurvatureOption = .noCurve
    
    // Destination
    @State private var destination: CLLocationCoordinate2D?
    
    // Array of road segments from KML (only used for lessCurved / moreCurved)
    @State private var roadSegments: [RoadSegment] = []
    
    var body: some View {
        VStack {
            // Time Picker
            Picker("Trip Duration", selection: $selectedTime) {
                Text("30 Min").tag(30)
                Text("60 Min").tag(60)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // Curvature Picker (now has 3 options: No Curve, Less Curved, More Curved)
            Picker("Curvature", selection: $selectedCurvatureThreshold) {
                ForEach(CurvatureOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .onChange(of: selectedCurvatureThreshold) { _ in
                // If user picks "No Curve," we won't load KML
                // Otherwise, we load the relevant KML
                if selectedCurvatureThreshold == .noCurve {
                    // Clear out any existing segments so we don't do a leftover route
                    roadSegments = []
                } else {
                    loadLocalKML()
                }
            }
            
            // Control Buttons
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
            
            // Google Map
            GoogleMapView(mapView: $mapView, userLocation: $navManager.userLocation)
                .edgesIgnoringSafeArea(.bottom)
                .onAppear {
                    let companyName = "Your Company Name"
                    GMSNavigationServices.showTermsAndConditionsDialogIfNeeded(withCompanyName: companyName) { accepted in
                        mapView.isNavigationEnabled = accepted
                    }
                    navManager.requestPermission()
                    
                    // Initially, if we start with .noCurve, do not load KML
                    // If you prefer a default "lessCurved," set that above
                    if selectedCurvatureThreshold != .noCurve {
                        loadLocalKML()
                    }
                }
        }
        // Overlay for navigation state
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
        guard let userLoc = navManager.userLocation else {
            print("User location not available.")
            return
        }
        
        // Approx distance for 30/60 min
        let milesAway = (selectedTime == 30) ? 5.0 : 10.0
        
        switch selectedCurvatureThreshold {
        case .noCurve:
            // If user wants "No Curve," pick a purely random coordinate
            destination = randomCoordinate(from: userLoc, withinMiles: milesAway)
            
        case .lessCurved, .moreCurved:
            // We use the road segments approach
            destination = randomCoordinateOnCurvyRoads(
                origin: userLoc,
                maxDistanceMiles: milesAway,
                roadSegments: roadSegments
            )
        }
    }
    
    /// Original random bearing approach for "No Curve"
    private func randomCoordinate(from origin: CLLocationCoordinate2D,
                                  withinMiles distanceMiles: Double) -> CLLocationCoordinate2D {
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
    
    /// Curvy approach: pick from loaded "roadSegments"
    private func randomCoordinateOnCurvyRoads(
        origin: CLLocationCoordinate2D,
        maxDistanceMiles: Double,
        roadSegments: [RoadSegment]
    ) -> CLLocationCoordinate2D? {
        
        let maxDistanceMeters = maxDistanceMiles * 1609.34
        let nearbySegments = roadSegments.filter { seg in
            let dist = distanceBetween(
                origin.latitude, origin.longitude,
                seg.midpoint.latitude, seg.midpoint.longitude
            )
            return dist <= maxDistanceMeters
        }
        
        guard !nearbySegments.isEmpty else {
            print("No segments found within \(maxDistanceMiles) miles.")
            return nil
        }
        
        guard let chosenSegment = nearbySegments.randomElement(),
              let randomCoord = chosenSegment.randomCoordinate()
        else {
            return nil
        }
        
        return randomCoord
    }
    
    // MARK: - Load Local KML (for lessCurved / moreCurved only)
    private func loadLocalKML() {
        let subfolder: String
        let kmlFileName: String
        
        switch selectedCurvatureThreshold {
        case .lessCurved:
            subfolder   = "CurvatureData/great-britain.c_300/great-britain"
            kmlFileName = "doc_c300"
            
        case .moreCurved:
            subfolder   = "CurvatureData/great-britain.c_1000/great-britain"
            kmlFileName = "doc_c1000"
            
        case .noCurve:
            // Should never hit here because we skip if noCurve
            return
        }
        
        guard let kmlURL = Bundle.main.url(
            forResource: kmlFileName,
            withExtension: "kml",
            subdirectory: subfolder
        ) else {
            print("Could not find \(kmlFileName).kml in \(subfolder).")
            return
        }
        
        // Parse the KML
        let parser = KMLParser()
        if let lines = parser.parseKML(from: kmlURL) {
            let segments = lines.compactMap { RoadSegment.fromKMLLineString($0) }
            self.roadSegments = segments
            print("Loaded \(segments.count) road segments from \(kmlFileName).kml.")
        } else {
            print("Failed to parse \(kmlFileName).kml at \(kmlURL).")
        }
    }
}

// MARK: - Preview
struct RouteView_Previews: PreviewProvider {
    static var previews: some View {
        RouteView()
    }
}

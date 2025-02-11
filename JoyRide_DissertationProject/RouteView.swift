//
//  RouteView.swift
//  JoyRide_DissertationProject
//
//  Created by macbook on 27/01/2025.
//  Updated for round-trip route visibility and custom map styling on 11/02/2025.
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
    case noCurve = "Less Curved"
    case lessCurved = "Curved"   // c_300 (≥300)
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
    
    // Start navigation (Google Navigation SDK) for a single destination – kept for backward compatibility.
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
    
    // Start round-trip navigation with multiple waypoints.
    func startRoundTripNavigation(with waypoints: [CLLocationCoordinate2D], on mapView: GMSMapView) {
        let navWaypoints = waypoints.compactMap { GMSNavigationWaypoint(location: $0, title: "") }
        guard !navWaypoints.isEmpty else {
            print("Failed to create navigation waypoints.")
            return
        }
        
        mapView.navigator?.setDestinations(navWaypoints) { routeStatus in
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

extension GMSMapView {
    func loadMapStyle(named fileName: String) {
        do {
            if let styleURL = Bundle.main.url(forResource: fileName, withExtension: "json") {
                self.mapStyle = try GMSMapStyle(contentsOfFileURL: styleURL)
                //print("\(fileName).json successfully loaded.")
            } else {
                print("Unable to find \(fileName).json in the main bundle")
            }
        } catch {
            print("Failed to load map style: \(error)")
        }
    }
}

// MARK: - GoogleMapView (SwiftUI Wrapper)
// This updated wrapper re-applies the custom style in updateUIView and via a delegate callback.
struct GoogleMapView: UIViewRepresentable {
    @Binding var mapView: GMSMapView
    @Binding var userLocation: CLLocationCoordinate2D?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> GMSMapView {
        mapView.settings.myLocationButton = true
        mapView.isMyLocationEnabled = true
        // Set the delegate to our coordinator
        mapView.delegate = context.coordinator
        // Apply the custom style initially.
        mapView.loadMapStyle(named: "dark_yellow_map_style")
        return mapView
    }
    
    func updateUIView(_ mapView: GMSMapView, context: Context) {
        // Reapply the style on every update.
        mapView.loadMapStyle(named: "dark_yellow_map_style")
    }
    
    class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: GoogleMapView
        
        init(_ parent: GoogleMapView) {
            self.parent = parent
        }
        
        func mapViewDidFinishTileRendering(_ mapView: GMSMapView) {
            // Once tile rendering finishes, try reapplying the style.
            mapView.loadMapStyle(named: "dark_yellow_map_style")
        }
    }
}

// MARK: - RouteView
struct RouteView: View {
    @StateObject private var navManager = GoogleNavigationManager()
    @State private var mapView = GMSMapView()
    
    // Time selection (30, 60, or 90 minutes)
    @State private var selectedTime: Int = 30
    
    // Curvature selection (includes "noCurve")
    @State private var selectedCurvatureThreshold: CurvatureOption = .noCurve
    
    // Destination (for the outbound leg) and startLocation (to remember where we began)
    @State private var destination: CLLocationCoordinate2D?
    @State private var startLocation: CLLocationCoordinate2D?
    
    // Array of road segments from KML (used for lessCurved / moreCurved)
    @State private var roadSegments: [RoadSegment] = []
    
    // Polylines for outbound, return, and the combined round-trip route
    @State private var outboundPolyline: GMSPolyline?
    @State private var returnPolyline: GMSPolyline?
    @State private var combinedPolyline: GMSPolyline?
    
    var body: some View {
        VStack {
            // Time Picker (30, 60, or 90 minutes)
            Picker("Trip Duration", selection: $selectedTime) {
                Text("30 Min").tag(30)
                Text("60 Min").tag(60)
                Text("90 Min").tag(90)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // Curvature Picker (No Curve, Less Curved, More Curved)
            Picker("Curvature", selection: $selectedCurvatureThreshold) {
                ForEach(CurvatureOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .onChange(of: selectedCurvatureThreshold) { _ in
                if selectedCurvatureThreshold == .noCurve {
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
                    } else if let dest = destination, let start = startLocation {
                        // Start round-trip navigation using two waypoints:
                        navManager.startRoundTripNavigation(with: [dest, start], on: mapView)
                    }
                }
                .padding()
                .background(navManager.isNavigating ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            // Google Map view
            GoogleMapView(mapView: $mapView, userLocation: $navManager.userLocation)
                .edgesIgnoringSafeArea(.bottom)
                .onAppear {
                    let companyName = "Your Company Name"
                    // Show Terms & Conditions. The accepted value sets isNavigationEnabled.
                    GMSNavigationServices.showTermsAndConditionsDialogIfNeeded(withCompanyName: companyName) { accepted in
                        mapView.isNavigationEnabled = accepted
                    }
                    navManager.requestPermission()
                    
                    if selectedCurvatureThreshold != .noCurve {
                        loadLocalKML()
                    }
                }
        }
        // Overlay to indicate navigation state
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
    
    // MARK: - Generate a Round Trip Route (and display it on the map)
    private func generateRoute() {
        guard let userLoc = navManager.userLocation else {
            print("User location not available.")
            return
        }
        
        // Save the starting location.
        startLocation = userLoc
        
        // For a round-trip, take half the total trip distance for the outbound leg.
        let totalMiles = Double(selectedTime) / 30.0 * 5.0
        let outboundMiles = totalMiles / 2.0
        
        var dest: CLLocationCoordinate2D?
        
        switch selectedCurvatureThreshold {
        case .noCurve:
            dest = randomCoordinate(from: userLoc, withinMiles: outboundMiles)
        case .lessCurved, .moreCurved:
            dest = randomCoordinateOnCurvyRoads(
                origin: userLoc,
                maxDistanceMiles: outboundMiles,
                roadSegments: roadSegments
            )
        }
        
        guard let destination = dest else {
            print("Failed to generate destination.")
            return
        }
        self.destination = destination
        
        // Clear any existing polylines.
        outboundPolyline?.map = nil
        returnPolyline?.map = nil
        combinedPolyline?.map = nil
        
        // Fetch both outbound and return routes.
        fetchRoundTripRoutes(from: userLoc, to: destination) { outboundPath, returnPath in
            if let outPath = outboundPath, let retPath = returnPath {
                // Combine the two paths into one round-trip route.
                let combinedPath = GMSMutablePath()
                for i in 0..<outPath.count() {
                    combinedPath.add(outPath.coordinate(at: i))
                }
                for i in 0..<retPath.count() {
                    combinedPath.add(retPath.coordinate(at: i))
                }
                DispatchQueue.main.async {
                    // Draw the combined route in purple.
                    let polyline = GMSPolyline(path: combinedPath)
                    polyline.strokeColor = .purple
                    polyline.strokeWidth = 5.0
                    polyline.map = mapView
                    self.combinedPolyline = polyline
                    
                    // Adjust camera to show the entire route.
                    var bounds = GMSCoordinateBounds()
                    for i in 0..<combinedPath.count() {
                        bounds = bounds.includingCoordinate(combinedPath.coordinate(at: i))
                    }
                    let update = GMSCameraUpdate.fit(bounds, withPadding: 60.0)
                    mapView.animate(with: update)
                }
            } else {
                print("Failed to fetch round trip routes.")
            }
        }
    }
    
    /// Fetches both an outbound route (origin -> destination) and a return route (destination -> origin)
    /// using the Directions API (with alternatives), then chooses a pair that minimizes overlap.
    private func fetchRoundTripRoutes(from origin: CLLocationCoordinate2D,
                                      to destination: CLLocationCoordinate2D,
                                      completion: @escaping (GMSPath?, GMSPath?) -> Void) {
        fetchRoutes(from: origin, to: destination) { outboundPaths in
            self.fetchRoutes(from: destination, to: origin) { returnPaths in
                if let pair = self.chooseDisjointPair(outboundPaths: outboundPaths, returnPaths: returnPaths) {
                    completion(pair.outbound, pair.return)
                } else {
                    // Fallback: use the first available routes.
                    completion(outboundPaths.first, returnPaths.first)
                }
            }
        }
    }
    
    /// Helper: Fetches an array of routes (as GMSPath) from the Directions API.
    private func fetchRoutes(from origin: CLLocationCoordinate2D,
                             to destination: CLLocationCoordinate2D,
                             completion: @escaping ([GMSPath]) -> Void) {
        let apiKey = "YOUR_GOOGLE_MAPS_API_KEY"
        var urlComponents = URLComponents(string: "https://maps.googleapis.com/maps/api/directions/json")!
        urlComponents.queryItems = [
            URLQueryItem(name: "origin", value: "\(origin.latitude),\(origin.longitude)"),
            URLQueryItem(name: "destination", value: "\(destination.latitude),\(destination.longitude)"),
            URLQueryItem(name: "alternatives", value: "true"),
            URLQueryItem(name: "key", value: apiKey)
        ]
        
        guard let url = urlComponents.url else {
            print("Failed to create URL for directions request.")
            completion([])
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error fetching directions: \(error)")
                completion([])
                return
            }
            guard let data = data else {
                print("No data returned from directions request.")
                completion([])
                return
            }
            do {
                let decoder = JSONDecoder()
                let directionsResponse = try decoder.decode(GoogleDirectionsResponse.self, from: data)
                var paths: [GMSPath] = []
                if let routes = directionsResponse.routes {
                    for route in routes {
                        let polylineString = route.overviewPolyline.points
                        if let path = GMSPath(fromEncodedPath: polylineString) {
                            paths.append(path)
                        }
                    }
                }
                completion(paths)
            } catch {
                print("Error decoding directions response: \(error)")
                completion([])
            }
        }.resume()
    }
    
    /// Chooses a pair of outbound and return paths that minimizes overlap.
    private func chooseDisjointPair(outboundPaths: [GMSPath],
                                    returnPaths: [GMSPath]) -> (outbound: GMSPath, `return`: GMSPath)? {
        var bestPair: (GMSPath, GMSPath)?
        var bestScore: Double = Double.greatestFiniteMagnitude
        
        for outPath in outboundPaths {
            for retPath in returnPaths {
                let score = overlapScore(path1: outPath, path2: retPath)
                if score < bestScore {
                    bestScore = score
                    bestPair = (outPath, retPath)
                }
            }
        }
        return bestPair
    }
    
    /// A simple heuristic that counts points in path1 within 50 meters of any point in path2.
    private func overlapScore(path1: GMSPath, path2: GMSPath) -> Double {
        var score: Double = 0
        for i in 0..<path1.count() {
            let coord1 = path1.coordinate(at: i)
            for j in 0..<path2.count() {
                let coord2 = path2.coordinate(at: j)
                let d = distanceBetween(coord1.latitude, coord1.longitude, coord2.latitude, coord2.longitude)
                if d < 50 { // 50-meter threshold
                    score += 1
                    break
                }
            }
        }
        return score
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
    
    /// Curvy approach: pick a random coordinate from loaded road segments.
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
    
    // MARK: - Load Local KML (for lessCurved / moreCurved)
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

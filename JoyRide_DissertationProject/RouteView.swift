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
enum CurvatureOption: String, CaseIterable {
    case noCurve = "Less Curved"
    case lessCurved = "Curved"   // c_300 (≥300)
    case moreCurved = "More Curved"   // c_1000 (≥1000)
}

// MARK: - ElevationOption (Picker)
enum ElevationOption: String, CaseIterable {
    case noElevation = "No Elevation"
    case lessElevation = "Less Elevation"
    case moreElevation = "More Elevation"
}

// MARK: - RoadSegment Model
struct RoadSegment {
    let coordinates: [CLLocationCoordinate2D]
    
    var midpoint: CLLocationCoordinate2D {
        guard !coordinates.isEmpty else { return .init(latitude: 0, longitude: 0) }
        let midIndex = coordinates.count / 2
        return coordinates[midIndex]
    }
    
    func randomCoordinate() -> CLLocationCoordinate2D? {
        guard coordinates.count > 1 else { return coordinates.first }
        let index = Int.random(in: 0..<coordinates.count)
        return coordinates[index]
    }
    
    static func fromKMLLineString(_ lineString: String) -> RoadSegment? {
        let pairs = lineString.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        var coords: [CLLocationCoordinate2D] = []
        for pair in pairs {
            let nums = pair.split(separator: ",").compactMap { Double($0) }
            if nums.count >= 2 {
                let lon = nums[0], lat = nums[1]
                coords.append(.init(latitude: lat, longitude: lon))
            }
        }
        return coords.isEmpty ? nil : RoadSegment(coordinates: coords)
    }
}

// MARK: - KMLParser (Minimal)
class KMLParser: NSObject, XMLParserDelegate {
    private var currentElement = ""
    private var currentCoordinates = ""
    private var lineStrings: [String] = []
    
    func parseKML(from url: URL) -> [String]? {
        guard let parser = XMLParser(contentsOf: url) else { return nil }
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

// MARK: - Elevation Response Models
struct ElevationResponse: Codable {
    let results: [ElevationResult]
    let status: String
}

struct ElevationResult: Codable {
    let elevation: Double
}

// MARK: - GoogleNavigationManager
class GoogleNavigationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var isNavigating = false
    @Published var steps: [Step] = []
    @Published var currentStepIndex: Int = 0
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
    
    // Single destination navigation
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
    
    // Round-trip navigation
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
    
    // MARK: - CLLocationManagerDelegate
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
                print("\(fileName).json successfully loaded.")
            } else {
                print("Unable to find \(fileName).json in the main bundle")
            }
        } catch {
            print("Failed to load map style: \(error)")
        }
    }
}

// MARK: - GoogleMapView (SwiftUI Wrapper)
struct GoogleMapView: UIViewRepresentable {
    @Binding var mapView: GMSMapView
    @Binding var userLocation: CLLocationCoordinate2D?
    
    func makeUIView(context: Context) -> GMSMapView {
        mapView.settings.myLocationButton = true
        mapView.isMyLocationEnabled = true
        mapView.loadMapStyle(named: "dark_yellow_map_style")
        mapView.delegate = context.coordinator
        return mapView
    }
    
    func updateUIView(_ mapView: GMSMapView, context: Context) {
        mapView.loadMapStyle(named: "dark_yellow_map_style")
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: GoogleMapView
        init(_ parent: GoogleMapView) {
            self.parent = parent
        }
        func mapViewDidFinishTileRendering(_ mapView: GMSMapView) {
            mapView.loadMapStyle(named: "dark_yellow_map_style")
        }
    }
}

// MARK: - StyledGoogleMapView (Container)
struct StyledGoogleMapView: UIViewControllerRepresentable {
    @Binding var mapView: GMSMapView
    @Binding var userLocation: CLLocationCoordinate2D?
    
    func makeUIViewController(context: Context) -> UIViewController {
        let vc = MapViewController()
        vc.mapView = mapView
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if let vc = uiViewController as? MapViewController {
            vc.mapView.loadMapStyle(named: "dark_yellow_map_style")
        }
    }
}

class MapViewController: UIViewController, GMSMapViewDelegate {
    var mapView: GMSMapView!
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        mapView.settings.myLocationButton = true
        mapView.isMyLocationEnabled = true
        view.addSubview(mapView)
        mapView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        mapView.loadMapStyle(named: "dark_yellow_map_style")
    }
    
    func mapViewDidFinishTileRendering(_ mapView: GMSMapView) {
        mapView.loadMapStyle(named: "dark_yellow_map_style")
    }
}

// MARK: - RouteView
struct RouteView: View {
    // Setting the tab bar tint in the initializer makes the bottom tab buttons green.
    init() {
        UITabBar.appearance().tintColor = UIColor.green
    }
    
    @StateObject private var navManager = GoogleNavigationManager()
    @State private var mapView = GMSMapView()
    @State private var showFilters: Bool = true  // Toggle filters visibility
    
    // Time selection
    @State private var selectedTime: Int = 30
    
    // Curvature selection
    @State private var selectedCurvatureThreshold: CurvatureOption = .noCurve
    
    // Elevation selection
    @State private var selectedElevationOption: ElevationOption = .noElevation
    
    // Destination & start
    @State private var destination: CLLocationCoordinate2D?
    @State private var startLocation: CLLocationCoordinate2D?
    
    // Road segments
    @State private var roadSegments: [RoadSegment] = []
    
    // Polylines
    @State private var outboundPolyline: GMSPolyline?
    @State private var returnPolyline: GMSPolyline?
    @State private var combinedPolyline: GMSPolyline?
    
    // Define the green gradient
    private var greenGradient: LinearGradient {
        LinearGradient(gradient: Gradient(colors: [Color.green.opacity(0.7), Color.green]),
                       startPoint: .leading, endPoint: .trailing)
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(gradient: Gradient(colors: [Color.black, Color(red: 0.0, green: 0.15, blue: 0.0)]),
                           startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 16) {
                // Toggle button for showing/hiding filters
                HStack {
                    Button(action: {
                        withAnimation {
                            showFilters.toggle()
                        }
                    }) {
                        Text(showFilters ? "Hide Filters" : "Show Filters")
                            .padding(8)
                            .background(greenGradient)
                            .cornerRadius(8)
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                
                // Filters UI
                if showFilters {
                    VStack(spacing: 16) {
                        // Time Picker
                        Picker("Trip Duration", selection: $selectedTime) {
                            Text("30 Min").tag(30)
                            Text("60 Min").tag(60)
                            Text("90 Min").tag(90)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(8)
                        .background(greenGradient)
                        .cornerRadius(8)
                        .tint(.white)
                        
                        // Curvature Picker
                        Picker("Curvature", selection: $selectedCurvatureThreshold) {
                            ForEach(CurvatureOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(8)
                        .background(greenGradient)
                        .cornerRadius(8)
                        .tint(.white)
                        .onChange(of: selectedCurvatureThreshold) { _ in
                            if selectedCurvatureThreshold == .noCurve {
                                roadSegments = []
                            } else {
                                loadLocalKML()
                            }
                        }
                        
                        // Elevation Picker
                        Picker("Elevation", selection: $selectedElevationOption) {
                            ForEach(ElevationOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(8)
                        .background(greenGradient)
                        .cornerRadius(8)
                        .tint(.white)
                        
                        // Control Buttons
                        HStack(spacing: 16) {
                            Button("Generate Route") {
                                generateRoute()
                            }
                            .padding()
                            .background(greenGradient)
                            .cornerRadius(10)
                            .foregroundColor(.white)
                            .font(.system(.headline, design: .rounded))
                            
                            Button(navManager.isNavigating ? "Stop Navigation" : "Start Navigation") {
                                if navManager.isNavigating {
                                    navManager.stopNavigation(on: mapView)
                                } else if let dest = destination, let start = startLocation {
                                    navManager.startRoundTripNavigation(with: [dest, start], on: mapView)
                                }
                            }
                            .padding()
                            .background(
                                navManager.isNavigating
                                ? LinearGradient(gradient: Gradient(colors: [Color.red.opacity(0.7), Color.red]),
                                                 startPoint: .leading, endPoint: .trailing)
                                : greenGradient
                            )
                            .cornerRadius(10)
                            .foregroundColor(.white)
                            .font(.system(.headline, design: .rounded))
                        }
                    }
                }
                
                // Google Map View expands to fill remaining space
                StyledGoogleMapView(mapView: $mapView, userLocation: $navManager.userLocation)
                    .edgesIgnoringSafeArea(.bottom)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        let companyName = "Your Company Name"
                        GMSNavigationServices.showTermsAndConditionsDialogIfNeeded(withCompanyName: companyName) { accepted in
                            mapView.isNavigationEnabled = accepted
                        }
                        navManager.requestPermission()
                        if selectedCurvatureThreshold != .noCurve {
                            loadLocalKML()
                        }
                    }
            }
            .padding()
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
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
    
    // MARK: - Route Generation and Utility Methods
    private func generateRoute() {
        guard let userLoc = navManager.userLocation else {
            print("User location not available.")
            return
        }
        startLocation = userLoc
        let totalMiles = Double(selectedTime) / 30.0 * 5.0
        let outboundMiles = totalMiles / 2.0
        
        if selectedElevationOption == .noElevation {
            var dest: CLLocationCoordinate2D?
            switch selectedCurvatureThreshold {
            case .noCurve:
                dest = randomCoordinate(from: userLoc, withinMiles: outboundMiles)
            case .lessCurved, .moreCurved:
                dest = randomCoordinateOnCurvyRoads(origin: userLoc, maxDistanceMiles: outboundMiles, roadSegments: roadSegments)
            }
            guard let destination = dest else {
                print("Failed to generate destination.")
                return
            }
            self.destination = destination
            proceedWithRouteGeneration(from: userLoc, to: destination)
        } else {
            generateCandidateRoute(userLoc: userLoc, outboundMiles: outboundMiles, attempt: 1, maxAttempts: 5) { candidate in
                guard let candidate = candidate else {
                    print("Failed to generate candidate route with elevation preferences.")
                    return
                }
                DispatchQueue.main.async {
                    self.destination = candidate
                    self.proceedWithRouteGeneration(from: userLoc, to: candidate)
                }
            }
        }
    }
    
    private func proceedWithRouteGeneration(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) {
        outboundPolyline?.map = nil
        returnPolyline?.map = nil
        combinedPolyline?.map = nil
        
        fetchRoundTripRoutes(from: origin, to: destination) { outboundPath, returnPath in
            if let outPath = outboundPath, let retPath = returnPath {
                let combinedPath = GMSMutablePath()
                for i in 0..<outPath.count() {
                    combinedPath.add(outPath.coordinate(at: i))
                }
                for i in 0..<retPath.count() {
                    combinedPath.add(retPath.coordinate(at: i))
                }
                DispatchQueue.main.async {
                    let polyline = GMSPolyline(path: combinedPath)
                    polyline.strokeColor = .purple
                    polyline.strokeWidth = 5.0
                    polyline.map = mapView
                    self.combinedPolyline = polyline
                    
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
    
    private func generateCandidateRoute(userLoc: CLLocationCoordinate2D, outboundMiles: Double, attempt: Int, maxAttempts: Int, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        var candidate: CLLocationCoordinate2D?
        if selectedCurvatureThreshold == .noCurve {
            candidate = randomCoordinate(from: userLoc, withinMiles: outboundMiles)
        } else {
            candidate = randomCoordinateOnCurvyRoads(origin: userLoc, maxDistanceMiles: outboundMiles, roadSegments: roadSegments)
        }
        guard let candidateCoord = candidate else {
            completion(nil)
            return
        }
        getElevation(for: userLoc) { startElevation in
            guard let startElevation = startElevation else { completion(candidateCoord); return }
            self.getElevation(for: candidateCoord) { candidateElevation in
                guard let candidateElevation = candidateElevation else { completion(candidateCoord); return }
                let elevationDifference = abs(candidateElevation - startElevation)
                let thresholdLess = 20.0
                let thresholdMore = 50.0
                var conditionMet = false
                switch self.selectedElevationOption {
                case .lessElevation:
                    conditionMet = elevationDifference <= thresholdLess
                case .moreElevation:
                    conditionMet = elevationDifference >= thresholdMore
                default:
                    conditionMet = true
                }
                if conditionMet {
                    completion(candidateCoord)
                } else if attempt < maxAttempts {
                    self.generateCandidateRoute(userLoc: userLoc, outboundMiles: outboundMiles, attempt: attempt + 1, maxAttempts: maxAttempts, completion: completion)
                } else {
                    completion(candidateCoord)
                }
            }
        }
    }
    
    private func getElevation(for coordinate: CLLocationCoordinate2D, completion: @escaping (Double?) -> Void) {
        let apiKey = "AIzaSyCR4UzC0O1xZRP2Jf8A6LIShdThU4Znir0"
        let urlString = "https://maps.googleapis.com/maps/api/elevation/json?locations=\(coordinate.latitude),\(coordinate.longitude)&key=\(apiKey)"
        guard let url = URL(string: urlString) else { completion(nil); return }
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error { print("Elevation API error: \(error)"); completion(nil); return }
            guard let data = data else { completion(nil); return }
            do {
                let elevationResponse = try JSONDecoder().decode(ElevationResponse.self, from: data)
                let elevation = elevationResponse.results.first?.elevation
                completion(elevation)
            } catch {
                print("Elevation decoding error: \(error)")
                completion(nil)
            }
        }.resume()
    }
    
    private func fetchRoundTripRoutes(from origin: CLLocationCoordinate2D,
                                      to destination: CLLocationCoordinate2D,
                                      completion: @escaping (GMSPath?, GMSPath?) -> Void) {
        fetchRoutes(from: origin, to: destination) { outboundPaths in
            self.fetchRoutes(from: destination, to: origin) { returnPaths in
                if let pair = self.chooseDisjointPair(outboundPaths: outboundPaths, returnPaths: returnPaths) {
                    completion(pair.outbound, pair.return)
                } else {
                    completion(outboundPaths.first, returnPaths.first)
                }
            }
        }
    }
    
    private func fetchRoutes(from origin: CLLocationCoordinate2D,
                             to destination: CLLocationCoordinate2D,
                             completion: @escaping ([GMSPath]) -> Void) {
        let apiKey = "AIzaSyCR4UzC0O1xZRP2Jf8A6LIShdThU4Znir0"
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
            if let error = error { print("Error fetching directions: \(error)"); completion([]); return }
            guard let data = data else { print("No data returned from directions request."); completion([]); return }
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
    
    private func overlapScore(path1: GMSPath, path2: GMSPath) -> Double {
        var score: Double = 0
        for i in 0..<path1.count() {
            let coord1 = path1.coordinate(at: i)
            for j in 0..<path2.count() {
                let coord2 = path2.coordinate(at: j)
                let d = distanceBetween(coord1.latitude, coord1.longitude, coord2.latitude, coord2.longitude)
                if d < 50 { score += 1; break }
            }
        }
        return score
    }
    
    private func randomCoordinate(from origin: CLLocationCoordinate2D,
                                  withinMiles distanceMiles: Double) -> CLLocationCoordinate2D {
        let distanceMeters = distanceMiles * 1609.34
        let bearing = Double.random(in: 0..<360) * .pi / 180
        let earthRadius: Double = 6378137
        let angularDistance = distanceMeters / earthRadius
        let lat1 = origin.latitude * .pi / 180
        let lon1 = origin.longitude * .pi / 180
        let lat2 = asin(sin(lat1) * cos(angularDistance) +
                        cos(lat1) * sin(angularDistance) * cos(bearing))
        let lon2 = lon1 + atan2(sin(bearing) * sin(angularDistance) * cos(lat1),
                                cos(angularDistance) - sin(lat1) * sin(lat2))
        return CLLocationCoordinate2D(latitude: lat2 * 180 / .pi, longitude: lon2 * 180 / .pi)
    }
    
    private func randomCoordinateOnCurvyRoads(origin: CLLocationCoordinate2D,
                                               maxDistanceMiles: Double,
                                               roadSegments: [RoadSegment]) -> CLLocationCoordinate2D? {
        let maxDistanceMeters = maxDistanceMiles * 1609.34
        let nearbySegments = roadSegments.filter { seg in
            let dist = distanceBetween(origin.latitude, origin.longitude,
                                       seg.midpoint.latitude, seg.midpoint.longitude)
            return dist <= maxDistanceMeters
        }
        guard !nearbySegments.isEmpty,
              let chosenSegment = nearbySegments.randomElement(),
              let randomCoord = chosenSegment.randomCoordinate() else {
            print("No segments found within \(maxDistanceMiles) miles.")
            return nil
        }
        return randomCoord
    }
    
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
        guard let kmlURL = Bundle.main.url(forResource: kmlFileName,
                                           withExtension: "kml",
                                           subdirectory: subfolder) else {
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

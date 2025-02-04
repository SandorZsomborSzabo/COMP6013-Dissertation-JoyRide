//
//  JoyRide_DissertationProjectApp.swift
//  JoyRide_DissertationProject
//
//  Created by macbook on 29/12/2024.
//

import SwiftUI
import GoogleMaps
import GooglePlaces


@main
struct JoyRide_DissertationProjectApp: App {
    
    init() {
            GMSServices.provideAPIKey("AIzaSyCR4UzC0O1xZRP2Jf8A6LIShdThU4Znir0")
            GMSPlacesClient.provideAPIKey("AIzaSyCR4UzC0O1xZRP2Jf8A6LIShdThU4Znir0")
        }
    
    var body: some Scene {
        WindowGroup {
            LoginRegisterView()
        }
    }
}

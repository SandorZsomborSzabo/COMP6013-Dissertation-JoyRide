//
//  SettingsView.swift
//  JoyRide_DissertationProject
//
//  Created by macbook on 03/01/2025.
//

import SwiftUI
import SQLite3

struct SettingsView: View {
    @Binding var isAuthenticated: Bool // Tracks if the user is authenticated

    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.largeTitle)
                .padding()

            Button(action: logOut) {
                Text("Log Out")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(5)
            }

            Button(action: deleteAccount) {
                Text("Delete Account")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(5)
            }

            Spacer()
        }
        .padding()
    }

    // Log out action
    private func logOut() {
        isAuthenticated = false
        // Navigate back to the LoginRegisterView
        UIApplication.shared.windows.first?.rootViewController = UIHostingController(rootView: LoginRegisterView())
    }


    // Delete account action
    private func deleteAccount() {
        // Logic to delete the account from the database
        // This should ideally prompt the user for confirmation
        guard let db = LoginRegisterView.database else { return }
        let deleteQuery = "DELETE FROM Users WHERE username = ?;"
        var statement: OpaquePointer? = nil

        if sqlite3_prepare_v2(db, deleteQuery, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (LoginRegisterView().username as NSString).utf8String, -1, nil)
            if sqlite3_step(statement) == SQLITE_DONE {
                print("Account deleted successfully")
                isAuthenticated = false
            } else {
                print("Failed to delete account")
            }
        } else {
            print("Failed to prepare delete statement")
        }

        sqlite3_finalize(statement)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(isAuthenticated: .constant(true))
    }
}

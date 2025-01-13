//
//  SettingsView.swift
//  JoyRide_DissertationProject
//
//  Created by macbook on 03/01/2025.
//

import SwiftUI
import SQLite3

struct SettingsView: View {
    let username: String
    @Binding var isAuthenticated: Bool

    // State for showing the popup and tracking user input
    @State private var showDeleteConfirmation = false
    @State private var typedDelete = ""

    var body: some View {
        ZStack {
            // 1. Main settings content
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

                // Pressing this will show the confirmation popup
                Button(action: {
                    showDeleteConfirmation = true
                }) {
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

            // 2. The popup overlay when showDeleteConfirmation == true
            if showDeleteConfirmation {
                // A semi-transparent background to dim the underlying view
                Rectangle()
                    .fill(Color.black.opacity(0.4))
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        // If you want the user to tap outside to dismiss, uncomment:
                        // showDeleteConfirmation = false
                    }

                // 3. The actual popup box
                VStack(spacing: 20) {
                    Text("Type DELETE to confirm")
                        .font(.headline)
                    
                    TextField("DELETE", text: $typedDelete)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    
                    HStack {
                        Button("Cancel") {
                            // Reset input and hide popup
                            typedDelete = ""
                            showDeleteConfirmation = false
                        }
                        .foregroundColor(.blue)
                        
                        Button("Confirm") {
                            // Call delete logic if typedDelete == "DELETE"
                            if typedDelete == "DELETE" {
                                deleteAccount(for: username)
                            }
                            // Dismiss popup regardless
                            typedDelete = ""
                            showDeleteConfirmation = false
                        }
                        // Disable the confirm button unless typedDelete == "DELETE"
                        .disabled(typedDelete != "DELETE")
                        .foregroundColor(typedDelete == "DELETE" ? .red : .gray)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(radius: 6)
                .padding(.horizontal, 40)  
            }
        }
    }

    // Log out action
    private func logOut() {
        isAuthenticated = false
        UIApplication.shared.windows.first?.rootViewController =
            UIHostingController(rootView: LoginRegisterView())
    }

    private func deleteAccount(for username: String) {
        guard let db = LoginRegisterView.database else { return }
        let deleteQuery = "DELETE FROM Users WHERE username = ?;"
        var statement: OpaquePointer? = nil

        if sqlite3_prepare_v2(db, deleteQuery, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (username as NSString).utf8String, -1, nil)

            if sqlite3_step(statement) == SQLITE_DONE {
                print("Account deleted successfully")
                isAuthenticated = false
                UIApplication.shared.windows.first?.rootViewController =
                    UIHostingController(rootView: LoginRegisterView())
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
        SettingsView(
            username: "PreviewUser",
            isAuthenticated: .constant(true)
        )
    }
}

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
    
    // Define a green gradient for styling
    private var greenGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [Color.green.opacity(0.7), Color.green]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    var body: some View {
        ZStack {
            // Set the background to black for dark mode.
            Color.black.edgesIgnoringSafeArea(.all)
            
            // Main settings content.
            VStack(spacing: 20) {
                Text("Settings")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .padding()
                
                Button(action: logOut) {
                    Text("Log Out")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(greenGradient)
                        )
                        .foregroundColor(.white)
                }
                
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    Text("Delete Account")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(greenGradient)
                        )
                        .foregroundColor(.white)
                }
                
                Spacer()
            }
            .padding()
            
            // Popup overlay for account deletion confirmation.
            if showDeleteConfirmation {
                // Dim background overlay.
                Rectangle()
                    .fill(Color.black.opacity(0.4))
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        // Optionally allow tap-outside to dismiss.
                        // showDeleteConfirmation = false
                    }
                
                // Popup box.
                VStack(spacing: 20) {
                    Text("Type DELETE to confirm")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    TextField("DELETE", text: $typedDelete)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(greenGradient, lineWidth: 1)
                        )
                        .foregroundColor(.white)
                        .padding(.horizontal)
                    
                    HStack {
                        Button("Cancel") {
                            // Reset input and hide popup.
                            typedDelete = ""
                            showDeleteConfirmation = false
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(greenGradient)
                        )
                        .foregroundColor(.white)
                        
                        Button("Confirm") {
                            if typedDelete == "DELETE" {
                                deleteAccount(for: username)
                            }
                            // Dismiss popup regardless.
                            typedDelete = ""
                            showDeleteConfirmation = false
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(typedDelete == "DELETE" ? Color.green : Color.gray)
                        )
                        .foregroundColor(.white)
                        .disabled(typedDelete != "DELETE")
                    }
                    .padding(.horizontal)
                }
                .padding()
                .background(Color.black)
                .cornerRadius(12)
                .shadow(radius: 6)
                .padding(.horizontal, 40)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    func setUserOnlineStatus(username: String, isOnline: Bool) {
        guard let db = LoginRegisterView.database else { return }
        
        let updateQuery = "UPDATE Users SET isOnline = ? WHERE username = ?;"
        var statement: OpaquePointer? = nil
        
        if sqlite3_prepare_v2(db, updateQuery, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, isOnline ? 1 : 0)
            sqlite3_bind_text(statement, 2, (username as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("Updated isOnline = \(isOnline) for user \(username)")
            } else {
                print("Failed to update isOnline for user \(username)")
            }
        }
        sqlite3_finalize(statement)
    }
    
    // Log out action.
    private func logOut() {
        isAuthenticated = false
        UIApplication.shared.windows.first?.rootViewController =
            UIHostingController(rootView: LoginRegisterView())
        setUserOnlineStatus(username: username, isOnline: false)
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

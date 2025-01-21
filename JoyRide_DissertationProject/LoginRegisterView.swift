//
//  LoginRegisterView.swift
//  JoyRide_DissertationProject
//
//  Created by macbook on 02/01/2025.
//

import SwiftUI
import SQLite3

struct LoginRegisterView: View {
    @State private var isLoginMode = true // Tracks whether the user is in login or register mode
    @State private var email = ""
    @State var username = ""
    @State private var password = ""
    @State private var isAuthenticated = false // Tracks if the user is authenticated
    @State private var showAlert = false // Tracks if the alert is shown
    @State private var alertMessage = "" // Stores the alert message

    static var database: OpaquePointer? = {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("UsersDatabase.sqlite")

        print("Database path: \(fileURL.path)")

        var db: OpaquePointer? = nil
        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("Failed to open database")
        } else {
            // 1) Create Users table
            let createUsersTable = """
            CREATE TABLE IF NOT EXISTS Users (
                username TEXT PRIMARY KEY,
                email TEXT,
                password TEXT,
                isOnline INT DEFAULT 0
            );
            """
            if sqlite3_exec(db, createUsersTable, nil, nil, nil) != SQLITE_OK {
                print("Failed to create Users table")
            } else {
                print("Successfully created/verified Users table")
            }
            
            let addIsOnlineColumn = "ALTER TABLE Users ADD COLUMN isOnline INT DEFAULT 0;"
            if sqlite3_exec(db, addIsOnlineColumn, nil, nil, nil) == SQLITE_OK {
                print("Successfully added 'isOnline' column to Users table.")
            } else {
                print("Failed to add 'isOnline' column (maybe it already exists?)")
            }

            // 2) Create Friends table
            let createFriendsTable = """
            CREATE TABLE IF NOT EXISTS Friends (
                user1 TEXT NOT NULL,
                user2 TEXT NOT NULL,
                PRIMARY KEY(user1, user2),
                FOREIGN KEY(user1) REFERENCES Users(username),
                FOREIGN KEY(user2) REFERENCES Users(username)
            );
            """
            if sqlite3_exec(db, createFriendsTable, nil, nil, nil) != SQLITE_OK {
                print("Failed to create Friends table")
            } else {
                print("Successfully created/verified Friends table")
            }
        }
        return db
    }()


    var body: some View {
        if isAuthenticated {
            ContentView(username: username) // Navigate to main app after authentication
        } else {
            VStack {
                // Top buttons for switching modes
                HStack {
                    Button(action: { isLoginMode = true }) {
                        Text("Log In")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isLoginMode ? Color.gray : Color.clear)
                            .foregroundColor(.black)
                            .border(Color.black, width: 1)
                    }
                    Button(action: { isLoginMode = false }) {
                        Text("Register")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(!isLoginMode ? Color.gray : Color.clear)
                            .foregroundColor(.black)
                            .border(Color.black, width: 1)
                    }
                }
                .frame(height: 50)

                Spacer()

                if isLoginMode {
                    loginForm()
                } else {
                    registerForm()
                }

                Spacer()
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }

    private func loginForm() -> some View {
        VStack(spacing: 20) {
            Text("Log In").font(.largeTitle)
            TextField("Username", text: $username)
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(5)
                .border(Color.gray, width: 1)
            SecureField("Password", text: $password)
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(5)
                .border(Color.gray, width: 1)
            Button(action: authenticateUser) {
                Text("Log In")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(5)
            }
        }
        .padding()
    }

    private func registerForm() -> some View {
        VStack(spacing: 20) {
            Text("Register").font(.largeTitle)
            TextField("Email", text: $email)
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(5)
                .border(Color.gray, width: 1)
            TextField("Username", text: $username)
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(5)
                .border(Color.gray, width: 1)
            SecureField("Password", text: $password)
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(5)
                .border(Color.gray, width: 1)
            Button(action: validateAndRegisterUser) {
                Text("Register")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(5)
            }
        }
        .padding()
    }

    func validateAndRegisterUser() {
        if email.isEmpty || username.isEmpty || password.isEmpty {
            alertMessage = "All fields are required. Please fill in Email, Username, and Password."
            showAlert = true
        } else {
            registerUser()
        }
    }
    
    func setUserOnlineStatus(username: String, isOnline: Bool) {
        guard let db = Self.database else { return }

        let updateQuery = "UPDATE Users SET isOnline = ? WHERE username = ?;"
        var statement: OpaquePointer? = nil

        if sqlite3_prepare_v2(db, updateQuery, -1, &statement, nil) == SQLITE_OK {
            // Convert Bool to Int: 1 or 0
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


    func authenticateUser() {
        guard let db = Self.database else { return }
        let query = "SELECT * FROM Users WHERE username = ? AND password = ?;"
        var statement: OpaquePointer? = nil

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (username as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (password as NSString).utf8String, -1, nil)

            if sqlite3_step(statement) == SQLITE_ROW {
                print("User authenticated successfully")
                isAuthenticated = true
                
                setUserOnlineStatus(username: username, isOnline: true)
            } else {
                alertMessage = "Invalid username or password. Please try again."
                showAlert = true
                print("Invalid login credentials")
            }
        } else {
            alertMessage = "Failed to execute login query. Please try again."
            showAlert = true
            print("Failed to prepare query")
        }
        sqlite3_finalize(statement)
    }

    func registerUser() {
        guard let db = Self.database else { return }
        let query = "INSERT INTO Users (email, username, password) VALUES (?, ?, ?);"
        var statement: OpaquePointer? = nil

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (email as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (username as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, (password as NSString).utf8String, -1, nil)

            if sqlite3_step(statement) == SQLITE_DONE {
                print("User registered successfully: \(username)")
                isAuthenticated = true
            } else {
                alertMessage = "Failed to register user. Please try again."
                showAlert = true
                print("Failed to insert user")
            }
        } else {
            alertMessage = "Failed to prepare registration query. Please try again."
            showAlert = true
            print("Failed to prepare insert statement")
        }
        sqlite3_finalize(statement)
    }
}

struct LoginRegisterView_Previews: PreviewProvider {
    static var previews: some View {
        LoginRegisterView()
    }
}


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
    @State private var username = ""
    @State private var password = ""
    @State private var isAuthenticated = false // Tracks if the user is authenticated

    private static var database: OpaquePointer? = {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("UsersDatabase.sqlite")

        print("Database path: \(fileURL.path)")

        var db: OpaquePointer? = nil
        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("Failed to open database")
        } else {
            let createTableQuery = """
            CREATE TABLE IF NOT EXISTS Users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                email TEXT,
                username TEXT,
                password TEXT
            );
            """
            if sqlite3_exec(db, createTableQuery, nil, nil, nil) != SQLITE_OK {
                print("Failed to create table")
            } else {
                print("Successfully created table or table already exists")
            }
        }
        return db
    }()

    var body: some View {
        if isAuthenticated {
            ContentView() // Navigate to main app after authentication
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
            Button(action: registerUser) {
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
            } else {
                print("Invalid login credentials")
            }
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
                print("Failed to register user")
            }
        }
        sqlite3_finalize(statement)
    }
}

struct LoginRegisterView_Previews: PreviewProvider {
    static var previews: some View {
        LoginRegisterView()
    }
}


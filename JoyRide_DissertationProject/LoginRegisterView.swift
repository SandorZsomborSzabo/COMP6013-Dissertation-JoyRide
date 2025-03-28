//
//  LoginRegisterView.swift
//  JoyRide_DissertationProject
//
//  Created by macbook on 02/01/2025.
//

import SwiftUI
import SQLite3

// MARK: - Custom Modifiers and Button Style

struct DarkFieldStyle: ViewModifier {
    var cornerRadius: CGFloat = 8
    var borderColor: Color = .green
    func body(content: Content) -> some View {
        content
            .padding(10)
            .background(Color.black)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: 1)
            )
            .foregroundColor(.white)
    }
}

extension View {
    func darkFieldStyle(cornerRadius: CGFloat = 8, borderColor: Color = .green) -> some View {
        self.modifier(DarkFieldStyle(cornerRadius: cornerRadius, borderColor: borderColor))
    }
}

struct DarkButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 8
    var fillColor: Color = .green
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(fillColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(fillColor, lineWidth: 1)
            )
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct ModeSwitchButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isSelected ? Color.green : Color.black)
                .foregroundColor(isSelected ? .white : .green)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.green, lineWidth: 1)
                )
                .cornerRadius(8)
        }
    }
}

// MARK: - LoginRegisterView

struct LoginRegisterView: View {
    @State private var isLoginMode = true
    @State private var email = ""
    @State var username = ""
    @State private var password = ""
    @State private var isAuthenticated = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showDataProtectionModal = true
    
    // Define our green gradient (if you wish to use gradients later)
    private var greenGradient: LinearGradient {
        LinearGradient(gradient: Gradient(colors: [Color.green.opacity(0.7), Color.green]),
                       startPoint: .leading, endPoint: .trailing)
    }
    
    // MARK: - Database Setup
    static var database: OpaquePointer? = {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("UsersDatabase.sqlite")
        
        print("Database path: \(fileURL.path)")
        
        var db: OpaquePointer? = nil
        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("Failed to open database")
        } else {
            // Create Users table
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
            
            // Create Friends table
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
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            if isAuthenticated {
                ContentView(username: username)
            } else {
                VStack {
                    // Mode switch buttons at the top
                    HStack {
                        ModeSwitchButton(title: "Log In", isSelected: isLoginMode) {
                            isLoginMode = true
                        }
                        ModeSwitchButton(title: "Register", isSelected: !isLoginMode) {
                            isLoginMode = false
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    if isLoginMode {
                        loginForm
                    } else {
                        registerForm
                    }
                    
                    Spacer()
                }
                .padding()
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .fullScreenCover(isPresented: $showDataProtectionModal) {
            DataProtectionModalView(showModal: $showDataProtectionModal)
        }
    }
    
    // MARK: - Forms
    
    var loginForm: some View {
        VStack(spacing: 20) {
            Text("Log In")
                .font(.largeTitle)
                .foregroundColor(.white)
            TextField("Username", text: $username)
                .darkFieldStyle()
            SecureField("Password", text: $password)
                .darkFieldStyle()
            Button(action: authenticateUser) {
                Text("Log In")
            }
            .buttonStyle(DarkButtonStyle())
        }
        .padding()
    }
    
    var registerForm: some View {
        VStack(spacing: 20) {
            Text("Register")
                .font(.largeTitle)
                .foregroundColor(.white)
            TextField("Email", text: $email)
                .darkFieldStyle()
            TextField("Username", text: $username)
                .darkFieldStyle()
            SecureField("Password", text: $password)
                .darkFieldStyle()
            Button(action: validateAndRegisterUser) {
                Text("Register")
            }
            .buttonStyle(DarkButtonStyle())
        }
        .padding()
    }
    
    // MARK: - Actions
    
    func validateAndRegisterUser() {
        if email.isEmpty || username.isEmpty || password.isEmpty {
            alertMessage = "All fields are required. Please fill in Email, Username, and Password."
            showAlert = true
        } else {
            registerUser()
        }
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
    
    func setUserOnlineStatus(username: String, isOnline: Bool) {
        guard let db = Self.database else { return }
        
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
}

// MARK: - Data Protection Modal

struct DataProtectionModalView: View {
    @Binding var showModal: Bool
    @State private var hasAgreed: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Data Protection Policy")
                .font(.largeTitle)
                .foregroundColor(.white)
                .padding()
            ScrollView {
                Text("""
                Your data will be processed, stored, and used in accordance with our privacy policy. We ensure that your personal information is protected and used solely for providing and improving our services. Your email, username, and password will be securely stored in our database. We may also use anonymized data for analytical purposes.
                """)
                    .foregroundColor(.white)
                    .padding()
            }
            .darkFieldStyle()
            
            Toggle("I have read and accept the Data Protection Policy", isOn: $hasAgreed)
                .padding()
                .darkFieldStyle()
            
            HStack(spacing: 40) {
                Button("Decline") {
                    alertMessage = "You must accept the Data Protection Policy in order to use the application."
                    showAlert = true
                }
                .buttonStyle(DarkButtonStyle(fillColor: .red))
                
                Button("Accept") {
                    if hasAgreed {
                        showModal = false
                    } else {
                        alertMessage = "Please tick the box to confirm you have read the Data Protection Policy."
                        showAlert = true
                    }
                }
                .buttonStyle(DarkButtonStyle())
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color.black)
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Notice"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
}

// MARK: - Preview

struct LoginRegisterView_Previews: PreviewProvider {
    static var previews: some View {
        LoginRegisterView()
    }
}

//
//  SocialView.swift
//  JoyRide_DissertationProject
//
//  Created by macbook on 13/01/2025.
//
import SwiftUI
import SQLite3

struct SocialView: View {
    // The currently logged-in user
    let currentUsername: String
    
    // The selected top tab: friends, groups, or discover
    @State private var selectedTab: SocialTab = .friends
    
    // The list of friend usernames for the current user
    @State private var friendList: [String] = []
    
    // Text field for searching a username to add
    @State private var searchUsername: String = ""
    
    // For alerts
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            // A horizontal bar with 3 "tabs": Friends, Groups, Discover
            HStack(spacing: 0) {
                TabButton(title: "Friends", isActive: selectedTab == .friends) {
                    selectedTab = .friends
                }
                Divider()
                TabButton(title: "Groups", isActive: selectedTab == .groups) {
                    selectedTab = .groups
                }
                Divider()
                TabButton(title: "Discover", isActive: selectedTab == .discover) {
                    selectedTab = .discover
                }
            }
            .frame(height: 50)
            .border(Color.black, width: 1)
            
            // Show different views based on which tab is selected
            switch selectedTab {
            case .friends:
                friendsSection
            case .groups:
                groupsSection
            case .discover:
                discoverSection
            }
        }
        .edgesIgnoringSafeArea(.bottom)
        .onAppear {
            // Whenever this view appears, load the friend list from DB
            fetchFriends()
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Notice"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // MARK: - Friends Section
    
    private var friendsSection: some View {
        VStack(spacing: 0) {
            // Display how many friends the user has
            Text("Active friends: \(friendList.count)")
                .font(.headline)
                .padding()
                .border(Color.black, width: 1)
            
            // A row with a text field and "Add Friend" button
            HStack {
                TextField("Search username to add", text: $searchUsername)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Button("Add Friend") {
                    addFriend(searchUsername)
                }
                .padding(.trailing)
            }
            
            // Show the user's friend list in a scrollable list
            List(friendList, id: \.self) { friend in
                HStack {
                    Text(friend) // The friend's username
                    Spacer()
                    Button("Chat") {
                        // Chat action
                        print("Chat with \(friend)")
                    }
                }
            }
            
            Spacer()
            
            // A "Discover" button that switches to the Discover tab
            Button("Discover") {
                selectedTab = .discover
            }
            .padding()
            .border(Color.black, width: 1)
        }
    }
    
    // MARK: - Groups Section
    
    private var groupsSection: some View {
        VStack {
            Spacer()
            Text("Groups Page")
                .font(.largeTitle)
                .foregroundColor(.gray)
            Spacer()
        }
        .border(Color.black, width: 1)
    }
    
    // MARK: - Discover Section
    
    private var discoverSection: some View {
        VStack {
            Spacer()
            Text("Discover Page")
                .font(.largeTitle)
                .foregroundColor(.gray)
            Spacer()
        }
        .border(Color.black, width: 1)
    }
    
    // MARK: - Database Helpers
    
    /// Fetch all friends of `currentUsername` from the Friends table
    private func fetchFriends() {
        guard let db = LoginRegisterView.database else { return }
        
        // We want any row where the current user is user1 or user2
        // We'll return the *other* username as "friendName"
        let query = """
        SELECT CASE 
            WHEN user1 = ? THEN user2 
            ELSE user1 
        END AS friendName
        FROM Friends
        WHERE user1 = ? OR user2 = ?;
        """
        
        var statement: OpaquePointer? = nil
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (currentUsername as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (currentUsername as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, (currentUsername as NSString).utf8String, -1, nil)
            
            var fetched: [String] = []
            
            while sqlite3_step(statement) == SQLITE_ROW {
                if let friendNameCStr = sqlite3_column_text(statement, 0) {
                    let friendName = String(cString: friendNameCStr)
                    fetched.append(friendName)
                }
            }
            friendList = fetched
        } else {
            print("Failed to prepare fetchFriends statement")
        }
        
        sqlite3_finalize(statement)
    }
    
    /// Add a friend, but only if that user exists in `Users`
    private func addFriend(_ newFriend: String) {
        guard let db = LoginRegisterView.database else { return }
        
        // Prevent adding yourself
        if newFriend.lowercased() == currentUsername.lowercased() {
            alertMessage = "You cannot add yourself as a friend."
            showAlert = true
            return
        }
        
        // 1) Check if user exists in the Users table
        guard userExists(newFriend) else {
            alertMessage = "No user found with that username."
            showAlert = true
            return
        }
        
        // 2) Insert a row into Friends table (user1 = currentUsername, user2 = newFriend)
        let insertQuery = "INSERT OR IGNORE INTO Friends (user1, user2) VALUES (?, ?);"
        var statement: OpaquePointer? = nil
        
        if sqlite3_prepare_v2(db, insertQuery, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (currentUsername as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (newFriend as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("Friend added: \(newFriend)")
                // Refresh the friend list
                fetchFriends()
            } else {
                alertMessage = "Could not add friend for unknown reason."
                showAlert = true
                print("Failed to insert friend relationship.")
            }
        } else {
            print("Failed to prepare addFriend statement.")
        }
        
        sqlite3_finalize(statement)
    }
    
    /// Check if a user by this username exists in the Users table
    private func userExists(_ userToCheck: String) -> Bool {
        guard let db = LoginRegisterView.database else { return false }
        
        let query = "SELECT 1 FROM Users WHERE username = ? LIMIT 1;"
        var statement: OpaquePointer? = nil
        defer { sqlite3_finalize(statement) }
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (userToCheck as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                // Found at least one row => user exists
                return true
            }
        } else {
            print("Failed to prepare userExists statement.")
        }
        return false
    }
}

// MARK: - Supporting Types

/// Which top tab is selected
enum SocialTab {
    case friends
    case groups
    case discover
}

/// Basic tab button (reusing the one from ContentView is fine)
struct SocialTabButton: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Rectangle()
                    .fill(isActive ? Color.gray : Color.clear)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.black)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

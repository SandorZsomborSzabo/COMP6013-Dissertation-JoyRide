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
    
    // Instead of just storing friend usernames as [String],
    // we store FriendInfo objects with username + isOnline.
    @State private var friendList: [FriendInfo] = []
    
    // Text field for searching a username to add
    @State private var searchUsername: String = ""
    
    // For alerts
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // Green gradient used throughout the view
    private var greenGradient: LinearGradient {
        LinearGradient(gradient: Gradient(colors: [Color.green.opacity(0.7), Color.green]),
                       startPoint: .leading, endPoint: .trailing)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top horizontal tab bar with dark background and green-styled buttons
            HStack(spacing: 0) {
                SocialTabButton(title: "Friends", isActive: selectedTab == .friends) {
                    selectedTab = .friends
                }
                Divider().background(Color.green)
                SocialTabButton(title: "Groups", isActive: selectedTab == .groups) {
                    selectedTab = .groups
                }
                Divider().background(Color.green)
                SocialTabButton(title: "Discover", isActive: selectedTab == .discover) {
                    selectedTab = .discover
                }
            }
            .frame(height: 50)
            .background(Color.black)
            .overlay(RoundedRectangle(cornerRadius: 0)
                        .stroke(Color.green, lineWidth: 1))
            
            // Main content based on selected tab
            Group {
                switch selectedTab {
                case .friends:
                    friendsSection
                case .groups:
                    groupsSection
                case .discover:
                    discoverSection
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        }
        .background(Color.black)
        .edgesIgnoringSafeArea(.bottom)
        .onAppear {
            // Load the friend list and perform an online backup of the DB whenever this view appears.
            fetchFriends()
            performDatabaseBackup()
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
        VStack(spacing: 16) {
            // Active friends counter styled with rounded green border
            let activeFriendCount = friendList.filter { $0.isOnline }.count
            Text("Active friends: \(activeFriendCount)")
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.green, lineWidth: 1)
                )
                .padding(.horizontal)
            
            // A row with a search text field and "Add Friend" button
            HStack {
                TextField("Search username to add", text: $searchUsername)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.green, lineWidth: 1)
                    )
                    .foregroundColor(.white)
                    .padding(.leading)
                
                Button(action: {
                    addFriend(searchUsername)
                }) {
                    Text("Add Friend")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: 120)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(greenGradient)
                        )
                }
                .padding(.trailing)
            }
            
            // Friend list displayed in a List
            List(friendList, id: \.username) { friend in
                HStack {
                    Text(friend.username)
                        .foregroundColor(.white)
                    Text(friend.isOnline ? "(Online)" : "(Offline)")
                        .foregroundColor(friend.isOnline ? .green : .red)
                    
                    Spacer()
                    
                    Button("Chat") {
                        // Chat action here
                        print("Chat with \(friend.username)")
                    }
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(greenGradient)
                    )
                    .foregroundColor(.white)
                }
                .listRowBackground(Color.black)
            }
            .listStyle(PlainListStyle())
            
            Spacer()
            
            // "Discover" button to switch tabs, styled with green gradient and rounded corners
            Button(action: {
                selectedTab = .discover
            }) {
                Text("Discover")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(greenGradient)
                    )
                    .padding(.horizontal)
            }
        }
        .padding(.vertical)
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
        .background(Color.black)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.green, lineWidth: 1)
        )
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
        .background(Color.black)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.green, lineWidth: 1)
        )
    }
    
    // MARK: - Database Helpers
    
    private func fetchFriends() {
        guard let db = LoginRegisterView.database else { return }
        
        let query = """
        SELECT 
           CASE WHEN f.user1 = ? THEN f.user2 ELSE f.user1 END AS friendName,
           u.isOnline
        FROM Friends f
        JOIN Users u
          ON u.username = CASE WHEN f.user1 = ? THEN f.user2 ELSE f.user1 END
        WHERE (f.user1 = ? OR f.user2 = ?);
        """
        
        var statement: OpaquePointer? = nil
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (currentUsername as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (currentUsername as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, (currentUsername as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 4, (currentUsername as NSString).utf8String, -1, nil)
            
            var fetchedFriends: [FriendInfo] = []
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let friendNameCStr = sqlite3_column_text(statement, 0)
                let isOnlineInt = sqlite3_column_int(statement, 1)
                
                if let friendNameCStr = friendNameCStr {
                    let friendName = String(cString: friendNameCStr)
                    let isOnline = (isOnlineInt == 1)
                    
                    fetchedFriends.append(
                        FriendInfo(username: friendName, isOnline: isOnline)
                    )
                }
            }
            
            friendList = fetchedFriends
        } else {
            print("Failed to prepare fetchFriends statement")
        }
        
        sqlite3_finalize(statement)
    }
    
    private func addFriend(_ newFriend: String) {
        guard let db = LoginRegisterView.database else { return }
        
        if newFriend.lowercased() == currentUsername.lowercased() {
            alertMessage = "You cannot add yourself as a friend."
            showAlert = true
            return
        }
        
        guard userExists(newFriend) else {
            alertMessage = "No user found with that username."
            showAlert = true
            return
        }
        
        let insertQuery = "INSERT OR IGNORE INTO Friends (user1, user2) VALUES (?, ?);"
        var statement: OpaquePointer? = nil
        
        if sqlite3_prepare_v2(db, insertQuery, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (currentUsername as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (newFriend as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("Friend added: \(newFriend)")
                fetchFriends()
                performDatabaseBackup()
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
    
    private func userExists(_ userToCheck: String) -> Bool {
        guard let db = LoginRegisterView.database else { return false }
        
        let query = "SELECT 1 FROM Users WHERE username = ? LIMIT 1;"
        var statement: OpaquePointer? = nil
        defer { sqlite3_finalize(statement) }
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (userToCheck as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                return true
            }
        } else {
            print("Failed to prepare userExists statement.")
        }
        return false
    }
    
    private func performDatabaseBackup() {
        guard let sourceDB = LoginRegisterView.database else {
            print("Source database not available")
            return
        }
        
        let backupFileName = "backup.db"
        let fileManager = FileManager.default
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Documents directory not found")
            return
        }
        let backupURL = documentsDir.appendingPathComponent(backupFileName)
        
        var backupDB: OpaquePointer? = nil
        if sqlite3_open(backupURL.path, &backupDB) == SQLITE_OK {
            if let backup = sqlite3_backup_init(backupDB, "main", sourceDB, "main") {
                let result = sqlite3_backup_step(backup, -1)
                if result == SQLITE_DONE {
                    print("Backup completed successfully to \(backupURL.path).")
                } else {
                    print("Backup step returned result \(result).")
                }
                sqlite3_backup_finish(backup)
            } else {
                print("Failed to initialize backup.")
            }
            sqlite3_close(backupDB)
        } else {
            print("Failed to open backup database at \(backupURL.path).")
        }
    }
}

// MARK: - Additional Types

enum SocialTab {
    case friends
    case groups
    case discover
}

struct FriendInfo {
    let username: String
    let isOnline: Bool
}

/// Custom tab button for the social view header using type-erased fill style.
struct SocialTabButton: View {
    let title: String
    let isActive: Bool
    let action: () -> Void
    
    private var greenGradient: LinearGradient {
        LinearGradient(gradient: Gradient(colors: [Color.green.opacity(0.7), Color.green]),
                       startPoint: .leading, endPoint: .trailing)
    }
    
    private var fillStyle: AnyShapeStyle {
        if isActive {
            return AnyShapeStyle(greenGradient)
        } else {
            return AnyShapeStyle(Color.clear)
        }
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Rectangle()
                    .fill(fillStyle)
                    .cornerRadius(8)
                Text(title)
                    .font(.headline)
                    .foregroundColor(isActive ? .white : .green)
                    .padding(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

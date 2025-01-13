//
//  SocialView.swift
//  JoyRide_DissertationProject
//
//  Created by macbook on 13/01/2025.
//
import SwiftUI

struct SocialView: View {
    // 1) Track which of the 3 tabs is selected
    @State private var selectedTab: SocialTab = .friends
    
    var body: some View {
        VStack(spacing: 0) {
            // 2) The top tab bar
            HStack(spacing: 0) {
                TabButton(title: "Friends", isActive: selectedTab == .friends) {
                    selectedTab = .friends
                }
                TabButton(title: "Groups", isActive: selectedTab == .groups) {
                    selectedTab = .groups
                }
                TabButton(title: "Discover", isActive: selectedTab == .discover) {
                    selectedTab = .discover
                }
            }
            .frame(height: 50)
            .border(Color.black, width: 1)
            
            // 3) Show different content based on selectedTab
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
    }
    
    // MARK: Friends Section
    private var friendsSection: some View {
        // Example "Active friends: 1" area
        VStack(spacing: 0) {
            Text("Active friends: 1")
                .font(.headline)
                .padding()
                .border(Color.black, width: 1)
            
            // Example friend row
            HStack(alignment: .top, spacing: 16) {
                Circle()
                    .foregroundColor(.green)
                    .frame(width: 60, height: 60)
                    .overlay(Text("Picture").font(.footnote))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Friend 1")
                        .font(.headline)
                    Text("Vehicle: ...")
                        .font(.subheadline)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Last active: Now")
                        .font(.subheadline)
                    Button("Chat") {
                        // Chat action
                        print("Chat with Friend 1")
                    }
                    .padding(6)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
                }
            }
            .padding()
            .border(Color.black, width: 1)
            
            Spacer()
            
            // Example "Discover" button
            Button("Discover") {
                // should take user to discover page
                selectedTab = .discover
            }
            .padding()
            .border(Color.black, width: 1)
        }
    }
    
    // MARK: Groups Section
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
    
    // MARK: Discover Section
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
}

// 4) Small local enum to track which tab is active
enum SocialTab {
    case friends
    case groups
    case discover
}

// 5) A basic tab button style
struct SocialTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .background(isSelected ? Color.gray : Color.clear)
                .foregroundColor(.black)
                .border(Color.black, width: 1)
        }
    }
}

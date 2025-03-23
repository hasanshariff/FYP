//
//  ProfileView.swift
//  fypApp
//
//  Created by Hasan Shariff on 24/01/2025.
//

import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @StateObject private var themeManager = AppThemeManager()
    @StateObject private var fontManager = FontSizeManager()
    @State private var showLogoutAlert = false
    @State private var showFontModal = false
    @State private var email = ""
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("Signed in as")
                        .dynamicFontSize(fontManager)
                        .padding(.vertical, 4)
                    Text(email)
                        .foregroundColor(.gray)
                        .dynamicFontSize(fontManager)
                        .padding(.vertical, 4)
                }
                .padding(.vertical, 4)
                
                Section {
                    Toggle(isOn: $themeManager.isDark) {
                        HStack(spacing: 8) {
                            Image(systemName: "moon.fill")
                                .foregroundColor(themeManager.isDark ? .white : .purple)
                            Text("Dark Mode")
                                .dynamicFontSize(fontManager)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .padding(.vertical, 4)
                
                Section {
                    Button(action: { showFontModal = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "textformat.size")
                                .foregroundColor(themeManager.isDark ? .white : .purple)
                            Text("Adjust Font Size")
                                .dynamicFontSize(fontManager)
                                .foregroundColor(themeManager.isDark ? .white : .black)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.vertical, 4)
                
                Section {
                    NavigationLink(destination: LinksView()){
                        HStack(spacing: 8){
                            Image(systemName: "link")
                                .foregroundColor(themeManager.isDark ? .white : .purple)
                            Text("Help and useful links")
                                .dynamicFontSize(fontManager)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.vertical, 4)
                
                Section {
                    NavigationLink(destination: AboutView()){
                        HStack(spacing: 8){
                            Image(systemName: "info.circle")
                                .foregroundColor(themeManager.isDark ? .white : .purple)
                            Text("About")
                                .dynamicFontSize(fontManager)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.vertical, 4)
                
                Section {
                    NavigationLink(destination: LoginView()){
                        HStack(spacing: 8){
                            Image(systemName: "person.fill")
                                .foregroundColor(themeManager.isDark ? .white : .purple)
                            Text("Create account/ log in")
                                .dynamicFontSize(fontManager)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.vertical, 4)
                
                Section {
                    Button(action: { showLogoutAlert = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.red)
                            Text("Logout")
                                .foregroundColor(.red)
                                .dynamicFontSize(fontManager)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.vertical, 4)
                
                Section {
                    Text("Version 0.1.36")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .foregroundColor(.gray)
                        .dynamicFontSize(fontManager)
                        .padding(.vertical, 4)
                }
                .padding(.vertical, 4)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(colorScheme == .dark ? .white : .purple)
                            .font(.system(size: 24))
                        Text("Profile and Settings")
                            .foregroundColor(colorScheme == .dark ? .white : .purple)
                            .font(.system(size: 24, weight: .bold))
                    }
                }
            }
            .applyTheme(themeManager)
            .sheet(isPresented: $showFontModal) {
                FontSizeModal(fontSizeManager: fontManager, isPresented: $showFontModal)
                    .interactiveDismissDisabled(false)
            }
            .alert("Are you sure?", isPresented: $showLogoutAlert) {
                Button("No", role: .cancel) { }
                Button("Yes", role: .destructive) { handleLogout() }
            }
            .onAppear {
                email = Auth.auth().currentUser?.email ?? ""
            }
            .environmentObject(themeManager)
        }
    }
        
            private func handleLogout() {
                    do {
                        try Auth.auth().signOut()
                        withAnimation {
                            // Reset user preferences
                            themeManager.isDark = false
                            fontManager.resetFontSize()
                            
                            // Clear user data
                            email = ""
                            UserDefaults.standard.synchronize()
                        }
                        
                        // Navigate back to login view
                        dismiss()
                    } catch {
                        print("Error signing out: \(error.localizedDescription)")
                    }
                }
    
    struct FontSizeModal: View {
        @ObservedObject var fontSizeManager: FontSizeManager
        @Binding var isPresented: Bool
        
        var body: some View {
            VStack(spacing: 20) {
                Text("Adjust Font Size")
                    .font(.headline)
                
                HStack(spacing: 30) {
                    Button(action: fontSizeManager.decreaseFontSize) {
                        Image(systemName: "minus.circle")
                            .font(.title)
                            .foregroundColor(.purple)
                    }
                    
                    Text("\(Int(fontSizeManager.fontSize))")
                        .font(.title2)
                    
                    Button(action: fontSizeManager.increaseFontSize) {
                        Image(systemName: "plus.circle")
                            .font(.title)
                            .foregroundColor(.purple)
                    }
                }
                .padding()
                
                VStack(spacing: 12) {
                    Button("Done") {
                        withAnimation{
                            isPresented = false
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    Button("Reset") {
                        withAnimation{
                            fontSizeManager.resetFontSize()
                            isPresented = false
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.horizontal)
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16)
            .frame(width: 280)
            .shadow(radius: 10)
        }
    }
}

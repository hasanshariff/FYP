//
//  fypAppApp.swift
//  fypApp
//
//  Created by Hasan Shariff on 24/01/2025.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseAppCheck
import FirebaseFirestore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // 1. Configure Firebase first
        FirebaseApp.configure()
        
        // 3. Configure Firestore settings
        let db = Firestore.firestore()
        let settings = db.settings
        settings.cacheSettings = MemoryCacheSettings()
        db.settings = settings
        
        return true
    }
}

class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    private var authStateHandler: AuthStateDidChangeListenerHandle?
    
    init() {
        // Start as not authenticated
        isAuthenticated = false
        
        // Sign out user when app initializes
        try? Auth.auth().signOut()
        
        // Listen for auth state changes
        authStateHandler = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.isAuthenticated = user != nil
            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            isAuthenticated = false
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
    
    deinit {
        if let handler = authStateHandler {
            Auth.auth().removeStateDidChangeListener(handler)
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
            
            AddView()
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                    Text("Add")
                }
            
            WardrobeView()
                .tabItem {
                    Image(systemName: "hanger")
                    Text("Wardrobe")
                }
            
            CreateView()
                .tabItem {
                    Image(systemName: "square.and.pencil")
                    Text("Create")
                }
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
        }
        .accentColor(.purple)
    }
}

@main
struct fypAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authViewModel = AuthViewModel()
    @Environment(\.scenePhase) var scenePhase
    @StateObject private var fontSizeManager = FontSizeManager()
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                if authViewModel.isAuthenticated {
                    MainTabView()
                        .navigationBarHidden(true)
                } else {
                    LoginView()
                        .navigationBarBackButtonHidden(true)
                }
            }
            .environmentObject(fontSizeManager)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                Task { @MainActor in
                    authViewModel.signOut()
                }
            }
        }
    }
}

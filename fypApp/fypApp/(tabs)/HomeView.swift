//
//  HomeView.swift
//  fypApp
//
//  Created by Hasan Shariff on 24/01/2025.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - Models
struct Photo: Identifiable, Equatable {
    let id: String
    let url: String
    let type: String
    let timestamp: Date
    let brand: String
    let size: String
    
    static func == (lhs: Photo, rhs: Photo) -> Bool {
        lhs.id == rhs.id && lhs.timestamp == rhs.timestamp
    }
}

// MARK: - Image Cache
actor ImageCache {
    static let shared = ImageCache()
    private let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 100 // Limit number of cached images
        cache.totalCostLimit = 1024 * 1024 * 100 // 100 MB limit
        return cache
    }()
    
    func insert(_ image: UIImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
    
    func get(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }
    
    func clear() {
        cache.removeAllObjects()
    }
}

// MARK: - Network Service
actor NetworkService {
    static let shared = NetworkService()
    
    func fetchImage(from url: URL) async throws -> UIImage {
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }
        
        guard let image = UIImage(data: data) else {
            throw NetworkError.invalidImageData
        }
        
        return image
    }
    
    enum NetworkError: Error {
        case invalidResponse
        case invalidImageData
    }
}

// MARK: - Image Loading View
struct CachedAsyncImage: View {
    let url: URL?
    @State private var loadingState: ImageLoadingState = .loading
    
    enum ImageLoadingState {
        case loading
        case loaded(UIImage)
        case failed(Error)
        case empty
    }
    
    var body: some View {
        Group {
            switch loadingState {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded(let image):
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
            case .failed:
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                    Text("Failed to load image")
                        .font(.caption)
                    Button("Retry") {
                        Task { await loadImage() }
                    }
                }
            case .empty:
                Color.gray.opacity(0.3)
            }
        }
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard let url = url else {
            loadingState = .empty
            return
        }
        
        do {
            if let cached = await ImageCache.shared.get(for: url.absoluteString) {
                print("✅ Found cached image for URL: \(url.absoluteString)")
                withAnimation {
                    loadingState = .loaded(cached)
                }
                return
            }
            
            let image = try await NetworkService.shared.fetchImage(from: url)
            await ImageCache.shared.insert(image, for: url.absoluteString)
            
            withAnimation {
                loadingState = .loaded(image)
            }
        } catch {
            loadingState = .failed(error)
        }
    }
}

// MARK: - View Model
@MainActor
class HomeViewModel: ObservableObject {
    @Published private(set) var latestPhotos: [String: Photo?] = [
        "Tops": nil,
        "Bottoms": nil,
        "Shoes": nil
    ]
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var authListener: AuthStateDidChangeListenerHandle?
    
    init() {
        setupAuthListener()
    }
    
    private func setupAuthListener() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            
            if let user = user {
                self.setupFirestoreListener(for: user.uid)
                Task { await self.fetchLatestPhotos() }
            } else {
                self.cleanupListeners()
                self.clearPhotos()
            }
        }
    }
    
    private func setupFirestoreListener(for userUID: String) {
        cleanupListeners()
        
        let userRef = db.collection("users").document(userUID)
        listener = userRef.addSnapshotListener { [weak self] snapshot, error in
            if let error = error {
                self?.error = error
                return
            }
            
            guard snapshot?.exists == true else {
                self?.clearPhotos()
                return
            }
            
            Task { await self?.fetchLatestPhotos() }
        }
    }
    
    func fetchLatestPhotos() async {
        guard let userUID = Auth.auth().currentUser?.uid else {
            clearPhotos()
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            let document = try await db.collection("users").document(userUID).getDocument()
            
            guard document.exists,
                  let data = document.data(),
                  let photoArray = data["photoArray"] as? [[String: Any]] else {
                clearPhotos()
                return
            }
            
            var newLatestPhotos = latestPhotos
            
            for photoData in photoArray {
                guard let photo = try? self.parsePhotoData(photoData) else { continue }
                
                if let existingPhoto = newLatestPhotos[photo.type] as? Photo {
                    if photo.timestamp > existingPhoto.timestamp {
                        newLatestPhotos[photo.type] = photo
                    }
                } else {
                    newLatestPhotos[photo.type] = photo
                }
            }
            
            latestPhotos = newLatestPhotos
        } catch {
            self.error = error
            clearPhotos()
        }
        
        isLoading = false
    }
    
    private func parsePhotoData(_ photoData: [String: Any]) throws -> Photo {
        guard let type = photoData["type"] as? String,
              let url = photoData["url"] as? String,
              let brand = photoData["brand"] as? String,
              let size = photoData["size"] as? String else {
            throw ParseError.invalidData
        }
        
        let timestamp: Date
        if let firestoreTimestamp = photoData["timestamp"] as? Timestamp {
            timestamp = firestoreTimestamp.dateValue()
        } else if let timestampString = photoData["timestamp"] as? String,
                  let date = ISO8601DateFormatter().date(from: timestampString) {
            timestamp = date
        } else {
            throw ParseError.invalidTimestamp
        }
        
        return Photo(
            id: UUID().uuidString,
            url: url,
            type: type,
            timestamp: timestamp,
            brand: brand,
            size: size
        )
    }
    
    private func clearPhotos() {
        latestPhotos = ["Tops": nil, "Bottoms": nil, "Shoes": nil]
    }
    
    private func cleanupListeners() {
        listener?.remove()
        listener = nil
    }
    
    enum ParseError: Error {
        case invalidData
        case invalidTimestamp
    }
    
    deinit {
        if let authListener = authListener {
            Auth.auth().removeStateDidChangeListener(authListener)
        }
        listener?.remove()
        listener = nil
    }
}

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase
    @State private var currentTab = 0
    @State private var showFavorites = false
    
    private let types = ["Tops", "Bottoms", "Shoes"]
    private let titles = ["Your Latest Top", "Your Latest Bottom", "Your Latest Shoe"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                
                mainContent
                
                pageIndicator
            }
            .background(colorScheme == .dark ? Color(UIColor.systemBackground) : .white)
            .navigationBarHidden(true)
//            .navigationDestination(isPresented: $showWardrobe) {
//                WardrobeView()
//            }
            .navigationDestination(isPresented: $showFavorites) {
                FavouriteView()
            }
        }
        .onAppear {
            setupInitialState()
        }
    }
    
    private func setupInitialState() {
        // Initial data fetch
        Task {
            await viewModel.fetchLatestPhotos()
        }
    }
    
    // Header View
    private var header: some View {
        HStack {
            // App Title
            HStack(spacing: 8) {
                Image(systemName: "tshirt.fill")
                    .foregroundColor(colorScheme == .dark ? .white : .purple)
                    .font(.system(size: 24))
                
                Text("Wardrobe Buddy")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : .purple)
            }
            
            Spacer()
            
            // Navigation Buttons
            HStack(spacing: 16) {
                Button(action: {
                    showFavorites = true
                }) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.purple)
                        .font(.system(size: 20))
                        .padding(8)
                }
                
//                Button(action: {
//                    showWardrobe = true
//                }) {
//                    HStack(spacing: 4) {
//                        Image(systemName: "hanger")
//                        Text("View All")
//                    }
//                    .foregroundColor(.purple)
//                    .font(.system(size: 16, weight: .medium))
//                    .padding(.horizontal, 12)
//                    .padding(.vertical, 8)
//                    .background(Color.purple.opacity(0.1))
//                    .cornerRadius(8)
//                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // Main Content View
    private var mainContent: some View {
        ZStack {
            TabView(selection: $currentTab) {
                ForEach(0..<3) { index in
                    pageView(type: types[index], title: titles[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            navigationArrows
        }
    }
    
    // Navigation Arrows
    private var navigationArrows: some View {
        HStack {
            NavigationArrowButton(
                direction: .left,
                isEnabled: currentTab > 0,
                action: { withAnimation { currentTab = max(0, currentTab - 1) } }
            )
            
            Spacer()
            
            NavigationArrowButton(
                direction: .right,
                isEnabled: currentTab < 2,
                action: { withAnimation { currentTab = min(2, currentTab + 1) } }
            )
        }
        .padding(.horizontal, 8)
    }
    
    // Page Indicator
    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(currentTab == index ? Color.purple : Color.gray)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 20)
    }
    
    // Individual Page View
    private func pageView(type: String, title: String) -> some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .padding(.top, 16)
            
            Spacer(minLength: 0)
            
            if let photo = viewModel.latestPhotos[type] ?? nil {
                CachedAsyncImage(url: URL(string: photo.url))
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.6)
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 16)
            } else {
                NavigationLink(destination: AddView()) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.purple)
                }
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Helper Navigation Arrow Button
struct NavigationArrowButton: View {
    enum Direction {
        case left, right
        
        var systemName: String {
            switch self {
            case .left: return "chevron.left.circle.fill"
            case .right: return "chevron.right.circle.fill"
            }
        }
    }
    
    let direction: Direction
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: direction.systemName)
                .resizable()
                .frame(width: 40, height: 40)
                .foregroundColor(.purple)
                .opacity(isEnabled ? 0.8 : 0.2)
                .background(Color.white.opacity(0.001))
                .padding()
        }
        .disabled(!isEnabled)
    }
}

// MARK: - Supporting Views
struct ViewAllView: View {
    var body: some View {
        Text("View All Items")
            .navigationTitle("All Items")
    }
}

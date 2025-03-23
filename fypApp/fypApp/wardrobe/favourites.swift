//
//  favourites.swift
//  fypApp
//
//  Created by Hasan Shariff on 14/02/2025.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth


// MARK: - Data Models
struct SavedOutfit: Identifiable {
    let id: String
    let name: String
    let style: String
    let createdAt: Date
    var top: OutfitItem
    var bottom: OutfitItem
    var shoes: OutfitItem
    
}

struct OutfitItem {
    let brand: String
    let size: String
    let type: String
    let url: String
    let rgbValues: RGBValues
    var storedImage: UIImage?
}

struct RGBValues {
    let red: Double
    let green: Double
    let blue: Double
}

struct LoadingAlert: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text(message)
                .font(.system(size: 16, weight: .medium))
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .shadow(radius: 8)
        )
    }
}

// MARK: - View Model
class FavouritesViewModel: ObservableObject {
    @Published var savedOutfits: [SavedOutfit] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var isDeletingOutfit = false
    
    private let db = Firestore.firestore()
    
    func fetchOutfits() {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Please login to view saved outfits"
            return
        }
        
        isLoading = true
        
        db.collection("users").document(userId).collection("outfits")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { querySnapshot, error in
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                
                self.savedOutfits = querySnapshot?.documents.compactMap { document -> SavedOutfit? in
                    let data = document.data()
                    
                    // Use optional binding with default values to handle missing data
                    guard let name = data["name"] as? String,
                          let timestamp = data["createdAt"] as? Timestamp,
                          let topData = data["top"] as? [String: Any],
                          let bottomData = data["bottom"] as? [String: Any],
                          let shoesData = data["shoes"] as? [String: Any] else {
                              print("Failed to parse document: \(document.documentID)")
                              return nil
                    }
                    
                    let createdAt = timestamp.dateValue()
                    
                    // Parse individual items with safe type casting
                    let top = self.parseOutfitItem(from: topData)
                    let bottom = self.parseOutfitItem(from: bottomData)
                    let shoes = self.parseOutfitItem(from: shoesData)
                    
                    return SavedOutfit(
                        id: document.documentID,
                        name: name,
                        style: data["style"] as? String ?? name,
                        createdAt: createdAt,
                        top: top,
                        bottom: bottom,
                        shoes: shoes
                    )
                } ?? []
            }
    }

    private func parseOutfitItem(from data: [String: Any]) -> OutfitItem {
        let rgbData = data["rgbValues"] as? [String: Double] ?? [:]
        
        return OutfitItem(
            brand: data["brand"] as? String ?? "",
            size: data["size"] as? String ?? "",
            type: data["type"] as? String ?? "",
            url: data["url"] as? String ?? "",
            rgbValues: RGBValues(
                red: rgbData["red"] ?? 0,
                green: rgbData["green"] ?? 0,
                blue: rgbData["blue"] ?? 0
            )
        )
    }
    
    func deleteOutfit(_ outfitId: String) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
            
        isDeletingOutfit = true  // Start loading
            
        db.collection("users").document(userId).collection("outfits")
            .document(outfitId).delete() { error in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.isDeletingOutfit = false  // Stop loading
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                    } else {
                        print("Successfully deleted outfit with ID: \(outfitId)")
                        self.successMessage = "Outfit successfully deleted"
                    }
                }
            }
    }
}

// MARK: - Views
struct FavouriteView: View {
    @StateObject private var viewModel = FavouritesViewModel()
    @State private var showAddView = false
    //    @State private var showUploadAlert = false
    @State private var showDeleteAlert = false
    @State private var selectedOutfitId: String?
    @State private var isCarouselView = true
    @State private var currentCarouselIndex = 0
    @State private var searchText = ""
    @State private var isSearching = false
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentCardTopImage: UIImage?
    @State private var currentCardBottomImage: UIImage?
    @State private var currentCardShoesImage: String?
    
    
    private var headerColor: Color {
        colorScheme == .dark ? .white : .purple
    }
    
    // A helper function that determines if an outfit matches search criteria
    private func matchesSearchCriteria(outfit: SavedOutfit) -> Bool {
        // Check if name contains search text (case insensitive)
        let nameMatch = outfit.name.localizedCaseInsensitiveContains(searchText)
        
        // Check if style contains search text (case insensitive)
        let styleMatch = outfit.style.localizedCaseInsensitiveContains(searchText)
        
        // Return true if either name or style matches
        return nameMatch || styleMatch
    }
    
    // The computed property for filtered outfits
    private var filteredOutfits: [SavedOutfit] {
        // If search text is empty, return all outfits
        guard !searchText.isEmpty else {
            return viewModel.savedOutfits
        }
        
        // Filter outfits using the helper function
        return viewModel.savedOutfits.filter(matchesSearchCriteria)
    }
    
    private struct SearchBarView: View {
        @Binding var searchText: String
        @Binding var isSearching: Bool
        let headerColor: Color
        
        var body: some View {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(headerColor)
                TextField("Search outfits...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: {
                    isSearching = false
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(headerColor)
                }
            }
        }
    }
    
    private struct HeaderView: View {
        @Binding var isSearching: Bool
        @Binding var searchText: String
        @Binding var isCarouselView: Bool
        let headerColor: Color
        let dismiss: DismissAction
        
        var body: some View {
            HStack {
                if isSearching {
                    SearchBarView(searchText: $searchText,
                                isSearching: $isSearching,
                                headerColor: headerColor)
                } else {
                    HStack(spacing: 8) {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(headerColor)
                                .font(.system(size: 20, weight: .medium))
                        }
                        
                        Text("Favourites")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(headerColor)
                        
                        Spacer()
                        
                        HStack(spacing: 16) {
                            Button(action: {
                                isSearching = true
                            }) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(headerColor)
                                    .font(.system(size: 20))
                            }
                            
                            Button(action: {
                                withAnimation {
                                    isCarouselView.toggle()
                                }
                            }) {
                                Image(systemName: isCarouselView ? "square.grid.2x2" : "square.stack.fill")
                                    .foregroundColor(headerColor)
                                    .font(.system(size: 20))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 45)
        }
    }
        
    
    private struct ContentView: View {
        let viewModel: FavouritesViewModel
        let filteredOutfits: [SavedOutfit]
        let isCarouselView: Bool
        @Binding var currentCarouselIndex: Int
        let searchText: String
        @Binding var selectedOutfitId: String?
        @Binding var showDeleteAlert: Bool
        
        var body: some View {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
            } else if filteredOutfits.isEmpty {
                VStack {
                    Image(systemName: "heart.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                        .padding()
                    Text(searchText.isEmpty ? "No saved outfits yet" : "No matching outfits found")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                .padding()
            } else {
                Group {
                    if isCarouselView {
                        CarouselView(
                            outfits: filteredOutfits,
                            currentIndex: $currentCarouselIndex,
                            onDelete: { id in
                                selectedOutfitId = id
                                showDeleteAlert = true
                            }
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(filteredOutfits) { outfit in
                                    OutfitCard(outfit: outfit)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
        }
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                HeaderView(
                    isSearching: $isSearching,
                    searchText: $searchText,
                    isCarouselView: $isCarouselView,
                    headerColor: headerColor,
                    dismiss: dismiss
                )
                
                ContentView(
                    viewModel: viewModel,
                    filteredOutfits: filteredOutfits,
                    isCarouselView: isCarouselView,
                    currentCarouselIndex: $currentCarouselIndex,
                    searchText: searchText,
                    selectedOutfitId: $selectedOutfitId,
                    showDeleteAlert: $showDeleteAlert
                )
                
                Spacer()
            }
            
            // Bottom corner buttons
            if !filteredOutfits.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        // Bottom left button (Share)
                        let outfit = filteredOutfits[currentCarouselIndex]
                        let shareableOutfit = ShareableOutfit(
                            name: outfit.name,
                            style: outfit.style,
                            brands: [outfit.top.brand, outfit.bottom.brand, outfit.shoes.brand]
                        )
                        
                        ShareLink(
                            item: shareableOutfit,
                            preview: SharePreview(outfit.name)
                        ) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.purple)
                                .frame(width: 60, height: 60)
                        }
                        .padding(.leading, 20)
                        
                        Spacer()
                        
                        // Bottom right button (Delete)
                        Button(action: {
                            selectedOutfitId = outfit.id
                            showDeleteAlert = true
                        }) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.red)
                                .frame(width: 60, height: 60)
                        }
                        .padding(.trailing, 20)
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showAddView) {
            AddView()
        }
        .alert("Delete Outfit", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {
                selectedOutfitId = nil
            }
            Button("Delete", role: .destructive) {
                if let id = selectedOutfitId {
                    viewModel.deleteOutfit(id)
                    if currentCarouselIndex >= filteredOutfits.count - 1 {
                        currentCarouselIndex = max(0, filteredOutfits.count - 2)
                    }
                }
                selectedOutfitId = nil
            }
        } message: {
            Text("Are you sure you want to delete this outfit?")
        }
        .onAppear {
            viewModel.fetchOutfits()
        }
        .alert(item: Binding(
            get: { viewModel.errorMessage.map { ErrorAlert(message: $0) } },
            set: { _ in viewModel.errorMessage = nil }
        )) { error in
            Alert(
                title: Text("Error"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert("Success", isPresented: Binding(
            get: { viewModel.successMessage != nil },
            set: { if !$0 { viewModel.successMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                viewModel.successMessage = nil
            }
        } message: {
            Text(viewModel.successMessage ?? "")
        }
        .overlay {
            if viewModel.isDeletingOutfit {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                LoadingAlert(message: "Deleting outfit...")
            }
        }
    }
}

struct ShareableOutfit: Transferable {
    let name: String
    let style: String
    let brands: [String]
    
    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.description)
    }
    
    var description: String {
        """
        Outfit: \(name)
        Style: \(style)
        Items:
        - \(brands.joined(separator: "\n- "))
        """
    }
}

struct CarouselView: View {
    let outfits: [SavedOutfit]
    @Binding var currentIndex: Int
    let onDelete: (String) -> Void
    
    var body: some View {
        ZStack {
            TabView(selection: $currentIndex) {
                ForEach(Array(outfits.enumerated()), id: \.element.id) { index, outfit in
                    OutfitCard(outfit: outfit)
                        .tag(index)
                        .padding(.horizontal)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            // Navigation Chevrons
            HStack {
                Button(action: {
                    withAnimation {
                        currentIndex = max(currentIndex - 1, 0)
                    }
                }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.purple)
                        .opacity(currentIndex > 0 ? 1 : 0.3)
                }
                .padding(.leading)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        currentIndex = min(currentIndex + 1, outfits.count - 1)
                    }
                }) {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.purple)
                        .opacity(currentIndex < outfits.count - 1 ? 1 : 0.3)
                }
                .padding(.trailing)
            }
            
            // Custom Page Indicator
            VStack {
                Spacer()
                HStack(spacing: 8) {
                    ForEach(0..<outfits.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentIndex ? Color.purple : Color.gray)
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom)
            }
        }
        .frame(height: 600)
    }
}

struct OutfitCard: View {
    let outfit: SavedOutfit
    @State private var topImage: UIImage?
    @State private var bottomImage: UIImage?
    @State private var shoesImage: UIImage?
    
    func loadImages() async {
        // Load top image
        if let url = URL(string: outfit.top.url),
           let (data, _) = try? await URLSession.shared.data(from: url) {
            topImage = UIImage(data: data)
        }
        
        // Load bottom image
        if let url = URL(string: outfit.bottom.url),
           let (data, _) = try? await URLSession.shared.data(from: url) {
            bottomImage = UIImage(data: data)
        }
        
        // Load shoes image
        if let url = URL(string: outfit.shoes.url),
           let (data, _) = try? await URLSession.shared.data(from: url) {
            shoesImage = UIImage(data: data)
        }
    }
    
    // Helper method to get all loaded images
    func getLoadedImages() -> [UIImage] {
        var images: [UIImage] = []
        if let top = topImage { images.append(top) }
        if let bottom = bottomImage { images.append(bottom) }
        if let shoes = shoesImage { images.append(shoes) }
        return images
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Header section with name and style
            VStack(spacing: 4) {
                Text(outfit.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(outfit.style)
                    .font(.subheadline)
                    .foregroundColor(.purple)
                    .lineLimit(1)
            }
            
            // Top
            VStack(spacing: 4) {
                if let image = topImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 100)
                } else {
                    AsyncImage(url: URL(string: outfit.top.url)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .failure:
                            Image(systemName: "photo")
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(height: 100)
                }
                
                Text(outfit.top.brand)
                    .font(.caption)
                    .lineLimit(1)
            }
            
            // Bottom
            VStack(spacing: 4) {
                if let image = bottomImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 100)
                } else {
                    AsyncImage(url: URL(string: outfit.bottom.url)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .failure:
                            Image(systemName: "photo")
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(height: 100)
                }
                
                Text(outfit.bottom.brand)
                    .font(.caption)
                    .lineLimit(1)
            }
            
            // Shoes
            VStack(spacing: 4) {
                if let image = shoesImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 100)
                } else {
                    AsyncImage(url: URL(string: outfit.shoes.url)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .failure:
                            Image(systemName: "photo")
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(height: 100)
                }
                
                Text(outfit.shoes.brand)
                    .font(.caption)
                    .lineLimit(1)
            }
            
            Text(DateFormatter.localizedString(from: outfit.createdAt, dateStyle: .medium, timeStyle: .none))
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .onAppear {
            Task {
                await loadImages()
            }
        }
    }
}

struct ErrorAlert: Identifiable {
    let id = UUID()
    let message: String
}

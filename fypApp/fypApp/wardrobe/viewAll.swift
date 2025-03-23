//import SwiftUI
//import FirebaseFirestore
//import FirebaseAuth
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - Models
struct WardrobeItem: Identifiable, Codable, Hashable {
    let id: String
    let url: String
    let type: String
    let timestamp: String
    let brand: String
    let size: String
}

struct Category: Identifiable {
    let id: String
    let label: String
    let icon: String?
}

// MARK: - ViewModel
class WardrobeViewModel: ObservableObject {
    @Published var items: [WardrobeItem] = []
    @Published var searchQuery = ""
    @Published var selectedCategory: String? = nil
    @Published var isLoading = false
    
    private var db = Firestore.firestore()
    
    let categories: [Category] = [
        Category(id: "all", label: "All", icon: nil),
        Category(id: "Tops", label: "Tops", icon: "tshirt"),
        Category(id: "Bottoms", label: "Bottoms", icon: "person"),
        Category(id: "Shoes", label: "Shoes", icon: "shoe")
    ]
    
    func deleteItem(_ item: WardrobeItem, completion: @escaping (Bool) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        let userRef = db.collection("users").document(userId)
        
        userRef.getDocument { [weak self] (document, error) in
            if let document = document, document.exists,
               var photoArray = document.data()?["photoArray"] as? [[String: Any]] {
                
                // Find and remove the item from the array
                photoArray.removeAll { dict in
                    dict["url"] as? String == item.url &&
                    dict["type"] as? String == item.type &&
                    dict["timestamp"] as? String == item.timestamp &&
                    dict["brand"] as? String == item.brand &&
                    dict["size"] as? String == item.size
                }
                
                // Update Firestore with the new array
                userRef.updateData(["photoArray": photoArray]) { error in
                    if let error = error {
                        print("Error updating document: \(error)")
                        completion(false)
                    } else {
                        DispatchQueue.main.async {
                            // Update the local items array
                            self?.items.removeAll { $0.id == item.id }
                            completion(true)
                        }
                    }
                }
            } else {
                completion(false)
            }
        }
    }
    
    func fetchPhotos() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        let userRef = db.collection("users").document(userId)
        
        userRef.getDocument { [weak self] (document, error) in
            if let document = document, document.exists,
               let photoArray = document.data()?["photoArray"] as? [[String: Any]] {
                
                let wardrobeItems = photoArray.compactMap { photoData -> WardrobeItem? in
                    guard let url = photoData["url"] as? String,
                          let type = photoData["type"] as? String,
                          let timestamp = photoData["timestamp"] as? String,
                          let brand = photoData["brand"] as? String,
                          let size = photoData["size"] as? String else {
                        return nil
                    }
                    return WardrobeItem(
                        id: UUID().uuidString,
                        url: url,
                        type: type,
                        timestamp: timestamp,
                        brand: brand,
                        size: size
                    )
                }
                
                DispatchQueue.main.async {
                    self?.items = wardrobeItems
                    self?.isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    self?.isLoading = false
                }
            }
        }
    }
    
    var filteredItems: [WardrobeItem] {
        var filtered = items
        
        if !searchQuery.isEmpty {
            filtered = filtered.filter { item in
                item.size.lowercased().contains(searchQuery.lowercased()) ||
                item.brand.lowercased().contains(searchQuery.lowercased())
            }
        }
        
        if let category = selectedCategory {
            if category != "all" {
                filtered = filtered.filter { item in
                    switch category {
                    case "Tops":
                        return item.type.lowercased() == "tops" ||
                               item.type.lowercased() == "top" ||
                               item.type.lowercased() == "tshirt"
                    case "Bottoms":
                        return item.type.lowercased() == "bottoms" ||
                               item.type.lowercased() == "bottom" ||
                               item.type.lowercased() == "pants"
                    case "Shoes":
                        return item.type.lowercased() == "shoes" ||
                               item.type.lowercased() == "shoe"
                    default:
                        return true
                    }
                }
            }
        }
        
        return filtered
    }
}

// Add TabView index state
struct WardrobeView: View {
    @StateObject private var viewModel = WardrobeViewModel()
    @Environment(\.colorScheme) var colorScheme
//    @Environment(\.dismiss) var dismiss
    @State private var showSearch = false
    @State private var isRefreshing = false
    @State private var currentIndex = 0
    @State private var isGridView = true
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        NavigationStack{
            VStack(spacing: 0) {
                customHeader
                if showSearch {
                    searchBar
                }
                
                categorySection
                
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.filteredItems.isEmpty {
                    emptyStateView
                } else {
                    contentView
                }
            }
            .background(colorScheme == .dark ? Color.black : Color.white)
            .navigationBarHidden(true)
            .navigationDestination(for: WardrobeItem.self) { item in
                PhotoDetailView(item: item, viewModel: viewModel)
            }
            .onAppear {
                viewModel.fetchPhotos()
            }
        }
    }
    
    private var customHeader: some View {
        HStack {
            HStack(spacing: 12) {
                Text("My Wardrobe")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? .white : .purple)
            }
            Spacer()
            
            headerButtons
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var headerButtons: some View {
        HStack {
            Button(action: {
                withAnimation {
                    isGridView.toggle()
                }
            }) {
                Image(systemName: isGridView ? "rectangle.grid.1x2" : "square.grid.2x2")
                    .foregroundColor(colorScheme == .dark ? .white : .purple)
                    .font(.system(size: 20))
            }
            
            Button(action: {
                showSearch.toggle()
            }) {
                Image(systemName: showSearch ? "xmark" : "magnifyingglass")
                    .foregroundColor(colorScheme == .dark ? .white : .purple)
            }
            .padding(.leading, 12)
        }
    }
    
    private var searchBar: some View {
        HStack {
            TextField("Search by brand or size...", text: $viewModel.searchQuery)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
            
            if !viewModel.searchQuery.isEmpty {
                Button(action: {
                    viewModel.searchQuery = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
    }
    
    private var categorySection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(viewModel.categories) { category in
                    CategoryButton(category: category,
                                 isSelected: viewModel.selectedCategory == category.id,
                                 colorScheme: colorScheme) {
                        viewModel.selectedCategory = category.id
                    }
                }
            }
            .padding()
        }
    }
    
    private var loadingView: some View {
        ProgressView()
            .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tshirt")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("No items found")
                .font(.headline)
                .foregroundColor(.gray)
        }
        .padding(.top, 50)
    }
    
    private var contentView: some View {
        Group {
            if isGridView {
                gridView
            } else {
                carouselView
            }
        }
    }
    
    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(viewModel.filteredItems) { item in
                    GridItemView(item: item, colorScheme: colorScheme, viewModel: viewModel)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .refreshable {
            isRefreshing = true
            viewModel.fetchPhotos()
            isRefreshing = false
        }
    }
    
    private var carouselView: some View {
        VStack {
            ZStack {
                TabView(selection: $currentIndex) {
                    ForEach(Array(viewModel.filteredItems.enumerated()), id: \.element.id) { index, item in
                        CarouselItemView(item: item, viewModel: viewModel)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                carouselNavigationButtons
            }
            
            paginationDots
        }
    }
    
    private var carouselNavigationButtons: some View {
        HStack {
            CarouselNavigationButton(
                direction: .previous,
                currentIndex: currentIndex,
                maxIndex: viewModel.filteredItems.count - 1
            ) {
                withAnimation {
                    currentIndex = max(0, currentIndex - 1)
                }
            }
            
            Spacer()
            
            CarouselNavigationButton(
                direction: .next,
                currentIndex: currentIndex,
                maxIndex: viewModel.filteredItems.count - 1
            ) {
                withAnimation {
                    currentIndex = min(viewModel.filteredItems.count - 1, currentIndex + 1)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var paginationDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<viewModel.filteredItems.count, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? Color.purple : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical)
    }
}

// Helper Views
struct CategoryButton: View {
    let category: Category
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                if let iconName = category.icon {
                    Image(systemName: iconName)
                }
                Text(category.label)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isSelected ? Color.purple : Color.clear)
            .foregroundColor(isSelected ? .white : (colorScheme == .dark ? .white : .purple))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.purple, lineWidth: 1)
            )
        }
    }
}

struct GridItemView: View {
    let item: WardrobeItem
    let colorScheme: ColorScheme
    let viewModel: WardrobeViewModel
    
    var body: some View {
//        NavigationLink(destination: PhotoDetailView(item: item, viewModel: viewModel)) {
        NavigationLink(value: item){
            VStack(spacing: 8) {
                AsyncImage(url: URL(string: item.url)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ProgressView()
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Text(item.size)
                    .font(.system(size: 14))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 4)
        }
    }
}

enum CarouselDirection {
    case previous
    case next
}

struct CarouselNavigationButton: View {
    let direction: CarouselDirection
    let currentIndex: Int
    let maxIndex: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: direction == .previous ? "chevron.left.circle.fill" : "chevron.right.circle.fill")
                .resizable()
                .frame(width: 40, height: 40)
                .foregroundColor(.purple)
                .opacity(isEnabled ? 0.8 : 0.2)
        }
        .disabled(!isEnabled)
    }
    
    private var isEnabled: Bool {
        switch direction {
        case .previous:
            return currentIndex > 0
        case .next:
            return currentIndex < maxIndex
        }
    }
}

// New CarouselItemView
struct CarouselItemView: View {
    let item: WardrobeItem
    @ObservedObject var viewModel: WardrobeViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
//        NavigationLink(destination: PhotoDetailView(item: item, viewModel: viewModel)) {
        NavigationLink(value: item){
            VStack(spacing: 12) {
                AsyncImage(url: URL(string: item.url)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView()
                }
                .frame(height: 400)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(spacing: 8) {
                    Text(item.brand)
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    
                    Text(item.size)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text(item.type.capitalized)
                        .font(.caption)
                        .foregroundColor(.purple)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding(.bottom)
            }
            .padding(.horizontal)
        }
    }
}

struct PhotoDetailView: View {
    let item: WardrobeItem
    @Environment(\.colorScheme) var colorScheme
//    @Environment(\.dismiss) var dismiss
    @State private var showingDeleteAlert = false
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: WardrobeViewModel
    
    func handleDelete() {
        guard !isDeleting else { return }
        isDeleting = true
        
        viewModel.deleteItem(item) { success in
            isDeleting = false
            if success {
                showingDeleteConfirmation = true
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                AsyncImage(url: URL(string: item.url)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView()
                }
                .frame(maxHeight: 400)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 16) {
                    DetailRow(label: "Size", value: item.size)
                    DetailRow(label: "Brand", value: item.brand)
                    DetailRow(label: "Type", value: item.type.capitalized)
                }
                .padding(.horizontal)
                
                Button(action: {
                    showingDeleteAlert = true
                }) {
                    HStack {
                        Text("Delete Item")
                            .fontWeight(.semibold)
                        if isDeleting {
                            ProgressView()
                                .tint(.white)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isDeleting ? Color.gray : Color.red)
                    .cornerRadius(10)
                }
                .disabled(isDeleting)
                .padding(.horizontal)
                .padding(.top, 8)
                
                NavigationLink(destination: LinksView()) {
                    Text("Useful Links and Help")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Item Details")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .disabled(isDeleting)
            }
        }
        .alert("Delete Item", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                handleDelete()
            }
        } message: {
            Text("Are you sure you want to delete this item?")
        }
        .alert("Success", isPresented: $showingDeleteConfirmation) {
            Button("OK") {
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("Item has been deleted successfully")
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label + ":")
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? .white : .black)
            
            Text(value)
                .font(.body)
                .foregroundColor(colorScheme == .dark ? .gray : .gray)
        }
    }
}


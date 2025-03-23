//
//  OutfitView.swift
//  fypApp
//
//  Created by Hasan Shariff on 14/02/2025.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct StoredOutfit: Identifiable {
    let id = UUID()
    let topUrl: String
    let bottomUrl: String
    let shoesUrl: String
}

// MARK: - Outfit Manager
class OutfitManager: ObservableObject {
    @Published var storedOutfits: [StoredOutfit] = []
    private let db = Firestore.firestore()
    
    private func createRGBDict(_ values: OutfitView.RGBValues?) -> [String: Double] {
        return [
            "red": values?.red ?? 0,
            "green": values?.green ?? 0,
            "blue": values?.blue ?? 0
        ]
    }
    
    private func createItemDict(_ item: OutfitView.WardrobeItem?) -> [String: Any] {
        return [
            "brand": item?.brand ?? "",
            "size": item?.size ?? "",
            "type": item?.type ?? "",
            "url": item?.url ?? "",
            "rgbValues": createRGBDict(item?.rgbValues)
        ]
    }
    
    func checkOutfitNameExists(_ name: String) async throws -> Bool {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw OutfitError.userNotAuthenticated
        }
        
        let querySnapshot = try await db.collection("users")
            .document(userId)
            .collection("outfits")
            .whereField("name", isEqualTo: name)
            .getDocuments()
        
        return !querySnapshot.documents.isEmpty
    }
    
    func checkOutfitExists(_ outfit: OutfitView.GeneratedOutfit) async throws -> Bool {
            guard let userId = Auth.auth().currentUser?.uid,
                  let top = outfit.top,
                  let bottom = outfit.bottom,
                  let shoes = outfit.shoes else {
                throw OutfitError.userNotAuthenticated
            }
            
            let querySnapshot = try await db.collection("users")
                .document(userId)
                .collection("outfits")
                .getDocuments()
            
            return querySnapshot.documents.contains { document in
                let data = document.data()
                guard let topData = data["top"] as? [String: Any],
                      let bottomData = data["bottom"] as? [String: Any],
                      let shoesData = data["shoes"] as? [String: Any] else {
                    return false
                }
                
                return topData["url"] as? String == top.url &&
                       bottomData["url"] as? String == bottom.url &&
                       shoesData["url"] as? String == shoes.url
            }
        }
    
    func saveOutfit(name: String, style: String, outfit: OutfitView.GeneratedOutfit) async throws {
        if try await checkOutfitNameExists(name) {
            throw OutfitError.nameAlreadyExists
        }
        
        if try await checkOutfitExists(outfit) {
            throw OutfitError.outfitAlreadyExists
        }
        
        guard let userId = Auth.auth().currentUser?.uid else {
            throw OutfitError.userNotAuthenticated
        }
        
        let topDict = createItemDict(outfit.top)
        let bottomDict = createItemDict(outfit.bottom)
        let shoesDict = createItemDict(outfit.shoes)
        
        let outfitData: [String: Any] = [
            "name": name,
            "style": style,
            "createdAt": Timestamp(),
            "top": topDict,
            "bottom": bottomDict,
            "shoes": shoesDict
        ]
        
        try await db.collection("users").document(userId).collection("outfits").addDocument(data: outfitData)
        
        // Update stored outfits after saving
        await loadStoredOutfits()
    }
    
    func deleteItem(with url: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw OutfitError.userNotAuthenticated
        }
        
        // Get user document reference
        let userRef = db.collection("users").document(userId)
        
        // Get the current photoArray
        let document = try await userRef.getDocument()
        guard var photoArray = document.data()?["photoArray"] as? [[String: Any]] else {
            print("Error: photoArray not found")
            return
        }
        
        // Find and remove the item with the matching URL
        if let index = photoArray.firstIndex(where: { ($0["url"] as? String) == url }) {
            photoArray.remove(at: index)
            
            // Update Firestore
            try await userRef.updateData(["photoArray": photoArray])
            print("Successfully deleted item with URL: \(url)")
        } else {
            print("Item with URL \(url) not found in photoArray")
        }
    }
    
    func resetRejectionCount() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw OutfitError.userNotAuthenticated
        }
        
        // Get user document reference
        let userRef = db.collection("users").document(userId)
        
        // Get the current photoArray
        let document = try await userRef.getDocument()
        guard var photoArray = document.data()?["photoArray"] as? [[String: Any]] else {
            print("Error: photoArray not found")
            return
        }
        
        // Reset rejection count for all items
        for i in 0..<photoArray.count {
            var item = photoArray[i]
            item["rejectionCount"] = 0
            photoArray[i] = item
        }
        
        // Update Firestore
        try await userRef.updateData(["photoArray": photoArray])
        print("Reset rejection count for all items")
    }
    
    @MainActor
    func loadStoredOutfits() async {
        do {
            self.storedOutfits = try await fetchStoredOutfits()
        } catch {
            print("Error loading stored outfits: \(error)")
        }
    }
    
    func fetchStoredOutfits() async throws -> [StoredOutfit] {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw OutfitError.userNotAuthenticated
        }
        
        let querySnapshot = try await db.collection("users")
            .document(userId)
            .collection("outfits")
            .getDocuments()
        
        return querySnapshot.documents.compactMap { document in
            let data = document.data()  // Remove the unnecessary cast here
            guard let top = data["top"] as? [String: Any],
                  let bottom = data["bottom"] as? [String: Any],
                  let shoes = data["shoes"] as? [String: Any] else {
                return nil
            }
            
            return StoredOutfit(
                topUrl: top["url"] as? String ?? "",
                bottomUrl: bottom["url"] as? String ?? "",
                shoesUrl: shoes["url"] as? String ?? ""
            )
        }
    }
    
    func isOutfitStored(_ outfit: OutfitView.GeneratedOutfit) -> Bool {
        guard let top = outfit.top,
              let bottom = outfit.bottom,
              let shoes = outfit.shoes else {
            return false
        }
        
        return storedOutfits.contains { storedOutfit in
            return storedOutfit.topUrl == top.url &&
                   storedOutfit.bottomUrl == bottom.url &&
                   storedOutfit.shoesUrl == shoes.url
        }
    }
    
    func checkItemRejectionCount(for url: String) async throws -> Int {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw OutfitError.userNotAuthenticated
        }
        
        // Get user document reference
        let userRef = db.collection("users").document(userId)
        
        // Get the current photoArray
        let document = try await userRef.getDocument()
        guard let photoArray = document.data()?["photoArray"] as? [[String: Any]] else {
            print("Error: photoArray not found")
            return 0
        }
        
        // Find the item with matching URL
        if let itemData = photoArray.first(where: { ($0["url"] as? String) == url }),
           let rejectionCount = itemData["rejectionCount"] as? Int {
            return rejectionCount
        }
        
        return 0
    }

    func incrementRejectionCount(for itemUrls: [String]) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw OutfitError.userNotAuthenticated
        }
        
        // Get user document reference
        let userRef = db.collection("users").document(userId)
        
        // Get the current photoArray
        let document = try await userRef.getDocument()
        guard var photoArray = document.data()?["photoArray"] as? [[String: Any]] else {
            print("Error: photoArray not found")
            return
        }
        
        // Update rejection counts for unlocked items
        var updated = false
        for url in itemUrls {
            if let index = photoArray.firstIndex(where: { ($0["url"] as? String) == url }) {
                var item = photoArray[index]
                let currentCount = item["rejectionCount"] as? Int ?? 0
                item["rejectionCount"] = currentCount + 1
                photoArray[index] = item
                updated = true
                print("Incremented rejection count for item with URL: \(url)")
            }
        }
        
        // Update Firestore if changes were made
        if updated {
            try await userRef.updateData(["photoArray": photoArray])
            print("Updated photoArray with new rejection counts")
        }
    }
    
    // Add this method to OutfitManager
    func resetRejectionCountForItem(with url: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw OutfitError.userNotAuthenticated
        }
        
        // Get the current photoArray
        let document = try await db.collection("users").document(userId).getDocument()
        guard var photoArray = document.data()?["photoArray"] as? [[String: Any]] else {
            print("Error: photoArray not found")
            return
        }
        
        // Update rejection count
        if let index = photoArray.firstIndex(where: { ($0["url"] as? String) == url }) {
            var item = photoArray[index]
            item["rejectionCount"] = 0
            photoArray[index] = item
            
            // Update Firestore
            try await db.collection("users").document(userId).updateData(["photoArray": photoArray])
            print("Reset rejection count for item with URL: \(url)")
        }
    }
}

enum OutfitError: Error {
    case userNotAuthenticated
    case saveFailed
    case nameAlreadyExists
    case outfitAlreadyExists
}

struct OutfitView: View {
    let selectedStyle: StyleOption
    let photoArray: [[String: Any]]
    @Environment(\.colorScheme) var colorScheme
    @State private var navigateToFavourites = false
    @State private var showingSaveDialog = false
    @State private var outfitName = ""
    @State private var currentOutfit: GeneratedOutfit?
    @StateObject private var outfitManager = OutfitManager()
    @State private var showError = false
    @State private var errorMessage = ""
    
    // New state for complete outfit tracking
    @State private var sortedOutfits: [GeneratedOutfit] = []
    @State private var currentOutfitIndex: Int = 0
    
    @State private var currentTopIndex: Int = 0
    @State private var currentBottomIndex: Int = 0
    @State private var currentShoeIndex: Int = 0
    
    @State private var sortedTops: [WardrobeItem] = []
    @State private var sortedBottoms: [WardrobeItem] = []
    @State private var sortedShoes: [WardrobeItem] = []
    
    @State private var showingSavePrompt = false
    
    @State private var showingResetModal = false
    @State private var isResettingCounts = false
    
    @State private var successMessage = ""
    @State private var showSuccessIndicator = false
    
    @State private var showRejectionModal = false
    @State private var rejectedItem: WardrobeItem?
    @State private var rejectedItemType: String = ""
    @State private var rejectedItemsQueue: [(item: WardrobeItem, type: String)] = []
    
    @Environment(\.openURL) var openURL
    
    // MARK: - Data Structures
    struct WardrobeItem {
        let brand: String
        let rgbValues: RGBValues
        let size: String
        let type: String
        let url: String
        var score: Double = 0.0
        var rejectionCount: Int = 0
    }
    
    struct RGBValues {
        let red: Double
        let green: Double
        let blue: Double
    }
    
    struct GeneratedOutfit {
        let top: WardrobeItem?
        let bottom: WardrobeItem?
        let shoes: WardrobeItem?
        var topLocked: Bool = false
        var bottomLocked: Bool = false
        var shoesLocked: Bool = false
        
        var allItemsLocked: Bool {
            return topLocked && bottomLocked && shoesLocked
        }
    }
    
    struct SimilarityMatrix {
        var matrix: [[Double]]
        let items: [WardrobeItem]
        
        init(items: [WardrobeItem]) {
            self.items = items
            self.matrix = Array(repeating: Array(repeating: 0.0, count: items.count), count: items.count)
            calculateSimilarities()
        }
        
        mutating private func calculateSimilarities() {
            for i in 0..<items.count {
                for j in 0..<items.count {
                    matrix[i][j] = calculateColorSimilarity(items[i].rgbValues, items[j].rgbValues)
                }
            }
        }
        
        private func calculateColorSimilarity(_ rgb1: RGBValues, _ rgb2: RGBValues) -> Double {
            let rDiff = rgb1.red - rgb2.red
            let gDiff = rgb1.green - rgb2.green
            let bDiff = rgb1.blue - rgb2.blue
            return sqrt(rDiff * rDiff + gDiff * gDiff + bDiff * bDiff)
        }
    }
    
    struct RejectionModal: View {
        let item: WardrobeItem
        let itemType: String
        let onKeep: () -> Void
        let onDelete: () -> Void
        let onDonate: () -> Void
        @State private var isDeleting = false
        
        var body: some View {
            VStack(spacing: 20) {
                Text("We noticed you don't like this \(itemType)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .padding(.top)
                    .multilineTextAlignment(.center)
                
                AsyncImage(url: URL(string: item.url)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 120)
                            .cornerRadius(10)
                    case .failure:
                        Image(systemName: "photo")
                            .frame(height: 120)
                    @unknown default:
                        EmptyView()
                    }
                }
                .padding(.horizontal)
                
                Text("Would you like to remove it from your wardrobe?")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                HStack(spacing: 15) {
                    Button(action: onKeep) {
                        Text("Keep it")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 100)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    
                    Button(action: onDonate) {
                        Text ("Donate Item")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 100)
                            .padding(.vertical, 12)
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                    
                    Button(action: onDelete) {
                        Group {
                            if isDeleting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Delete")
                            }
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 100)
                        .padding(.vertical, 12)
                        .background(Color.red)
                        .cornerRadius(10)
                    }
                    .disabled(isDeleting)
                    .opacity(isDeleting ? 0.6 : 1)
                }
                .padding(.bottom)
            }
            .padding()
            .frame(width: 300)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 10)
        }
    }
    
    private func loadStoredOutfits() {
            Task {
                do {
                    let outfits = try await outfitManager.fetchStoredOutfits()
                    await MainActor.run {
                        outfitManager.storedOutfits = outfits
                    }
                } catch {
                    print("Error loading stored outfits: \(error)")
                }
            }
        }
    
    private func createNewOutfit() -> GeneratedOutfit? {
            guard !sortedTops.isEmpty && !sortedBottoms.isEmpty && !sortedShoes.isEmpty else {
                return nil
            }
            
            for topIndex in 0..<sortedTops.count {
                for bottomIndex in 0..<sortedBottoms.count {
                    for shoeIndex in 0..<sortedShoes.count {
                        let outfit = GeneratedOutfit(
                            top: sortedTops[topIndex],
                            bottom: sortedBottoms[bottomIndex],
                            shoes: sortedShoes[shoeIndex]
                        )
                        
                        if !outfitManager.isOutfitStored(outfit) {
                            currentTopIndex = topIndex
                            currentBottomIndex = bottomIndex
                            currentShoeIndex = shoeIndex
                            return outfit
                        }
                    }
                }
            }
            return nil
        }
    
    private func toggleLock(for item: String) {
        guard var outfit = currentOutfit else { return }
        
        switch item {
        case "top":
            outfit.topLocked.toggle()
        case "bottom":
            outfit.bottomLocked.toggle()
        case "shoes":
            outfit.shoesLocked.toggle()
        default:
            return
        }
        
        currentOutfit = outfit
        
        // If all items are locked, show save prompt
        if outfit.topLocked && outfit.bottomLocked && outfit.shoesLocked {
            showingSaveDialog = true
        }
    }
    
    // MARK: - Outfit Generation Functions
    private func generateOutfit() {
            print("Starting outfit generation with style: \(selectedStyle.title)")
            
            // Keep track of locked items
            let lockedTop = currentOutfit?.topLocked == true ? currentOutfit?.top : nil
            let lockedBottom = currentOutfit?.bottomLocked == true ? currentOutfit?.bottom : nil
            let lockedShoes = currentOutfit?.shoesLocked == true ? currentOutfit?.shoes : nil
            
            guard !photoArray.isEmpty else {
                print("Error: PhotoArray is empty")
                return
            }
            
            // Convert dictionary array to WardrobeItem array
            let items = photoArray.compactMap { dict -> WardrobeItem? in
                guard let rgbDict = dict["rgbValues"] as? [String: Double],
                      let brand = dict["brand"] as? String,
                      let size = dict["size"] as? String,
                      let type = dict["type"] as? String,
                      let url = dict["url"] as? String else {
                    print("Error parsing item: \(dict)")
                    return nil
                }
                
                return WardrobeItem(
                    brand: brand,
                    rgbValues: RGBValues(
                        red: rgbDict["red"] ?? 0.0,
                        green: rgbDict["green"] ?? 0.0,
                        blue: rgbDict["blue"] ?? 0.0
                    ),
                    size: size,
                    type: type,
                    url: url
                )
            }
            
            let similarityMatrix = SimilarityMatrix(items: items)
            
            // Separate items by type
            let tops = items.filter { $0.type == "Tops" }
            let bottoms = items.filter { $0.type == "Bottoms" }
            let shoes = items.filter { $0.type == "Shoes" }
            
            print("Filtered counts - Tops: \(tops.count), Bottoms: \(bottoms.count), Shoes: \(shoes.count)")
            
            if selectedStyle.id == 3 { // Sandwich method
                print("Processing Sandwich method")
                var topShoeCombinations: [(top: WardrobeItem, shoe: WardrobeItem, similarity: Double)] = []
                
                // If both top and shoes are locked, use only those items
                // If one is locked, only find combinations with the locked item
                // If neither is locked, find all combinations
                let availableTops = lockedTop != nil ? [lockedTop!] : tops
                let availableShoes = lockedShoes != nil ? [lockedShoes!] : shoes
                
                for top in availableTops {
                    for shoe in availableShoes {
                        let topColor = normalizeRGBValues(top.rgbValues)
                        let shoeColor = normalizeRGBValues(shoe.rgbValues)
                        let similarity = 1.0 - (calculateColorDifference(topColor, shoeColor) / sqrt(3.0))
                        
                        // Create mutable copies
                        var scoredTop = top
                        var scoredShoe = shoe
                        
                        // Set the similarity score as percentage
                        let similarityPercentage = round(similarity * 100)
                        scoredTop.score = similarityPercentage
                        scoredShoe.score = similarityPercentage
                        
                        topShoeCombinations.append((top: scoredTop, shoe: scoredShoe, similarity: similarity))
                    }
                }
                
                
                // Sort combinations by similarity (highest first)
                topShoeCombinations.sort { $0.similarity > $1.similarity }
                
                // Print sorted combinations
                for combination in topShoeCombinations {
                    print("Top-Shoe combination - Top: \(combination.top.brand), Shoe: \(combination.shoe.brand), Similarity: \(String(format: "%.1f", combination.similarity * 100))%")
                }
                
                // Store all combinations as complete outfits
                sortedOutfits = topShoeCombinations.compactMap { combination in
                    // Use locked bottom if exists, otherwise score bottoms for this combination
                    let availableBottoms = lockedBottom != nil ? [lockedBottom!] : bottoms
                    let scoredBottoms = availableBottoms.map { bottom -> (item: WardrobeItem, score: Double) in
                        var scoredItem = bottom
                        let bottomColor = normalizeRGBValues(bottom.rgbValues)
                        let topColor = normalizeRGBValues(combination.top.rgbValues)
                        let shoeColor = normalizeRGBValues(combination.shoe.rgbValues)
                        
                        let contrastWithTop = calculateColorDifference(topColor, bottomColor)
                        let contrastWithShoes = calculateColorDifference(shoeColor, bottomColor)
                        
                        let contrastScore = (contrastWithTop + contrastWithShoes) / (2.0 * sqrt(3.0))
                        scoredItem.score = round(contrastScore * 100)
                        
                        return (item: scoredItem, score: scoredItem.score)
                    }.sorted { $0.score > $1.score }
                    
                    // Create outfit with best matching bottom
                    guard let bestBottom = scoredBottoms.first?.item else { return nil }
                    
                    return GeneratedOutfit(
                        top: combination.top,
                        bottom: bestBottom,
                        shoes: combination.shoe,
                        topLocked: lockedTop != nil,
                        bottomLocked: lockedBottom != nil,
                        shoesLocked: lockedShoes != nil
                    )
                }
                
                // Start with the highest scoring combination that hasn't been saved
                for (index, outfit) in sortedOutfits.enumerated() {
                    if !outfitManager.isOutfitStored(outfit) {
                        currentOutfit = outfit
                        currentOutfitIndex = index
                        print("Starting with unsaved outfit at index: \(index)")
                        break
                    }
                }
                
                if currentOutfit == nil {
                    // If all combinations are saved, start with the highest scoring one
                    currentOutfit = sortedOutfits.first
                    currentOutfitIndex = 0
                    errorMessage = "All possible combinations have been saved! Here's the highest rated outfit."
                    showError = true
                    print("All combinations saved, showing best match")
                }
                
                // Store individual sorted items for reference
                if let bestMatch = topShoeCombinations.first {
                    sortedTops = topShoeCombinations.map { $0.top }
                    sortedShoes = topShoeCombinations.map { $0.shoe }
                    sortedBottoms = bottoms.sorted { b1, b2 in
                        let score1 = calculateBottomScore(bottom: b1, topShoe: (top: bestMatch.top, shoe: bestMatch.shoe))
                        let score2 = calculateBottomScore(bottom: b2, topShoe: (top: bestMatch.top, shoe: bestMatch.shoe))
                        return score1 > score2
                    }
                }
                
            } else {
                // Regular scoring for other styles
                let availableTops = lockedTop != nil ? [lockedTop!] : tops
                let availableBottoms = lockedBottom != nil ? [lockedBottom!] : bottoms
                let availableShoes = lockedShoes != nil ? [lockedShoes!] : shoes
                
                let scoredTops = availableTops.map { item -> (item: WardrobeItem, score: Double) in
                    var scoredItem = item
                    switch selectedStyle.id {
                    case 1: // Casual
                        (scoredItem, _, _) = scoreCasualOutfit(top: item, bottom: item, shoe: item, matrix: similarityMatrix)
                    case 2: // Streetwear
                        (scoredItem, _, _) = scoreStreetwearOutfit(top: item, bottom: item, shoe: item, matrix: similarityMatrix)
                    case 4: // Random
                        scoredItem.score = Double.random(in: 0...100)
                    default:
                        break
                    }
                    return (item: scoredItem, score: scoredItem.score)
                }
                
                let scoredBottoms = availableBottoms.map { item -> (item: WardrobeItem, score: Double) in
                    var scoredItem = item
                    switch selectedStyle.id {
                    case 1:
                        (_, scoredItem, _) = scoreCasualOutfit(top: item, bottom: item, shoe: item, matrix: similarityMatrix)
                    case 2:
                        (_, scoredItem, _) = scoreStreetwearOutfit(top: item, bottom: item, shoe: item, matrix: similarityMatrix)
                    case 4:
                        scoredItem.score = Double.random(in: 0...100)
                    default:
                        break
                    }
                    return (item: scoredItem, score: scoredItem.score)
                }
                
                let scoredShoes = availableShoes.map { item -> (item: WardrobeItem, score: Double) in
                    var scoredItem = item
                    switch selectedStyle.id {
                    case 1:
                        (_, _, scoredItem) = scoreCasualOutfit(top: item, bottom: item, shoe: item, matrix: similarityMatrix)
                    case 2:
                        (_, _, scoredItem) = scoreStreetwearOutfit(top: item, bottom: item, shoe: item, matrix: similarityMatrix)
                    case 4:
                        scoredItem.score = Double.random(in: 0...100)
                    default:
                        break
                    }
                    return (item: scoredItem, score: scoredItem.score)
                }
                
                sortedTops = scoredTops.sorted(by: { $0.score > $1.score }).map { $0.item }
                sortedBottoms = scoredBottoms.sorted(by: { $0.score > $1.score }).map { $0.item }
                sortedShoes = scoredShoes.sorted(by: { $0.score > $1.score }).map { $0.item }
                
                // Create a new outfit respecting locked items
                if let newOutfit = createNewOutfit() {
                    currentOutfit = GeneratedOutfit(
                        top: lockedTop ?? newOutfit.top,
                        bottom: lockedBottom ?? newOutfit.bottom,
                        shoes: lockedShoes ?? newOutfit.shoes,
                        topLocked: lockedTop != nil,
                        bottomLocked: lockedBottom != nil,
                        shoesLocked: lockedShoes != nil
                    )
                    print("Generated new unsaved outfit combination")
                } else {
                    // All possible combinations have been saved
                    currentOutfit = GeneratedOutfit(
                        top: sortedTops.first,
                        bottom: sortedBottoms.first,
                        shoes: sortedShoes.first,
                        topLocked: lockedTop != nil,
                        bottomLocked: lockedBottom != nil,
                        shoesLocked: lockedShoes != nil
                    )
                    errorMessage = "All possible combinations have been saved! Here's a previously saved outfit."
                    showError = true
                    print("All possible combinations have been saved")
                }
            }
            
            print("Generated \(sortedTops.count) tops, \(sortedBottoms.count) bottoms, \(sortedShoes.count) shoes")
        }
    
    // Add this function to OutfitView
    private func trackRejections() {
        guard let outfit = currentOutfit else { return }
        
        // Only track unlocked items
        var itemsToIncrement: [String] = []
        var itemsToCheck: [(item: WardrobeItem, type: String)] = []
        
        // Check each item that isn't locked
        if let top = outfit.top, !outfit.topLocked {
            itemsToIncrement.append(top.url)
            itemsToCheck.append((item: top, type: "top"))
        }
        
        if let bottom = outfit.bottom, !outfit.bottomLocked {
            itemsToIncrement.append(bottom.url)
            itemsToCheck.append((item: bottom, type: "bottom"))
        }
        
        if let shoes = outfit.shoes, !outfit.shoesLocked {
            itemsToIncrement.append(shoes.url)
            itemsToCheck.append((item: shoes, type: "shoes"))
        }
        
        // If we have items to track
        if !itemsToIncrement.isEmpty {
            Task {
                do {
                    // First check all items for rejection count = 2
                    for itemPair in itemsToCheck {
                        let rejectionCount = try await outfitManager.checkItemRejectionCount(for: itemPair.item.url)
                        
                        // If the count is currently 2, it will become 3 after incrementing
                        if rejectionCount == 2 {
                            await MainActor.run {
                                // Add to the queue
                                rejectedItemsQueue.append(itemPair)
                            }
                        }
                    }
                    
                    // Now increment all rejection counts
                    try await outfitManager.incrementRejectionCount(for: itemsToIncrement)
                    print("Successfully tracked rejections for \(itemsToIncrement.count) items")
                    
                    // Show the first rejected item modal if there are any
                    await MainActor.run {
                        showNextRejectionModal()
                    }
                    
                } catch {
                    print("Error tracking rejections: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func showNextRejectionModal() {
        if !rejectedItemsQueue.isEmpty {
            let next = rejectedItemsQueue.first!
            rejectedItem = next.item
            rejectedItemType = next.type
            showRejectionModal = true
        } else {
            // No more items to show, continue with next outfit
            showNextOutfit()
        }
    }
    
    private func checkAndShowRejectionModal(item: WardrobeItem, type: String) {
        Task {
            do {
                // Use the new method from OutfitManager
                let rejectionCount = try await outfitManager.checkItemRejectionCount(for: item.url)
                
                // If the count is currently 2, it will become 3 after incrementing
                if rejectionCount == 2 {
                    await MainActor.run {
                        // Set the rejected item and type for the modal
                        rejectedItem = item
                        rejectedItemType = type
                        showRejectionModal = true
                    }
                }
            } catch {
                print("Error checking rejection count: \(error.localizedDescription)")
            }
        }
    }

    private func deleteRejectedItem() {
        guard let item = rejectedItem else { return }
        
        Task {
            do {
                try await outfitManager.deleteItem(with: item.url)
                
                // Remove this item from the queue and show next
                await MainActor.run {
                    showSuccessMessage("Item removed from your wardrobe")
                    
                    // Remove first item from queue
                    if !rejectedItemsQueue.isEmpty {
                        rejectedItemsQueue.removeFirst()
                    }
                    
                    // Reset current modal
                    showRejectionModal = false
                    rejectedItem = nil
                    
                    // Show next item or continue
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showNextRejectionModal()
                    }
                }
            } catch {
                print("Error deleting item: \(error.localizedDescription)")
                
                await MainActor.run {
                    showRejectionModal = false
                    errorMessage = "Failed to delete item: \(error.localizedDescription)"
                    showError = true
                    
                    // Still remove from queue to avoid getting stuck
                    if !rejectedItemsQueue.isEmpty {
                        rejectedItemsQueue.removeFirst()
                    }
                    
                    // Show next item
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showNextRejectionModal()
                    }
                }
            }
        }
    }
    
    private func keepRejectedItem() {
        // Reset rejection counter for the kept item
        guard let item = rejectedItem else {
            // If no item, just remove from queue and show next
            if !rejectedItemsQueue.isEmpty {
                rejectedItemsQueue.removeFirst()
            }
            
            showRejectionModal = false
            rejectedItem = nil
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showNextRejectionModal()
            }
            return
        }
        
        Task {
            do {
                // Call the dedicated method to reset rejection count
                try await outfitManager.resetRejectionCountForItem(with: item.url)
                
                await MainActor.run {
                    showSuccessMessage("Item kept in your wardrobe")
                    
                    // Remove from queue and show next
                    if !rejectedItemsQueue.isEmpty {
                        rejectedItemsQueue.removeFirst()
                    }
                    
                    // Reset current modal
                    showRejectionModal = false
                    rejectedItem = nil
                    
                    // Show next item or continue
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showNextRejectionModal()
                    }
                }
            } catch {
                print("Error resetting rejection count: \(error.localizedDescription)")
                
                // Still continue with queue even if there was an error
                await MainActor.run {
                    if !rejectedItemsQueue.isEmpty {
                        rejectedItemsQueue.removeFirst()
                    }
                    
                    showRejectionModal = false
                    rejectedItem = nil
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showNextRejectionModal()
                    }
                }
            }
        }
    }
    
    private func donateItem() {
        if let url = URL(string: "https://donateclothes.uk/"){
            UIApplication.shared.open(url)
        }
    }
    
    private func calculateBottomScore(bottom: WardrobeItem, topShoe: (top: WardrobeItem, shoe: WardrobeItem)) -> Double {
        let bottomColor = normalizeRGBValues(bottom.rgbValues)
        let topColor = normalizeRGBValues(topShoe.top.rgbValues)
        let shoeColor = normalizeRGBValues(topShoe.shoe.rgbValues)
        
        let contrastWithTop = calculateColorDifference(topColor, bottomColor)
        let contrastWithShoes = calculateColorDifference(shoeColor, bottomColor)
        
        return (contrastWithTop + contrastWithShoes) / (2.0 * sqrt(3.0))
    }

    private func showNextOutfit() {
        // Keep track of locked items and their states
        let lockedTop = currentOutfit?.topLocked == true ? currentOutfit?.top : nil
        let lockedBottom = currentOutfit?.bottomLocked == true ? currentOutfit?.bottom : nil
        let lockedShoes = currentOutfit?.shoesLocked == true ? currentOutfit?.shoes : nil
        let currentLocks = (
            top: currentOutfit?.topLocked ?? false,
            bottom: currentOutfit?.bottomLocked ?? false,
            shoes: currentOutfit?.shoesLocked ?? false
        )
        
        print("\n=== Starting Outfit Generation ===")
        print("Currently locked items:")
        print("Top: \(currentLocks.top ? "locked" : "unlocked")")
        print("Bottom: \(currentLocks.bottom ? "locked" : "unlocked")")
        print("Shoes: \(currentLocks.shoes ? "locked" : "unlocked")\n")
        
        // If all items are locked, no need to generate
        if currentLocks.top && currentLocks.bottom && currentLocks.shoes {
            print("🔒 All items locked - no generation needed")
            return
        }
        
        if selectedStyle.id == 3 { // Sandwich style
            guard !sortedOutfits.isEmpty else { return }
            
            var found = false
            var attempts = 0
            let maxAttempts = sortedOutfits.count
            
            while !found && attempts < maxAttempts {
                currentOutfitIndex = (currentOutfitIndex + 1) % sortedOutfits.count
                let nextOutfit = sortedOutfits[currentOutfitIndex]
                
                let newOutfit = GeneratedOutfit(
                    top: lockedTop ?? nextOutfit.top,
                    bottom: lockedBottom ?? nextOutfit.bottom,
                    shoes: lockedShoes ?? nextOutfit.shoes,
                    topLocked: currentLocks.top,
                    bottomLocked: currentLocks.bottom,
                    shoesLocked: currentLocks.shoes
                )
                
                // Check if this outfit is already stored
                if !outfitManager.isOutfitStored(newOutfit) {
                    currentOutfit = newOutfit
                    found = true
                    print("✅ Found new sandwich combination on attempt \(attempts + 1)")
                    print("Top: \(newOutfit.top?.brand ?? "none")")
                    print("Bottom: \(newOutfit.bottom?.brand ?? "none")")
                    print("Shoes: \(newOutfit.shoes?.brand ?? "none")")
                } else {
                    print("Skipping stored sandwich combination")
                }
                
                attempts += 1
            }
            
            if !found {
                print("No unsaved combinations found, showing best match")
                errorMessage = "All possible combinations have been saved! Here's a previously saved outfit."
                showError = true
                
                // Show the highest scored combination as fallback
                if let bestOutfit = sortedOutfits.first {
                    currentOutfit = GeneratedOutfit(
                        top: lockedTop ?? bestOutfit.top,
                        bottom: lockedBottom ?? bestOutfit.bottom,
                        shoes: lockedShoes ?? bestOutfit.shoes,
                        topLocked: currentLocks.top,
                        bottomLocked: currentLocks.bottom,
                        shoesLocked: currentLocks.shoes
                    )
                }
            }
            
        } else { // Casual or Streetwear styles
            // Get current indices
            var currentTopIndex = sortedTops.firstIndex { $0.url == currentOutfit?.top?.url } ?? -1
            var currentBottomIndex = sortedBottoms.firstIndex { $0.url == currentOutfit?.bottom?.url } ?? -1
            var currentShoeIndex = sortedShoes.firstIndex { $0.url == currentOutfit?.shoes?.url } ?? -1
            
            // Keep track of attempts to avoid infinite loop
            var attempts = 0
            var foundNewOutfit = false
            let maxAttempts = sortedTops.count * sortedBottoms.count * sortedShoes.count
            
            while !foundNewOutfit && attempts < maxAttempts {
                // Increment indices for unlocked items
                if !currentLocks.top {
                    currentTopIndex = (currentTopIndex + 1) % sortedTops.count
                }
                if !currentLocks.bottom {
                    currentBottomIndex = (currentBottomIndex + 1) % sortedBottoms.count
                }
                if !currentLocks.shoes {
                    currentShoeIndex = (currentShoeIndex + 1) % sortedShoes.count
                }
                
                // Get next items, keeping locked items
                let nextTop = currentLocks.top ? lockedTop : (currentTopIndex >= 0 ? sortedTops[currentTopIndex] : sortedTops.first)
                let nextBottom = currentLocks.bottom ? lockedBottom : (currentBottomIndex >= 0 ? sortedBottoms[currentBottomIndex] : sortedBottoms.first)
                let nextShoes = currentLocks.shoes ? lockedShoes : (currentShoeIndex >= 0 ? sortedShoes[currentShoeIndex] : sortedShoes.first)
                
                // Create new outfit
                if let top = nextTop, let bottom = nextBottom, let shoes = nextShoes {
                    let newOutfit = GeneratedOutfit(
                        top: top,
                        bottom: bottom,
                        shoes: shoes,
                        topLocked: currentLocks.top,
                        bottomLocked: currentLocks.bottom,
                        shoesLocked: currentLocks.shoes
                    )
                    
                    // Check if this outfit is already stored
                    if !outfitManager.isOutfitStored(newOutfit) {
                        currentOutfit = newOutfit
                        foundNewOutfit = true
                        print("Generated new unique outfit combination")
                        print("Top: \(top.brand)")
                        print("Bottom: \(bottom.brand)")
                        print("Shoes: \(shoes.brand)")
                    } else {
                        print("Skipping stored outfit combination")
                    }
                }
                
                attempts += 1
            }
            
            if !foundNewOutfit {
                errorMessage = "All possible combinations have been saved! Here's a previously saved outfit."
                showError = true
                print("⚠️ All possible combinations have been tried")
                
                // Show the first available combination as fallback
                if let top = sortedTops.first,
                   let bottom = sortedBottoms.first,
                   let shoes = sortedShoes.first {
                    currentOutfit = GeneratedOutfit(
                        top: top,
                        bottom: bottom,
                        shoes: shoes,
                        topLocked: currentLocks.top,
                        bottomLocked: currentLocks.bottom,
                        shoesLocked: currentLocks.shoes
                    )
                }
            }
        }
        print("=== Outfit Generation Complete ===\n")
    }

    // Helper function for handling sandwich style next outfit
    private func handleSandwichStyleNext(
        lockedTop: WardrobeItem?,
        lockedBottom: WardrobeItem?,
        lockedShoes: WardrobeItem?,
        currentLocks: (top: Bool, bottom: Bool, shoes: Bool)
    ) {
        guard !sortedOutfits.isEmpty else { return }
        
        var found = false
        var attempts = 0
        let maxAttempts = sortedOutfits.count
        
        while !found && attempts < maxAttempts {
            currentOutfitIndex = (currentOutfitIndex + 1) % sortedOutfits.count
            let nextOutfit = sortedOutfits[currentOutfitIndex]
            
            let newOutfit = GeneratedOutfit(
                top: lockedTop ?? nextOutfit.top,
                bottom: lockedBottom ?? nextOutfit.bottom,
                shoes: lockedShoes ?? nextOutfit.shoes,
                topLocked: currentLocks.top,
                bottomLocked: currentLocks.bottom,
                shoesLocked: currentLocks.shoes
            )
            
            if !outfitManager.isOutfitStored(newOutfit) {
                currentOutfit = newOutfit
                found = true
                print("✅ Found new sandwich combination on attempt \(attempts + 1)")
            }
            
            attempts += 1
        }
        
        if !found {
            print("No unsaved combinations found, generating new outfits")
            generateOutfit()
            
            if let generatedOutfit = currentOutfit {
                currentOutfit = GeneratedOutfit(
                    top: lockedTop ?? generatedOutfit.top,
                    bottom: lockedBottom ?? generatedOutfit.bottom,
                    shoes: lockedShoes ?? generatedOutfit.shoes,
                    topLocked: currentLocks.top,
                    bottomLocked: currentLocks.bottom,
                    shoesLocked: currentLocks.shoes
                )
            }
        }
    }
    
    private func scoreCasualOutfit(top: WardrobeItem, bottom: WardrobeItem, shoe: WardrobeItem, matrix: SimilarityMatrix) -> (WardrobeItem, WardrobeItem, WardrobeItem) {
        var scoredTop = top
        var scoredBottom = bottom
        var scoredShoe = shoe
        
        let neutralTarget = RGBValues(
            red: Double(ColorRules.RGBRange.neutral.min.red + ColorRules.RGBRange.neutral.max.red) / 2,
            green: Double(ColorRules.RGBRange.neutral.min.green + ColorRules.RGBRange.neutral.max.green) / 2,
            blue: Double(ColorRules.RGBRange.neutral.min.blue + ColorRules.RGBRange.neutral.max.blue) / 2
        )
        
        // Score based on closeness to neutral target
        func scoreNeutrality(_ rgb: RGBValues) -> Double {
            let similarity = calculateRGBSimilarity(rgb1: rgb, targetRGB: neutralTarget)
            let maxDiff = sqrt(3.0 * pow(255.0, 2))  // Maximum possible RGB difference
            return (1.0 - (similarity / maxDiff)) * 100.0  // Convert to percentage
        }
        
        // Also consider grayscale factor (how close R, G, B are to each other)
        func scoreGrayscale(_ rgb: RGBValues) -> Double {
            let mean = (rgb.red + rgb.green + rgb.blue) / 3.0
            let rDiff = abs(rgb.red - mean)
            let gDiff = abs(rgb.green - mean)
            let bDiff = abs(rgb.blue - mean)
            let maxDiff = 255.0  // Maximum possible difference from mean
            return (1.0 - ((rDiff + gDiff + bDiff) / (3.0 * maxDiff))) * 100.0  // Convert to percentage
        }
        
        // Calculate scores
        let topNeutralScore = scoreNeutrality(top.rgbValues)
        let topGrayScore = scoreGrayscale(top.rgbValues)
        scoredTop.score = min(100.0, max(0.0, (topNeutralScore + topGrayScore) / 2.0))
        
        let bottomNeutralScore = scoreNeutrality(bottom.rgbValues)
        let bottomGrayScore = scoreGrayscale(bottom.rgbValues)
        scoredBottom.score = min(100.0, max(0.0, (bottomNeutralScore + bottomGrayScore) / 2.0))
        
        let shoeNeutralScore = scoreNeutrality(shoe.rgbValues)
        let shoeGrayScore = scoreGrayscale(shoe.rgbValues)
        scoredShoe.score = min(100.0, max(0.0, (shoeNeutralScore + shoeGrayScore) / 2.0))
        
        // Log the scores
        print("Casual Style Match Scores:")
        print("Top (\(top.brand)) - Neutral: \(String(format: "%.1f", topNeutralScore))%, Grayscale: \(String(format: "%.1f", topGrayScore))%, Final: \(String(format: "%.1f", scoredTop.score))%")
        print("Bottom (\(bottom.brand)) - Neutral: \(String(format: "%.1f", bottomNeutralScore))%, Grayscale: \(String(format: "%.1f", bottomGrayScore))%, Final: \(String(format: "%.1f", scoredBottom.score))%")
        print("Shoes (\(shoe.brand)) - Neutral: \(String(format: "%.1f", shoeNeutralScore))%, Grayscale: \(String(format: "%.1f", shoeGrayScore))%, Final: \(String(format: "%.1f", scoredShoe.score))%")
        
        // Calculate overall outfit score
        let overallScore = (scoredTop.score + scoredBottom.score + scoredShoe.score) / 3.0
        print("Overall Outfit Score: \(String(format: "%.1f", overallScore))%\n")
        
        return (scoredTop, scoredBottom, scoredShoe)
    }

    private func scoreStreetwearOutfit(top: WardrobeItem, bottom: WardrobeItem, shoe: WardrobeItem, matrix: SimilarityMatrix) -> (WardrobeItem, WardrobeItem, WardrobeItem) {
        var scoredTop = top
        var scoredBottom = bottom
        var scoredShoe = shoe
        
        // Score bright top
        let topIntensity = (top.rgbValues.red + top.rgbValues.green + top.rgbValues.blue) / 3.0
        let topBrightnessScore = min(100.0, (topIntensity / 255.0) * 100.0)
        
        // Score dark bottom and shoes
        let bottomIntensity = (bottom.rgbValues.red + bottom.rgbValues.green + bottom.rgbValues.blue) / 3.0
        let shoeIntensity = (shoe.rgbValues.red + shoe.rgbValues.green + shoe.rgbValues.blue) / 3.0
        
        // Calculate base darkness scores
        let bottomDarknessScore = (1.0 - (bottomIntensity / 255.0)) * 100.0
        let shoeDarknessScore = (1.0 - (shoeIntensity / 255.0)) * 100.0
        
        // Boost scores if within dark range
        let avgMaxDark = Double(ColorRules.RGBRange.dark.max.red +
                               ColorRules.RGBRange.dark.max.green +
                               ColorRules.RGBRange.dark.max.blue) / 3.0
        
        // Calculate final scores with potential boosts
        scoredTop.score = topBrightnessScore
        scoredBottom.score = bottomIntensity <= avgMaxDark ? min(100.0, bottomDarknessScore * 1.5) : bottomDarknessScore
        scoredShoe.score = shoeIntensity <= avgMaxDark ? min(100.0, shoeDarknessScore * 1.5) : shoeDarknessScore
        
        // Log the scores
        print("Streetwear Style Match Scores:")
        print("Top (\(top.brand)) - Brightness Score: \(String(format: "%.1f", topBrightnessScore))%")
        print("Bottom (\(bottom.brand)) - Darkness Score: \(String(format: "%.1f", bottomDarknessScore))%, Final: \(String(format: "%.1f", scoredBottom.score))%")
        print("Shoes (\(shoe.brand)) - Darkness Score: \(String(format: "%.1f", shoeDarknessScore))%, Final: \(String(format: "%.1f", scoredShoe.score))%")
        
        // Calculate overall outfit score
        let overallScore = (scoredTop.score + scoredBottom.score + scoredShoe.score) / 3.0
        print("Overall Outfit Score: \(String(format: "%.1f", overallScore))%\n")
        
        return (scoredTop, scoredBottom, scoredShoe)
    }

    private func scoreSandwichOutfit(top: WardrobeItem, bottom: WardrobeItem, shoe: WardrobeItem, matrix: SimilarityMatrix) -> (WardrobeItem, WardrobeItem, WardrobeItem) {
        var scoredTop = top
        var scoredBottom = bottom
        var scoredShoe = shoe
        
        // Calculate color similarity between top and shoes
        let topColor = normalizeRGBValues(top.rgbValues)
        let shoeColor = normalizeRGBValues(shoe.rgbValues)
        let bottomColor = normalizeRGBValues(bottom.rgbValues)
        
        // Calculate similarity score between top and shoes (0 = identical, 1 = completely different)
        let topShoeColorDiff = calculateColorDifference(topColor, shoeColor)
        
        // Calculate how different the bottom is from both top and shoes
        let bottomTopDiff = calculateColorDifference(bottomColor, topColor)
        let bottomShoeDiff = calculateColorDifference(bottomColor, shoeColor)
        
        // We want top and shoes to be as similar as possible (low difference)
        // Score is inverted so higher is better (100 = identical, 0 = completely different)
        let topShoeScore = (1.0 - (topShoeColorDiff / sqrt(3.0))) * 100.0
        
        // We want bottom to be different from both top and shoes
        // Take the average difference and normalize it to percentage
        let bottomDiffScore = ((bottomTopDiff + bottomShoeDiff) / (2.0 * sqrt(3.0))) * 100.0
        
        // Weight the scores - prioritize top/shoe matching more than bottom contrast
        scoredTop.score = min(100.0, max(0.0, topShoeScore))
        scoredShoe.score = min(100.0, max(0.0, topShoeScore))
        scoredBottom.score = min(100.0, max(0.0, bottomDiffScore * 0.8))  // Slightly lower weight for bottom contrast
        
        return (scoredTop, scoredBottom, scoredShoe)
    }
    
    private func calculateColorDifference(_ rgb1: RGBValues, _ rgb2: RGBValues) -> Double {
        let rDiff = rgb1.red - rgb2.red
        let gDiff = rgb1.green - rgb2.green
        let bDiff = rgb1.blue - rgb2.blue
        return sqrt(rDiff * rDiff + gDiff * gDiff + bDiff * bDiff)
    }

    private func normalizeRGBValues(_ rgb: RGBValues) -> RGBValues {
        return RGBValues(
            red: rgb.red / 255.0,
            green: rgb.green / 255.0,
            blue: rgb.blue / 255.0
        )
    }

    private func normalizeValue(_ value: Double) -> Double {
        return value / 255.0
    }
    
    private func calculateRGBSimilarity(rgb1: RGBValues, targetRGB: RGBValues) -> Double {
        let rDiff = rgb1.red - targetRGB.red
        let gDiff = rgb1.green - targetRGB.green
        let bDiff = rgb1.blue - targetRGB.blue
        return sqrt(rDiff * rDiff + gDiff * gDiff + bDiff * bDiff)
    }
    
    private func resetAllRejectionCounts() {
        isResettingCounts = true
        Task {
            do {
                try await outfitManager.resetRejectionCount()
                
                // Use MainActor for UI updates
                await MainActor.run {
                    isResettingCounts = false
                    showingResetModal = false
                    
                    // Show success message with a temporary overlay
                    showSuccessMessage("All rejection counts have been reset")
                }
            } catch {
                print("Error resetting rejection counts: \(error)")
                
                await MainActor.run {
                    isResettingCounts = false
                    showingResetModal = false
                    
                    // Show error
                    errorMessage = "Failed to reset rejection counts"
                    showError = true
                }
            }
        }
    }

    // Add this function to show temporary success messages
    private func showSuccessMessage(_ message: String) {
        withAnimation {
            successMessage = message
            showSuccessIndicator = true
        }
        
        // Hide after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showSuccessIndicator = false
            }
        }
    }
    
    @State private var isSaving = false
    
    // MARK: - View Body
    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Text("\(selectedStyle.title): Outfit")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: {
                        showingResetModal = true
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title2)
                            .foregroundColor(.primary)
                            .padding(8)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                if let outfit = currentOutfit {
                    OutfitDisplayView(
                        outfit: outfit,
                        onLockToggle: toggleLock
                    )
                }

                Spacer()

                HStack {
                    Button(action: {
                        trackRejections()
                        showNextOutfit()  // Show next complete outfit
                    }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.red)
                            .clipShape(Circle())
                            .shadow(radius: 5)
                    }
                    .padding(.leading, 40)

                    Spacer()

                    Button(action: {
                        showingSaveDialog = true
                    }) {
                        Image(systemName: "heart.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.green)
                            .clipShape(Circle())
                            .shadow(radius: 5)
                    }
                    .padding(.trailing, 40)
                }
                .padding(.bottom, 30)
            }

            .navigationDestination(isPresented: $navigateToFavourites) {
                FavouriteView()
            }
            .onAppear {
                loadStoredOutfits()
                generateOutfit()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }

            // ✅ Add semi-transparent background when modal is active
            if showingSaveDialog {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        if !isSaving{
                            showingSaveDialog = false
                        }
                    }

                SaveOutfitDialog(
                    isPresented: $showingSaveDialog,
                    outfitName: $outfitName,
                    isSaving: $isSaving,
                    currentOutfit: currentOutfit,
                    selectedStyle: selectedStyle,
                    onSave: {
                        navigateToFavourites = true
                    }
                )
                .zIndex(1) // Ensures it's above everything
            }
            
            if isSaving{
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                LoadingAlert(message: "Saving.....")
                    .zIndex(2)
            }
            
            // Success message indicator
            if showSuccessIndicator {
                VStack {
                    Spacer()
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(successMessage)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                    .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom))
                .zIndex(5)
            }
            
            if showRejectionModal, let rejectedItem = rejectedItem {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                    }
                    .zIndex(5)
                
                RejectionModal(
                    item: rejectedItem,
                    itemType: rejectedItemType,
                    onKeep: {
                        keepRejectedItem()
                    },
                    onDelete: {
                        deleteRejectedItem()
                    },
                    onDonate: {
                        donateItem()
                    }
                )
                .zIndex(6)
            }
            
            // Add reset modal
            if showingResetModal {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        if !isResettingCounts {
                            showingResetModal = false
                        }
                    }
                    .zIndex(3)
                
                VStack(spacing: 20) {
                    Text("Reset Rejection Counts")
                        .font(.headline)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    Text("Would you like to reset the rejection counts for all items? This action cannot be undone.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    HStack(spacing: 20) {
                        Button(action: {
                            showingResetModal = false
                        }) {
                            Text("Cancel")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 100)
                                .padding(.vertical, 12)
                                .background(Color.gray)
                                .cornerRadius(10)
                        }
                        
                        Button(action: {
                            resetAllRejectionCounts()
                        }) {
                            Group {
                                if isResettingCounts {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Reset")
                                }
                            }
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 100)
                            .padding(.vertical, 12)
                            .background(Color.red)
                            .cornerRadius(10)
                        }
                        .disabled(isResettingCounts)
                        .opacity(isResettingCounts ? 0.6 : 1)
                    }
                    .padding(.bottom)
                }
                .padding()
                .frame(width: 300)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(20)
                .shadow(radius: 10)
                .zIndex(4)
            }
        }
    }

    // MARK: - Supporting Views
    struct OutfitDisplayView: View {
        let outfit: OutfitView.GeneratedOutfit
        let onLockToggle: (String) -> Void
        
        var body: some View {
            VStack(spacing: 20) {
                if let top = outfit.top {
                    HStack(alignment: .top, spacing: 10) {
                        ItemView(
                            item: top,
                            title: "Top"
                        )
                        
                        Button(action: { onLockToggle("top") }) {
                            Image(systemName: outfit.topLocked ? "lock.fill" : "lock.open.fill")
                                .font(.title3)
                                .foregroundColor(outfit.topLocked ? .green : .red)
                                .transition(.scale)
                                .frame(width: 44, height: 44)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                } else {
                    Text("No top selected")
                        .foregroundColor(.red)
                }
                
                if let bottom = outfit.bottom {
                    HStack(alignment: .top, spacing: 10) {
                        ItemView(
                            item: bottom,
                            title: "Bottom"
                        )
                        
                        Button(action: { onLockToggle("bottom") }) {
                            Image(systemName: outfit.bottomLocked ? "lock.fill" : "lock.open.fill")
                                .font(.title3)
                                .foregroundColor(outfit.bottomLocked ? .green : .red)
                                .transition(.scale)
                                .frame(width: 44, height: 44)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                } else {
                    Text("No bottom selected")
                        .foregroundColor(.red)
                }
                
                if let shoes = outfit.shoes {
                    HStack(alignment: .top, spacing: 10) {
                        ItemView(
                            item: shoes,
                            title: "Shoes"
                        )
                        
                        Button(action: { onLockToggle("shoes") }) {
                            Image(systemName: outfit.shoesLocked ? "lock.fill" : "lock.open.fill")
                                .font(.title3)
                                .foregroundColor(outfit.shoesLocked ? .green : .red)
                                .transition(.scale)
                                .frame(width: 44, height: 44)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                } else {
                    Text("No shoes selected")
                        .foregroundColor(.red)
                }
            }
            .padding()
            .onAppear {
                print("OutfitDisplayView appeared")
                print("Has top: \(outfit.top != nil)")
                print("Has bottom: \(outfit.bottom != nil)")
                print("Has shoes: \(outfit.shoes != nil)")
            }
        }
    }

    struct ItemView: View {
        let item: OutfitView.WardrobeItem
        let title: String
        
        var body: some View {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                    .padding(.bottom, 4)
                
                HStack {
                    AsyncImage(url: URL(string: item.url)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .onAppear {
                                    print("\(title): Loading image...")
                                }
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 100, height: 100)
                                .cornerRadius(10)
                                .onAppear {
                                    print("\(title): Successfully loaded image")
                                }
                        case .failure(_):
                            Image(systemName: "photo")
                                .frame(width: 100, height: 100)
                                .onAppear {
                                    print("\(title): Failed to load image")
                                    if let url = URL(string: item.url) {
                                        print("URL was valid: \(url)")
                                    } else {
                                        print("Invalid URL: \(item.url)")
                                    }
                                }
                        @unknown default:
                            EmptyView()
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text(item.brand)
                            .font(.subheadline)
                        Text("Size: \(item.size)")
                            .font(.caption)
                        Text("Style Match: \(Int(item.score))%")
                            .font(.caption)
                            .foregroundColor(styleMatchColor(score: item.score))
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
        
        private func styleMatchColor(score: Double) -> Color {
            switch score {
            case 80...100: return .green    // Excellent match
            case 60..<80: return .blue      // Good match
            case 40..<60: return .yellow    // Fair match
            default: return .red            // Poor match
            }
        }
    }

    struct SaveOutfitDialog: View {
        @Binding var isPresented: Bool
        @Binding var outfitName: String
        @Binding var isSaving: Bool
        let currentOutfit: OutfitView.GeneratedOutfit?
        let selectedStyle: StyleOption
        let onSave: () -> Void
        @State private var showError = false
        @State private var errorMessage = ""
        @State private var isCheckingName = false
        @StateObject private var outfitManager = OutfitManager()
        
        var body: some View {
            ZStack {
                // Semi-transparent background overlay
                if isPresented {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            isPresented = false
                        }
                    
                    // Dialog content
                    VStack(spacing: 20) {
                        Text("Save Outfit")
                            .font(.headline)
                            .fontWeight(.bold)
                            .padding(.top)
                        
                        Text("Would you like to save this outfit?")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        TextField("Name outfit...", text: $outfitName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)
                            .disabled(isCheckingName)
                        
                        HStack(spacing: 20) {
                            Button(action: {
                                outfitName = ""
                                isPresented = false
                            }) {
                                Text("Cancel")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(width: 100)
                                    .padding(.vertical, 12)
                                    .background(Color.red)
                                    .cornerRadius(10)
                            }
                            
                            Button(action: {
                                Task {
                                    isCheckingName = true
                                    isSaving = true
                                    do {
                                        if let outfit = currentOutfit {
                                            try await outfitManager.saveOutfit(
                                                name: outfitName,
                                                style: selectedStyle.title,
                                                outfit: outfit
                                            )
                                            
                                            let newStoredOutfits = try await outfitManager.fetchStoredOutfits()
                                            await MainActor.run {
                                                outfitManager.storedOutfits = newStoredOutfits
                                                onSave()
                                                outfitName = ""
                                                isPresented = false
                                            }
                                        }
                                    } catch OutfitError.userNotAuthenticated {
                                        errorMessage = "Please login to save outfits"
                                        showError = true
                                    } catch OutfitError.nameAlreadyExists {
                                        errorMessage = "An outfit with this name already exists. Please enter a different one."
                                        showError = true
                                    } catch OutfitError.outfitAlreadyExists {
                                        errorMessage = "This outfit combination already exists in your wardrobe!"
                                        showError = true
                                    } catch {
                                        errorMessage = "Failed to save outfit: \(error.localizedDescription)"
                                        showError = true
                                    }
                                    isCheckingName = false
                                    isSaving = false
                                }
                            }) {
                                Group {
                                    if isCheckingName {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("Save")
                                    }
                                }
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 100)
                                .padding(.vertical, 12)
                                .background(Color.purple)
                                .cornerRadius(10)
                            }
                            .disabled(outfitName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCheckingName || isSaving)
                            .opacity((outfitName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCheckingName || isSaving) ? 0.6 : 1)
                        }
                        .padding(.bottom)
                    }
                    .frame(width: 300)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(20)
                    .shadow(radius: 10)
                    .alert("Error", isPresented: $showError) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text(errorMessage)
                    }
                }
            }
            .ignoresSafeArea()
        }
    }
}

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// Enhanced Color Rules System
struct ColorRules {
    // Define specific bright colors
    struct BrightColors {
        static let red = (red: 255, green: 0, blue: 0)
        static let green = (red: 0, green: 255, blue: 0)
        static let blue = (red: 0, green: 0, blue: 255)
        static let yellow = (red: 255, green: 255, blue: 0)
        static let cyan = (red: 0, green: 255, blue: 255)
        static let magenta = (red: 255, green: 0, blue: 255)
    }
    
    struct RGBRange {
        // Neutral colors for Casual style
        static let neutral = (
            min: (red: 100, green: 100, blue: 100), // grey
            max: (red: 200, green: 200, blue: 200) // light grey
        )
        
        // Dark colors for Streetwear bottoms/shoes
        static let dark = (
            min: (red: 0, green: 0, blue: 0),
            max: (red: 100, green: 100, blue: 100)
        )
    }
    
    // Threshold for color matching
    static let brightColorThreshold = 30
    
    // Check if a color is bright by comparing with predefined bright colors
    static func isBrightColor(_ rgb: (red: Int, green: Int, blue: Int)) -> Bool {
        let brightColors = [
            BrightColors.red,
            BrightColors.green,
            BrightColors.blue,
            BrightColors.yellow,
            BrightColors.cyan,
            BrightColors.magenta
        ]
        
        return brightColors.contains { brightColor in
            areSimilarColors(rgb, brightColor, threshold: brightColorThreshold)
        }
    }
    
    static func isWithinRange(_ rgb: (red: Int, green: Int, blue: Int),
                            min: (red: Int, green: Int, blue: Int),
                            max: (red: Int, green: Int, blue: Int)) -> Bool {
        return rgb.red >= min.red && rgb.red <= max.red &&
               rgb.green >= min.green && rgb.green <= max.green &&
               rgb.blue >= min.blue && rgb.blue <= max.blue
    }
    
    static func areSimilarColors(_ rgb1: (red: Int, green: Int, blue: Int),
                                _ rgb2: (red: Int, green: Int, blue: Int),
                                threshold: Int = 30) -> Bool {
        return abs(rgb1.red - rgb2.red) <= threshold &&
               abs(rgb1.green - rgb2.green) <= threshold &&
               abs(rgb1.blue - rgb2.blue) <= threshold
    }
}

// Helper function to analyze image colors
func analyzeImageColors(_ imageRGB: (red: Int, green: Int, blue: Int)) -> (isBright: Bool, matchedColor: String?) {
    if ColorRules.isBrightColor(imageRGB) {
        let brightColors: [(color: (red: Int, green: Int, blue: Int), name: String)] = [
            (ColorRules.BrightColors.red, "Red"),
            (ColorRules.BrightColors.green, "Green"),
            (ColorRules.BrightColors.blue, "Blue"),
            (ColorRules.BrightColors.yellow, "Yellow"),
            (ColorRules.BrightColors.cyan, "Cyan"),
            (ColorRules.BrightColors.magenta, "Magenta")
        ]
        
        for (color, name) in brightColors {
            if ColorRules.areSimilarColors(imageRGB, color, threshold: ColorRules.brightColorThreshold) {
                return (true, name)
            }
        }
        return (true, nil) // Bright but doesn't match a specific predefined color
    }
    return (false, nil)
}

struct WardrobeCount {
    var tops: Int = 0
    var bottoms: Int = 0
    var shoes: Int = 0
    
    var hasMinimumItems: Bool {
        return tops >= 3 && bottoms >= 3 && shoes >= 3
    }
}

struct StyleOption: Identifiable {
    let id: Int
    let title: String
    let description: String
    
    var colorRuleDescription: String {
        switch id {
        case 1:
            return "Neutral colors (RGB: 100-200) for all pieces"
        case 2:
            return "Bright top (Red, Green, Blue, Yellow, Cyan, or Magenta) with dark bottoms and shoes (RGB: 0-100)"
        case 3:
            return "Top and shoes must have similar RGB values (within 30 points)"
        case 4:
            return "No color restrictions"
        default:
            return ""
        }
    }
    
    func validateColors(tops: (red: Int, green: Int, blue: Int),
                       bottoms: (red: Int, green: Int, blue: Int),
                       shoes: (red: Int, green: Int, blue: Int)) -> Bool {
        switch id {
        case 1: // Casual
            return ColorRules.isWithinRange(tops, min: ColorRules.RGBRange.neutral.min, max: ColorRules.RGBRange.neutral.max) &&
                   ColorRules.isWithinRange(bottoms, min: ColorRules.RGBRange.neutral.min, max: ColorRules.RGBRange.neutral.max) &&
                   ColorRules.isWithinRange(shoes, min: ColorRules.RGBRange.neutral.min, max: ColorRules.RGBRange.neutral.max)
            
        case 2: // Streetwear
            return ColorRules.isBrightColor(tops) &&
                   ColorRules.isWithinRange(bottoms, min: ColorRules.RGBRange.dark.min, max: ColorRules.RGBRange.dark.max) &&
                   ColorRules.isWithinRange(shoes, min: ColorRules.RGBRange.dark.min, max: ColorRules.RGBRange.dark.max)
            
        case 3: // Sandwich method
            return ColorRules.areSimilarColors(tops, shoes)
            
        case 4: // Random
            return true
            
        default:
            return true
        }
    }
}

struct InsufficientWardrobeView: View {
    let missingItems: [String]
    @Binding var showAddClothes: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Insufficient Items")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("You need at least 3 items of each type to create an outfit. You're missing:")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            ForEach(missingItems, id: \.self) { item in
                Text("• \(item)")
                    .foregroundColor(.red)
            }
            
            Button(action: {
                showAddClothes = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Clothes")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(25)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(radius: 10)
    }
}

struct CreateView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedStyle: StyleOption?
    @State private var showModal = false
    @State private var navigateToOutfit = false
    @State private var showAddClothes = false
    @State private var wardrobeCount = WardrobeCount()
    @State private var isCheckingWardrobe = true
    @Environment(\.dismiss) var dismiss
    @State private var photoArray: [[String: Any]] = []
    
    let styleOptions = [
        StyleOption(id: 1, title: "Casual", description: "Everyday wear"),
        StyleOption(id: 2, title: "Streetwear", description: "Streetwear style"),
        StyleOption(id: 3, title: "Sandwich method", description: "Top and shoes are the same colour while the bottoms are different"),
        StyleOption(id: 4, title: "Random", description: "Completely Random!")
    ]
    
    var missingItems: [String] {
        var missing: [String] = []
        if wardrobeCount.tops < 3 { missing.append("Tops") }
        if wardrobeCount.bottoms < 3 { missing.append("Bottoms") }
        if wardrobeCount.shoes < 3 { missing.append("Shoes") }
        return missing
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isCheckingWardrobe {
                    ProgressView()
                } else if !wardrobeCount.hasMinimumItems {
                    InsufficientWardrobeView(
                        missingItems: missingItems,
                        showAddClothes: $showAddClothes
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Select the style you would like:")
                                .font(.title3)
                                .foregroundColor(colorScheme == .dark ? .white : .primary)
                                .padding(.horizontal)
                            
                            VStack(spacing: 16) {
                                ForEach(styleOptions) { style in
                                    StyleButton(style: style) {
                                        selectedStyle = style
                                        showModal = true
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                if showModal, let style = selectedStyle {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            showModal = false
                        }
                    
                    StyleConfirmationView(
                        style: style,
                        onConfirm: {
                            showModal = false
                            navigateToOutfits(with: style)
                        },
                        onCancel: {
                            showModal = false
                        }
                    )
                    .transition(.scale)
                    .animation(.easeInOut, value: showModal)
                }
            }
            .navigationBarItems(leading:
                HStack {
                    Image(systemName: "plus")
                        .foregroundColor(colorScheme == .dark ? .white : .purple)
                        .font(.system(size: 24))
                    
                    Text("Create Outfit")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : .purple)
                }
            )
            .navigationDestination(isPresented: $showAddClothes) {
                AddView()
            }
//            .navigationDestination(isPresented: $navigateToOutfit) {
//                if let style = selectedStyle {
//                    OutfitView(selectedStyle: style)
//                }
//            }
            .navigationDestination(isPresented: $navigateToOutfit) {
                if let style = selectedStyle {
                    OutfitView(selectedStyle: style, photoArray: photoArray)
                }
            }
            
            .onAppear {
                checkWardrobeItems()
            }
            .onChange(of: showAddClothes) { oldValue, newValue in
                if !newValue {
                    checkWardrobeItems()
                }
            }
        }
    }
    
    private func navigateToOutfits(with style: StyleOption) {
        print("Selected Style: \(style.title)")
        print("Color Rules: \(style.colorRuleDescription)")
        print("Style ID: \(style.id)")
        print("Photo Array Count: \(photoArray.count)") // Debug print
        selectedStyle = style
        navigateToOutfit = true
    }
    
    private func checkWardrobeItems() {
        isCheckingWardrobe = true
        let db = Firestore.firestore()
        guard let userId = Auth.auth().currentUser?.uid else {
            isCheckingWardrobe = false
            return
        }
        
        db.collection("users").document(userId).getDocument { (document, error) in
            if let error = error {
                print("Error getting document: \(error)")
                isCheckingWardrobe = false
                return
            }
            
            guard let document = document,
                  let photos = document.data()?["photoArray"] as? [[String: Any]] else {
                print("No photoArray found in document")
                isCheckingWardrobe = false
                return
            }
            
            // Set the photoArray
            self.photoArray = photos
            print("PhotoArray loaded with \(photos.count) items")
            
            // Reset counts
            wardrobeCount.tops = 0
            wardrobeCount.bottoms = 0
            wardrobeCount.shoes = 0
            
            // Count items by type
            for item in photos {
                if let type = item["type"] as? String {
                    switch type {
                    case "Tops":
                        wardrobeCount.tops += 1
                    case "Bottoms":
                        wardrobeCount.bottoms += 1
                    case "Shoes":
                        wardrobeCount.shoes += 1
                    default:
                        break
                    }
                }
            }
            
            print("Wardrobe counts - Tops: \(wardrobeCount.tops), Bottoms: \(wardrobeCount.bottoms), Shoes: \(wardrobeCount.shoes)")
            isCheckingWardrobe = false
        }
    }
}

struct StyleButton: View {
    let style: StyleOption
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "tshirt.fill")
                    .foregroundColor(.white)
                Text(style.title)
                    .foregroundColor(.white)
                    .font(.title3)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.purple)
            .cornerRadius(25)
        }
    }
}

struct StyleConfirmationView: View {
    let style: StyleOption
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 20) {
            Text(style.title)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.purple)
            
            VStack(spacing: 8) {
                Text(style.description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                
                Text(style.colorRuleDescription)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            .foregroundColor(colorScheme == .dark ? .white : .primary)
            
            HStack(spacing: 12) {
                Button(action: {
                    onCancel()
                }) {
                    VStack {
                        Image(systemName: "xmark")
                        Text("Cancel")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(25)
                }
                
                Button(action: {
                    onConfirm()
                }) {
                    VStack {
                        Image(systemName: "checkmark")
                        Text("Confirm")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(25)
                }
            }
        }
        .padding()
        .background(colorScheme == .dark ? Color(.systemGray6) : .white)
        .cornerRadius(20)
        .padding()
        .shadow(radius: 10)
    }
}


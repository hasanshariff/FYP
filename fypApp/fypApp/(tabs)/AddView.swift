////
////  AddView.swift
////  fypApp
////
////  Created by Hasan Shariff on 24/01/2025.
////

import SwiftUI

struct AddView: View {
    @StateObject private var viewModel = AddViewModel()
    @Environment(\.colorScheme) var colorScheme
    
    private let rules = [
        "Ensure good lighting for the best photo quality",
        "Place the item on a plain background",
        "Capture the entire item in the frame",
        "Avoid shadows or glare on the item"
    ]
    
    var body: some View {
        ZStack {
            Color(colorScheme == .dark ? .black : .white)
                .ignoresSafeArea()
            
            VStack {
                HeaderView()
                
                ScrollView {
                    VStack(spacing: 32) {
                        Spacer()
                        Text("Click on this button to add items to your wardrobe. You can add tshirts, bottoms or shoes.")
                            .font(.title2)
                            .multilineTextAlignment(.center)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .padding(.horizontal)
                        
                        Button(action: { viewModel.showRulesModal = true }) {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text("Add Items")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.purple)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                        Spacer()
                    }
                    .frame(minHeight: UIScreen.main.bounds.height - 200)
                }
            }
            
            if viewModel.showRulesModal {
                RulesModalView(rules: rules, viewModel: viewModel)
            }
        }
        .fullScreenCover(isPresented: $viewModel.showCamera) {
            CameraViewControllerRepresentable()
        }
    }
}

struct RulesModalView: View {
    let rules: [String]
    @ObservedObject var viewModel: AddViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack {
                VStack(spacing: 24) {
                    HStack {
                        Text("Guidelines")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.purple)
                        
                        Spacer()
                        
                        Button(action: { viewModel.showRulesModal = false }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.red)
                                .font(.title2)
                        }
                    }
                    
                    VStack(spacing: 16) {
                        ForEach(rules, id: \.self) { rule in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.purple)
                                
                                Text(rule)
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                
                                Spacer()
                            }
                        }
                    }
                    
                    Button(action: {
                        viewModel.proceedToNextScreen()
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(.trailing, 8)
                            } else {
                                Image(systemName: "arrow.right.circle")
                            }
                            Text(viewModel.isLoading ? "Opening Camera..." : "Continue")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.purple)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isLoading)
                }
                .padding()
                .background(colorScheme == .dark ? Color(.systemGray6) : .white)
                .cornerRadius(12)
                .padding()
            }
        }
    }
}

struct HeaderView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            Image(systemName: "plus.circle.fill")
                .foregroundColor(colorScheme == .dark ? .white : .purple)
                .font(.system(size: 24, weight: .bold))
            Text("Add Items")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white : .purple)
            Spacer()
        }
        .padding()
        .background(colorScheme == .dark ? Color.black : Color.white)
    }
}

class AddViewModel: ObservableObject {
    @Published var showRulesModal = false
    @Published var showCamera = false
    @Published var isLoading = false
    
    func proceedToNextScreen() {
        isLoading = true
        
        // Simulate a brief loading time for smooth transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showRulesModal = false
            self.showCamera = true
            self.isLoading = false
        }
    }
}

//
//  about.swift
//  fypApp
//
//  Created by Hasan Shariff on 31/01/2025.
//

import SwiftUI

struct AboutView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @ScaledMetric var fontSize: CGFloat = 16
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .center, spacing: 16) {
                    Text("""
                        This app has been developed for the final year project 2024/25. 
                        This app allows users to upload photos of their clothes and then a custom algorithm will create an outfit 
                        for them using computer vision and other aspects.
                        """)
                        .font(.system(size: fontSize))
                        .foregroundColor(colorScheme == .dark ? .white : Color(.systemGray))
                        .multilineTextAlignment(.center)
                        .lineSpacing(16)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("About")
                        .font(.title2.bold())
                        .foregroundColor(.purple)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack {
                            Image(systemName: "arrow.left")
                                .foregroundColor(colorScheme == .dark ? .white : .purple)
                        }
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .background(colorScheme == .dark ? Color(white: 0.1) : .white)
    }
}

// For SwiftUI previews
struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AboutView()
                .preferredColorScheme(.light)
            
            AboutView()
                .preferredColorScheme(.dark)
        }
    }
}

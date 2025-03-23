//
//  links.swift
//  fypApp
//
//  Created by Hasan Shariff on 31/01/2025.
//

import SwiftUI

struct LinksView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @ScaledMetric var fontSize: CGFloat = 16
    
    let links = [
        (title: "Information about Hoarding", url: "https://hoardingdisordersuk.org/"),
        (title: "Clothes Donation", url: "https://donateclothes.uk/")
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(links, id: \.title) { link in
                        LinkButton(
                            title: link.title,
                            url: link.url,
                            fontSize: fontSize
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.top)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Useful Links and Help")
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

struct LinkButton: View {
    let title: String
    let url: String
    let fontSize: CGFloat
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: {
            if let url = URL(string: url) {
                UIApplication.shared.open(url)
            }
        }) {
            Text(title)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .cornerRadius(8)
        }
    }
}

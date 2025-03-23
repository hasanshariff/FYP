////
////  photoDetails.swift
////  fypApp
////
////  Created by Hasan Shariff on 30/01/2025.
////
//
//import SwiftUI
//import FirebaseFirestore
//import FirebaseAuth
//
//struct photoDetailView: View {
//    let item: WardrobeItem
//    @Environment(\.colorScheme) var colorScheme
//    @Environment(\.dismiss) var dismiss
//    @State private var showingDeleteAlert = false
//    
//    func handleDelete() {
//        guard let user = Auth.auth().currentUser else { return }
//        
//        let db = Firestore.firestore()
//        let userRef = db.collection("users").document(user.uid)
//        
//        userRef.updateData([
//            "photoArray": FieldValue.arrayRemove([
//                [
//                    "url": item.url,
//                    "type": item.type,
//                    "timestamp": item.timestamp,
//                    "brand": item.brand,
//                    "name": item.name
//                ]
//            ])
//        ]) { error in
//            if let error = error {
//                print("Error deleting item: \(error)")
//            } else {
//                print("Item deleted successfully")
//                dismiss()
//            }
//        }
//    }
//    
//    var body: some View {
//        ScrollView {
//            VStack(spacing: 16) {
//                AsyncImage(url: URL(string: item.url)) { image in
//                    image
//                        .resizable()
//                        .aspectRatio(contentMode: .fit)
//                } placeholder: {
//                    ProgressView()
//                }
//                .frame(maxHeight: 400)
//                .clipShape(RoundedRectangle(cornerRadius: 12))
//                
//                VStack(alignment: .leading, spacing: 16) {
//                    DetailRow(label: "Name", value: item.name)
//                    DetailRow(label: "Brand", value: item.brand)
//                    DetailRow(label: "Type", value: item.type.capitalized)
//                }
//                .padding(.horizontal)
//                
//                Button(action: {
//                    showingDeleteAlert = true
//                }) {
//                    Text("Delete Item")
//                        .fontWeight(.semibold)
//                        .foregroundColor(.white)
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(Color.red)
//                        .cornerRadius(10)
//                }
//                .padding(.horizontal)
//                .padding(.top, 8)
//                
//                NavigationLink(destination: UsefulLinksView()) {
//                    Text("Useful Links and Help")
//                        .fontWeight(.semibold)
//                        .foregroundColor(.white)
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(Color.purple)
//                        .cornerRadius(10)
//                }
//                .padding(.horizontal)
//            }
//        }
//        .navigationBarTitleDisplayMode(.inline)
//        .navigationTitle("Item Details")
//        .toolbar {
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button(action: {
//                    showingDeleteAlert = true
//                }) {
//                    Image(systemName: "trash")
//                        .foregroundColor(.red)
//                }
//            }
//        }
//        .alert("Delete Item", isPresented: $showingDeleteAlert) {
//            Button("Cancel", role: .cancel) { }
//            Button("Delete", role: .destructive) {
//                handleDelete()
//            }
//        } message: {
//            Text("Are you sure you want to delete this item?")
//        }
//    }
//}
//
//struct DetailRow: View {
//    let label: String
//    let value: String
//    @Environment(\.colorScheme) var colorScheme
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 4) {
//            Text(label + ":")
//                .font(.headline)
//                .foregroundColor(colorScheme == .dark ? .white : .black)
//            
//            Text(value)
//                .font(.body)
//                .foregroundColor(colorScheme == .dark ? .gray : .gray)
//        }
//    }
//}
//
//// Placeholder for UsefulLinksView
//struct UsefulLinksView: View {
//    var body: some View {
//        Text("Useful Links and Help")
//            .navigationTitle("Useful Links")
//    }
//}

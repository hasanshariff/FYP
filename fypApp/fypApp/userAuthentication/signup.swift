//
//  signup.swift
//  fypApp
//
//  Created by Hasan Shariff on 27/01/2025.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

class SignUpViewModel: ObservableObject {
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var showPassword = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    private let db = Firestore.firestore()
    
    func signUp(completion: @escaping (Bool, String?) -> Void) {
        if firstName.isEmpty || lastName.isEmpty || email.isEmpty || password.isEmpty {
            errorMessage = "Please fill in all fields"
            showError = true
            completion(false, errorMessage)
            return
        }
        
        isLoading = true
        
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                    completion(false, self.errorMessage)
                }
                return
            }
            
            guard let user = result?.user else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "User creation failed"
                    self.showError = true
                    completion(false, self.errorMessage)
                }
                return
            }
            
            self.createUserDocument(user: user) { success, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    if !success {
                        self.errorMessage = error ?? "Unknown error occurred"
                        self.showError = true
                    }
                    completion(success, error)
                }
            }
        }
    }
    
    private func createUserDocument(user: User, completion: @escaping (Bool, String?) -> Void) {
        let userData: [String: Any] = [
            "firstName": firstName,
            "lastName": lastName,
            "email": email,
            "photos": "",
            "photoArray": [],
            "updatedAt": Date().ISO8601Format()
        ]
        
        db.collection("users").document(user.uid).setData(userData) { error in
            if let error = error {
                completion(false, "Account created but profile setup failed: \(error.localizedDescription)")
            } else {
                completion(true, nil)
            }
        }
    }
}

struct SignUpView: View {
    @StateObject private var viewModel = SignUpViewModel()
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @AppStorage("fontSize") var fontSize: Double = 16
    
    var isDark: Bool {
        colorScheme == .dark
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // First Name Input
                        HStack {
                            Image(systemName: "person")
                                .foregroundColor(isDark ? .white : .purple)
                            
                            TextField("First name", text: $viewModel.firstName)
                                .textInputAutocapitalization(.never)
                                .foregroundColor(isDark ? .white : .black)
                                .font(.system(size: fontSize))
                        }
                        .padding()
                        .background(isDark ? Color(.systemGray6) : Color(.systemGray5))
                        .cornerRadius(8)
                        
                        // Last Name Input
                        HStack {
                            Image(systemName: "person")
                                .foregroundColor(isDark ? .white : .purple)
                            
                            TextField("Last name", text: $viewModel.lastName)
                                .textInputAutocapitalization(.never)
                                .foregroundColor(isDark ? .white : .black)
                                .font(.system(size: fontSize))
                        }
                        .padding()
                        .background(isDark ? Color(.systemGray6) : Color(.systemGray5))
                        .cornerRadius(8)
                        
                        // Email Input
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundColor(isDark ? .white : .purple)
                            
                            TextField("Email", text: $viewModel.email)
                                .textInputAutocapitalization(.never)
                                .foregroundColor(isDark ? .white : .black)
                                .font(.system(size: fontSize))
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled(true)
                        }
                        .padding()
                        .background(isDark ? Color(.systemGray6) : Color(.systemGray5))
                        .cornerRadius(8)
                        
                        // Password Input
                        HStack {
                            Image(systemName: "lock")
                                .foregroundColor(isDark ? .white : .purple)
                            
                            if viewModel.showPassword {
                                TextField("Password", text: $viewModel.password)
                                    .textInputAutocapitalization(.never)
                            } else {
                                SecureField("Password", text: $viewModel.password)
                                    .textInputAutocapitalization(.never)
                            }
                            
                            Button(action: {
                                viewModel.showPassword.toggle()
                            }) {
                                Image(systemName: viewModel.showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(isDark ? .white : .purple)
                            }
                        }
                        .padding()
                        .background(isDark ? Color(.systemGray6) : Color(.systemGray5))
                        .cornerRadius(8)
                        
                        // Sign Up Button
                        Button(action: {
                            viewModel.signUp { success, error in
                                if success {
                                    dismiss()
                                }
                            }
                        }) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Sign Up")
                                    .font(.system(size: fontSize))
                                    .bold()
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding()
                        .background(Color.purple)
                        .cornerRadius(8)
                        .disabled(viewModel.isLoading)
                        .opacity(viewModel.isLoading ? 0.7 : 1)
                    }
                    .padding()
                }
            }
            .navigationTitle("Sign Up")
                    .navigationBarTitleDisplayMode(.large)
                    .navigationBarBackButtonHidden(true) // This hides the default back button
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: { dismiss() }) {
                                Image(systemName: "chevron.left")
                                    .foregroundColor(isDark ? .white : .purple)
                            }
                        }
                    }
            
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
    
    var backgroundColor: Color {
        isDark ? Color(.systemBackground) : .white
    }
}

#Preview {
    SignUpView()
}

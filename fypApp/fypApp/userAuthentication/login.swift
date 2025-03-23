////
////  login.swift
////  fypApp
////
////  Created by Hasan Shariff on 27/01/2025.
////

import SwiftUI
import FirebaseAuth

class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var showPassword = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    func signIn() {
        if email.isEmpty || password.isEmpty {
            errorMessage = "Please fill in all fields"
            showError = true
            return
        }
        
        isLoading = true
        
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                    print(error.localizedDescription)
                }
            }
        }
    }
}

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @Environment(\.colorScheme) var colorScheme
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
                                    .foregroundColor(isDark ? .white : .black)
                                    .font(.system(size: fontSize))
                            } else {
                                SecureField("Password", text: $viewModel.password)
                                    .textInputAutocapitalization(.never)
                                    .foregroundColor(isDark ? .white : .black)
                                    .font(.system(size: fontSize))
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
                        
                        // Login Button
                        Button(action: {
                            viewModel.signIn()
                        }) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Login")
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
                        
                        // Forgot Password
                        Button("Forgot Password?") {
                            // Handle forgot password
                        }
                        .foregroundColor(.purple)
                        .font(.system(size: fontSize))
                        
                        // Sign Up Link
                        HStack(spacing: 8) {
                            Text("Don't have an account?")
                                .foregroundColor(isDark ? .white : .black)
                                .font(.system(size: fontSize))
                            
                            NavigationLink(destination: SignUpView()) {
                                Text("Sign up")
                                    .foregroundColor(.purple)
                                    .bold()
                                    .font(.system(size: fontSize))
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                }
            }
            .navigationTitle("Login")
            .navigationBarTitleDisplayMode(.large)
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
    LoginView()
}

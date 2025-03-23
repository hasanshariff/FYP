//
//  ThemeChoice.swift
//  fypApp
//
//  Created by Hasan Shariff on 25/01/2025.
//

import SwiftUI

class AppThemeManager: ObservableObject {
    @Published var isDark: Bool {
        didSet {
            UserDefaults.standard.set(isDark, forKey: "isDarkMode")
        }
    }
    
    init(){
        self.isDark = UserDefaults.standard.bool(forKey: "isDarkMode")
    }
    
    func toggleDarkMode(){
        isDark.toggle()
    }
}

extension View {
    func applyTheme(_ themeManager: AppThemeManager) -> some View {
        self.preferredColorScheme(themeManager.isDark ? .dark : .light)
    }
}

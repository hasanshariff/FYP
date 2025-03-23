//
//  FontSize.swift
//  fypApp
//
//  Created by Hasan Shariff on 25/01/2025.
//

import SwiftUI

class FontSizeManager: ObservableObject {
    @Published var fontSize: CGFloat
    
    init() {
        let storedSize = UserDefaults.standard.double(forKey: "fontSize")
        self.fontSize = storedSize > 0 ? CGFloat(storedSize) : 16
    }
    
    func increaseFontSize() {
        fontSize = min(fontSize + 2, 24)
        UserDefaults.standard.set(Double(fontSize), forKey: "fontSize")
    }
    
    func decreaseFontSize() {
        fontSize = max(fontSize - 2, 12)
        UserDefaults.standard.set(Double(fontSize), forKey: "fontSize")
    }
    
    func resetFontSize() {
        fontSize = 16
        UserDefaults.standard.set(Double(fontSize), forKey: "fontSize")
    }
}

extension View {
    func dynamicFontSize(_ fontSizeManager: FontSizeManager) -> some View {
        self.font(.system(size: fontSizeManager.fontSize))
    }
}

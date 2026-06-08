import SwiftUI

// MARK: - TABI Design System

extension Color {
    // Brand colors extracted from TABI presentation
    static let tabiOrange      = Color(red: 0.91, green: 0.53, blue: 0.29)  // #E8874A — primary orange
    static let tabiOrangeLight = Color(red: 0.99, green: 0.93, blue: 0.87)  // warm tint
    static let tabiLavender    = Color(red: 0.69, green: 0.65, blue: 0.84)  // #B0A7D6 — active tab / accents
    static let tabiLavLight    = Color(red: 0.94, green: 0.93, blue: 0.97)  // light lavender bg
    static let tabiBlue        = Color(red: 0.24, green: 0.60, blue: 0.90)  // action blue
    static let tabiGreen       = Color(red: 0.27, green: 0.76, blue: 0.45)  // taken / positive
    static let tabiRed         = Color(red: 0.93, green: 0.27, blue: 0.27)  // missed
    static let tabiAmber       = Color(red: 0.97, green: 0.65, blue: 0.13)  // skipped / warning
    static let tabiGray        = Color(red: 0.56, green: 0.56, blue: 0.58)  // secondary text
    
    // Adaptive colors that work in both light and dark mode
    static let tabiCard = Color(light: .white, dark: Color(white: 0.15))
    static let tabiBG = Color(light: Color(red: 0.95, green: 0.95, blue: 0.97), dark: .black)
}

// Helper extension to support light/dark mode colors
extension Color {
    init(light: Color, dark: Color) {
        self.init(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }
}

// Pill card icon background colors (as shown in Today wireframe)
let pillColors: [Color] = [
    Color(red: 0.22, green: 0.38, blue: 0.62),  // blue-slate
    Color(red: 0.52, green: 0.38, blue: 0.72),  // purple
    Color(red: 0.94, green: 0.75, blue: 0.18),  // golden
    Color(red: 0.20, green: 0.52, blue: 0.55),  // teal
    Color(red: 0.91, green: 0.53, blue: 0.29),  // orange
]

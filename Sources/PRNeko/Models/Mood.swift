import Foundation

// Animation state for the pet - directly linked to mood
enum AnimationState: Equatable {
    case mood(Mood)

    var imageFileName: String {
        switch self {
        case .mood(let mood):
            return mood.imageFileName
        }
    }

    var isAnimated: Bool {
        switch self {
        case .mood(let mood):
            return mood.isAnimated
        }
    }

    var useFillMode: Bool {
        switch self {
        case .mood(let mood):
            return mood.useFillMode
        }
    }

    var imageScale: CGFloat {
        switch self {
        case .mood(let mood):
            return mood.imageScale
        }
    }
}

enum Mood: String, Codable, CaseIterable {
    case anxious
    case hungry
    case excited
    case idle

    var displayName: String {
        switch self {
        case .anxious: return "Anxious"
        case .hungry: return "Hungry"
        case .excited: return "Excited"
        case .idle: return "Idle"
        }
    }

    /// Icon shown in the popover header to indicate mood
    var iconName: String {
        switch self {
        case .anxious: return "exclamationmark.triangle.fill"
        case .hungry: return "fork.knife"
        case .excited: return "sparkles"
        case .idle: return "zzz"
        }
    }

    /// Cat emoji for menu bar - different expressions per mood
    var menuBarIcon: String {
        switch self {
        case .anxious: return "🙀"
        case .hungry: return "😿"
        case .excited: return "😸"
        case .idle: return "😺"
        }
    }

    var color: String {
        switch self {
        case .anxious: return "red"
        case .hungry: return "orange"
        case .excited: return "yellow"
        case .idle: return "gray"
        }
    }

    /// Image file name for this mood (without extension)
    var imageFileName: String {
        switch self {
        case .anxious: return "cat_anxious"
        case .hungry: return "cat_breathing"
        case .excited: return "cat_licking_transparent"
        case .idle: return "cat_laying_transparent"
        }
    }

    /// Whether this mood uses an animated GIF (true) or static PNG (false)
    var isAnimated: Bool {
        return true  // All moods now use animated GIFs
    }

    /// Whether to use fill mode (zoomed in) for images
    var useFillMode: Bool {
        switch self {
        case .anxious: return true   // Zoom in on anxious cat
        case .hungry: return true    // Zoom in on breathing cat
        case .excited: return true   // Zoom in on licking cat
        case .idle: return false     // Keep laying cat smaller/relaxed
        }
    }

    /// Scale factor for the image (1.0 = normal)
    var imageScale: CGFloat {
        switch self {
        case .idle: return 1.3       // Slightly larger but not full zoom
        default: return 1.0
        }
    }
}

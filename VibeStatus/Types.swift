// Types.swift
// VibeStatus
//
// Core domain types and enums used throughout the application.
// This file serves as the single source of truth for shared data structures.

import SwiftUI

// MARK: - Notification Names

extension Notification.Name {
    static let openLicenseSettings = Notification.Name("openLicenseSettings")
    static let switchSettingsTab = Notification.Name("switchSettingsTab")
}

// MARK: - Core Status Types

/// Represents the current operational state of a Claude Code session.
/// These states map directly to the hook events emitted by Claude Code.
enum VibeStatus: String, Codable, Equatable, CaseIterable {
    /// Claude is actively processing a request
    case working
    /// Claude has finished processing and is waiting for new input
    case idle
    /// Claude requires user input to continue (e.g., confirmation prompt)
    case needsInput = "needs_input"
    /// No active Claude session detected
    case notRunning = "not_running"

    /// Human-readable display name for UI
    var displayName: String {
        switch self {
        case .working: return "Working"
        case .idle: return "Ready"
        case .needsInput: return "Needs Input"
        case .notRunning: return "Not Running"
        }
    }
}

/// Raw status data as written by the Claude Code hook script.
/// This structure matches the JSON format written to /tmp/vibestatus-*.json
struct StatusData: Codable {
    let state: VibeStatus
    let message: String?
    let timestamp: Date?
    let project: String?
    let pid: Int?
}

/// Represents a single Claude Code session with its current state.
/// Multiple sessions can be active simultaneously (one per terminal).
struct SessionInfo: Equatable, Identifiable {
    let id: String
    let status: VibeStatus
    let project: String
    let timestamp: Date
}

// MARK: - Widget Configuration Types

/// Screen position options for the floating widget
enum WidgetPosition: String, CaseIterable {
    case bottomRight = "bottom_right"
    case bottomLeft = "bottom_left"
    case topRight = "top_right"
    case topLeft = "top_left"
    case notch = "notch"

    var displayName: String {
        switch self {
        case .bottomRight: return "Bottom Right"
        case .bottomLeft: return "Bottom Left"
        case .topRight: return "Top Right"
        case .topLeft: return "Top Left"
        case .notch: return "Notch (MacBook)"
        }
    }
}

/// Widget appearance theme options
enum WidgetTheme: String, CaseIterable {
    case dark = "dark"
    case light = "light"
    case auto = "auto"

    var displayName: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        case .auto: return "Auto (System)"
        }
    }
}

/// Widget display style variants
enum WidgetStyle: String, CaseIterable {
    case standard = "standard"
    case mini = "mini"
    case compact = "compact"

    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .mini: return "Mini (Dot)"
        case .compact: return "Compact"
        }
    }
}

/// Preset accent colors for the widget's "working" indicator
enum AccentColorPreset: String, CaseIterable {
    case orange = "orange"
    case blue = "blue"
    case green = "green"
    case purple = "purple"
    case pink = "pink"
    case red = "red"

    var displayName: String {
        rawValue.capitalized
    }

    var rgb: (red: Double, green: Double, blue: Double) {
        switch self {
        case .orange: return (0.757, 0.373, 0.235)
        case .blue: return (0.0, 0.478, 1.0)
        case .green: return (0.298, 0.686, 0.314)
        case .purple: return (0.608, 0.318, 0.878)
        case .pink: return (0.914, 0.118, 0.388)
        case .red: return (1.0, 0.231, 0.188)
        }
    }

    var color: Color {
        Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}

// MARK: - Settings Types

/// Available system sounds for notifications
enum NotificationSound: String, CaseIterable {
    case glass = "Glass"
    case purr = "Purr"
    case blow = "Blow"
    case bottle = "Bottle"
    case frog = "Frog"
    case funk = "Funk"
    case hero = "Hero"
    case morse = "Morse"
    case ping = "Ping"
    case pop = "Pop"
    case submarine = "Submarine"
    case tink = "Tink"
    case none = "None"

    var displayName: String {
        self == .none ? "No Sound" : rawValue
    }

    /// Play the system sound. Must be called on main thread.
    @MainActor
    func play() {
        guard self != .none else { return }
        NSSound(named: NSSound.Name(rawValue))?.play()
    }
}

/// Tabs available in the Settings window
enum SettingsTab: String, CaseIterable {
    case general = "General"
    case widget = "Widget"
    case sounds = "Sounds"
    case license = "License"
    case about = "About"

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .widget: return "square.on.square"
        case .sounds: return "speaker.wave.2"
        case .license: return "key.fill"
        case .about: return "info.circle"
        }
    }
}

// MARK: - License Types

/// License validation status
enum LicenseStatus: String, Codable {
    case valid = "valid"
    case invalid = "invalid"
    case expired = "expired"
    case revoked = "revoked"
    case notValidated = "not_validated"

    var displayName: String {
        switch self {
        case .valid: return "Licensed"
        case .invalid: return "Invalid License"
        case .expired: return "License Expired"
        case .revoked: return "License Revoked"
        case .notValidated: return "Not Licensed"
        }
    }

    var isActive: Bool {
        self == .valid
    }
}

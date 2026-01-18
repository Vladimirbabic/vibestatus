// Constants.swift
// VibeStatus
//
// Application-wide constants. Centralizing these values makes configuration
// easier to audit and modify, and prevents accidental inconsistencies.

import SwiftUI

// MARK: - Application Constants

enum AppConstants {
    /// The branded orange color used throughout the app (Claude's brand color)
    static let brandOrange = Color(red: 0.757, green: 0.373, blue: 0.235)
    static let brandOrangeNS = NSColor(red: 0.757, green: 0.373, blue: 0.235, alpha: 1.0)
}

// MARK: - Status File Constants

enum StatusFileConstants {
    /// Directory where Claude hook writes status files
    static let directory = "/tmp"

    /// Prefix for status files (full pattern: vibestatus-{session_id}.json)
    static let filePrefix = "vibestatus-"

    /// File extension for status files
    static let fileExtension = ".json"

    /// How long a session is considered valid without updates (5 minutes)
    static let sessionTimeoutSeconds: TimeInterval = 300

    /// How often to poll for status file changes (1 second)
    static let pollingIntervalSeconds: TimeInterval = 1.0
}

// MARK: - Widget Layout Constants

enum WidgetLayoutConstants {
    /// Margin from screen edge for widget positioning
    static let screenMargin: CGFloat = 20

    /// Offset from top edge for notch positioning
    static let notchTopOffset: CGFloat = 6

    /// Corner radius for standard widget
    static let cornerRadius: CGFloat = 12

    // MARK: Standard Style Dimensions

    enum Standard {
        static let width: CGFloat = 220
        static let singleSessionHeight: CGFloat = 70
        static let multiSessionBaseHeight: CGFloat = 46
        static let sessionRowHeight: CGFloat = 24
        static let maxVisibleSessions: Int = 5
    }

    // MARK: Compact Style Dimensions

    enum Compact {
        static let width: CGFloat = 140
        static let height: CGFloat = 28
    }

    // MARK: Mini Style Dimensions

    enum Mini {
        static let collapsedSize: CGFloat = 32
        static let dotSize: CGFloat = 14
    }
}

// MARK: - UserDefaults Keys

/// Type-safe UserDefaults keys to prevent typos and enable refactoring
enum UserDefaultsKey: String {
    // Sound settings
    case idleSound
    case needsInputSound

    // Widget settings
    case widgetEnabled
    case widgetAutoShow
    case widgetPosition
    case widgetStyle

    // Theme settings
    case widgetTheme
    case widgetOpacity
    case widgetAccentColor

    // License settings
    case licenseKey
    case licenseStatus
    case licenseValidatedAt
}

// MARK: - License Constants

enum LicenseConstants {
    /// Polar.sh API endpoint for license validation (no auth required for customer portal)
    static let validationURL = "https://api.polar.sh/v1/customer-portal/license-keys/validate"

    /// Your Polar.sh organization ID
    static let organizationId = "e443356b-577b-4c05-bba5-9ef851189b5e"

    /// Polar.sh checkout URL for purchasing a license
    static let checkoutURL = "https://buy.polar.sh/polar_cl_O6qwqlyebCVmHQ791YQv686eVlWzxxmGAc3Gc2JNYQa"

    /// How often to re-validate the license (24 hours)
    static let revalidationIntervalSeconds: TimeInterval = 86400
}

// MARK: - UI Constants

enum UIConstants {
    /// Animation spring response for widget hover effects
    static let hoverAnimationResponse: Double = 0.3

    /// Animation damping for widget hover effects
    static let hoverAnimationDamping: Double = 0.7

    /// Default widget background opacity
    static let defaultWidgetOpacity: Double = 0.85

    /// Minimum allowed widget opacity
    static let minWidgetOpacity: Double = 0.3

    /// Maximum allowed widget opacity
    static let maxWidgetOpacity: Double = 1.0

    /// Opacity slider step size
    static let opacitySliderStep: Double = 0.05
}

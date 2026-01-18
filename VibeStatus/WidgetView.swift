// WidgetView.swift
// VibeStatus
//
// SwiftUI views for the floating desktop widget.
// Provides three display styles:
// - Standard: Full widget with status text and project name
// - Compact: Single-line pill showing status
// - Mini: Dot that expands on hover
//
// All views are theme-aware and update reactively via WidgetThemeConfig.

import SwiftUI

// MARK: - Theme Configuration

/// Resolved theme values for widget rendering.
/// Created from user settings and system appearance.
struct WidgetThemeConfig {
    let backgroundColor: Color
    let textColor: Color
    let secondaryTextColor: Color
    let accentColor: Color
    let opacity: Double

    /// Create theme config from current settings
    @MainActor
    static func current() -> WidgetThemeConfig {
        let manager = SetupManager.shared
        let isDark = resolveIsDarkMode(manager.widgetTheme)
        let accent = resolveAccentColor(manager.widgetAccentColor)

        return WidgetThemeConfig(
            backgroundColor: isDark ? Color.black : Color.white,
            textColor: isDark ? Color.white.opacity(0.9) : Color.black.opacity(0.9),
            secondaryTextColor: isDark ? Color.white.opacity(0.5) : Color.black.opacity(0.5),
            accentColor: accent,
            opacity: manager.widgetOpacity
        )
    }

    private static func resolveIsDarkMode(_ theme: String) -> Bool {
        switch theme {
        case WidgetTheme.light.rawValue: return false
        case WidgetTheme.dark.rawValue: return true
        default:
            return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
    }

    private static func resolveAccentColor(_ colorName: String) -> Color {
        AccentColorPreset(rawValue: colorName)?.color ?? AccentColorPreset.orange.color
    }
}

// MARK: - Widget Data

/// Snapshot of widget display data
struct WidgetData {
    let status: VibeStatus
    let statusText: String
    let sessions: [SessionInfo]

    @MainActor
    static func from(_ manager: StatusManager) -> WidgetData {
        WidgetData(
            status: manager.currentStatus,
            statusText: manager.statusText,
            sessions: manager.sessions
        )
    }
}

// MARK: - Main Widget View

/// Routes to the appropriate style view based on settings
struct WidgetView: View {
    let data: WidgetData
    var style: WidgetStyle = .standard
    var theme: WidgetThemeConfig? = nil
    var isLicensed: Bool = true
    var onUnlicensedTap: (() -> Void)? = nil

    var body: some View {
        let currentTheme = theme ?? WidgetThemeConfig.current()

        if !isLicensed {
            UnlicensedWidgetView(theme: currentTheme, onTap: onUnlicensedTap)
        } else {
            switch style {
            case .standard:
                StandardWidgetView(data: data, theme: currentTheme)
            case .mini:
                MiniWidgetView(data: data, theme: currentTheme)
            case .compact:
                CompactWidgetView(data: data, theme: currentTheme)
            }
        }
    }
}

// MARK: - Unlicensed Widget View

/// Shows when no valid license is present
struct UnlicensedWidgetView: View {
    let theme: WidgetThemeConfig
    var onTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "key.fill")
                .font(.system(size: 24))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("License Required")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(theme.textColor)

                Text("Tap to activate")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(theme.secondaryTextColor)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(width: WidgetLayoutConstants.Standard.width, height: WidgetLayoutConstants.Standard.singleSessionHeight)
        .background(theme.backgroundColor.opacity(theme.opacity))
        .clipShape(RoundedRectangle(cornerRadius: WidgetLayoutConstants.cornerRadius))
        .onTapGesture {
            onTap?()
        }
    }
}

// MARK: - Standard Widget View

struct StandardWidgetView: View {
    let data: WidgetData
    let theme: WidgetThemeConfig

    var body: some View {
        VStack(spacing: 0) {
            WidgetHeader(theme: theme)

            if data.sessions.count <= 1 {
                SingleSessionView(data: data, theme: theme)
            } else {
                MultiSessionView(sessions: data.sessions, theme: theme)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.backgroundColor.opacity(theme.opacity))
        .clipShape(RoundedRectangle(cornerRadius: WidgetLayoutConstants.cornerRadius))
    }
}

// MARK: - Mini Widget View

/// Collapsed dot that expands on hover to show status
struct MiniWidgetView: View {
    let data: WidgetData
    let theme: WidgetThemeConfig
    @State private var isHovering = false

    var body: some View {
        ZStack {
            if isHovering {
                expandedView
            } else {
                collapsedView
            }
        }
        .animation(
            .spring(response: UIConstants.hoverAnimationResponse, dampingFraction: UIConstants.hoverAnimationDamping),
            value: isHovering
        )
        .onHover { isHovering = $0 }
    }

    private var expandedView: some View {
        HStack(spacing: 8) {
            statusDot

            VStack(alignment: .leading, spacing: 1) {
                Text(data.statusText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(theme.textColor)

                if let project = data.sessions.first?.project {
                    Text(project)
                        .font(.system(size: 9, weight: .regular, design: .rounded))
                        .foregroundColor(theme.secondaryTextColor)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.backgroundColor.opacity(theme.opacity))
        .clipShape(Capsule())
        .transition(.scale.combined(with: .opacity))
    }

    private var collapsedView: some View {
        statusDot
            .padding(6)
            .background(theme.backgroundColor.opacity(theme.opacity))
            .clipShape(Circle())
            .transition(.scale.combined(with: .opacity))
    }

    private var statusDot: some View {
        Circle()
            .fill(statusColor)
            .frame(width: WidgetLayoutConstants.Mini.dotSize, height: WidgetLayoutConstants.Mini.dotSize)
    }

    private var statusColor: Color {
        switch data.status {
        case .working: return theme.accentColor
        case .idle: return .green
        case .needsInput: return .blue
        case .notRunning: return .gray
        }
    }
}

// MARK: - Compact Widget View

/// Single-line pill showing status
struct CompactWidgetView: View {
    let data: WidgetData
    let theme: WidgetThemeConfig

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            Text(data.statusText)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(theme.textColor)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(theme.backgroundColor.opacity(theme.opacity))
        .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch data.status {
        case .working: return theme.accentColor
        case .idle: return .green
        case .needsInput: return .blue
        case .notRunning: return .gray
        }
    }
}

// MARK: - Widget Header

private struct WidgetHeader: View {
    let theme: WidgetThemeConfig

    var body: some View {
        HStack {
            Text("vibe status")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(theme.secondaryTextColor.opacity(0.7))

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }
}

// MARK: - Single Session View

struct SingleSessionView: View {
    let data: WidgetData
    let theme: WidgetThemeConfig

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(data.statusText)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(theme.textColor)

                if let project = data.sessions.first?.project,
                   !project.isEmpty,
                   data.status != .notRunning {
                    Text(project)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(theme.secondaryTextColor)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 88, alignment: .leading)

            Spacer()

            StatusIndicator(status: data.status, accentColor: theme.accentColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}

// MARK: - Multiple Sessions View

struct MultiSessionView: View {
    let sessions: [SessionInfo]
    let theme: WidgetThemeConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(sessions) { session in
                SessionRowView(session: session, theme: theme)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Session Row View

struct SessionRowView: View {
    let session: SessionInfo
    let theme: WidgetThemeConfig

    var body: some View {
        HStack(spacing: 11) {
            SmallStatusIndicator(status: session.status, accentColor: theme.accentColor)

            Text(session.project)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(theme.textColor.opacity(0.8))
                .lineLimit(1)

            Spacer()

            Text(statusLabel)
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundColor(theme.secondaryTextColor)
        }
    }

    private var statusLabel: String {
        switch session.status {
        case .working: return "working"
        case .idle: return "ready"
        case .needsInput: return "input"
        case .notRunning: return "offline"
        }
    }
}

// MARK: - Status Indicators

struct StatusIndicator: View {
    let status: VibeStatus
    let accentColor: Color

    var body: some View {
        switch status {
        case .working:
            HStack(spacing: 7) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(accentColor)
                        .frame(width: 9, height: 9)
                        .opacity(0.4 + Double(i) * 0.15)
                }
            }
        case .idle:
            statusRect(color: .green)
        case .needsInput:
            statusRect(color: .blue)
        case .notRunning:
            statusRect(color: .gray, opacity: 0.5)
        }
    }

    private func statusRect(color: Color, opacity: Double = 0.9) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(color.opacity(opacity))
            .frame(width: 11, height: 11)
    }
}

struct SmallStatusIndicator: View {
    let status: VibeStatus
    let accentColor: Color

    var body: some View {
        switch status {
        case .working:
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(accentColor)
                        .frame(width: 7, height: 7)
                        .opacity(0.5 + Double(i) * 0.25)
                }
            }
        case .idle:
            statusCircle(color: .green)
        case .needsInput:
            statusCircle(color: .blue)
        case .notRunning:
            statusCircle(color: .gray, opacity: 0.5)
        }
    }

    private func statusCircle(color: Color, opacity: Double = 0.9) -> some View {
        Circle()
            .fill(color.opacity(opacity))
            .frame(width: 9, height: 9)
    }
}

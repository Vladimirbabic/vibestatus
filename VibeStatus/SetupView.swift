// SetupView.swift
// VibeStatus
//
// Settings window UI for configuring the application.
// Uses a sidebar navigation pattern with four sections:
// - General: Integration setup and status guide
// - Widget: Floating widget configuration
// - Sounds: Notification sound preferences
// - About: App info and links

import SwiftUI

// MARK: - Main Setup View

struct SetupView: View {
    @State private var selectedTab: SettingsTab

    init(initialTab: SettingsTab = .general) {
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(selectedTab: $selectedTab)

            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                case .widget:
                    WidgetSettingsView()
                case .sounds:
                    SoundsSettingsView()
                case .license:
                    LicenseSettingsView()
                case .about:
                    AboutSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 650, height: 480)
        .onReceive(NotificationCenter.default.publisher(for: .switchSettingsTab)) { notification in
            if let tab = notification.object as? SettingsTab {
                selectedTab = tab
            }
        }
    }
}

// MARK: - Settings Sidebar

private struct SettingsSidebar: View {
    @Binding var selectedTab: SettingsTab

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    HStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .frame(width: 20)
                        Text(tab.rawValue)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(selectedTab == tab ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(12)
        .frame(width: 180)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @StateObject private var setupManager = SetupManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                IntegrationSection(setupManager: setupManager)
                StatusGuideSection()

                if setupManager.isConfigured {
                    RestartHint()
                }

                Spacer()
            }
            .padding(30)
        }
    }
}

private struct IntegrationSection: View {
    @ObservedObject var setupManager: SetupManager

    var body: some View {
        SettingsSection(title: "Integration") {
            if setupManager.isConfigured {
                ConfiguredView(setupManager: setupManager)
            } else {
                UnconfiguredView(setupManager: setupManager)
            }

            if let error = setupManager.setupError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
        }
    }
}

private struct ConfiguredView: View {
    @ObservedObject var setupManager: SetupManager

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 4) {
                Text("Integration Active")
                    .font(.headline)
                Text("Claude Code hooks are configured and running")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Remove") {
                try? setupManager.unconfigure()
            }
            .foregroundColor(.red)
        }
    }
}

private struct UnconfiguredView: View {
    @ObservedObject var setupManager: SetupManager

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text("Setup Required")
                    .font(.headline)
                Text("Configure hooks to show Claude's status")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                Task { await setupManager.configure() }
            }) {
                if setupManager.isSettingUp {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 80)
                } else {
                    Text("Configure")
                        .frame(width: 80)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppConstants.brandOrange)
            .disabled(setupManager.isSettingUp)
        }
    }
}

private struct StatusGuideSection: View {
    var body: some View {
        SettingsSection(title: "Status Indicators") {
            VStack(alignment: .leading, spacing: 14) {
                StatusRow(color: AppConstants.brandOrange, title: "Working", description: "Claude is processing your request")
                StatusRow(color: .green, title: "Ready", description: "Idle, waiting for next task")
                StatusRow(color: .blue, title: "Needs Input", description: "Claude needs your response")
                StatusRow(color: .gray, title: "Not Running", description: "No active Claude sessions")
            }
        }
    }
}

private struct RestartHint: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.clockwise.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.orange)
            Text("Restart Claude Code to activate hooks")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 8)
    }
}

// MARK: - Widget Settings

struct WidgetSettingsView: View {
    @StateObject private var setupManager = SetupManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                WidgetBasicSettings(setupManager: setupManager)
                WidgetAppearanceSettings(setupManager: setupManager)
                Spacer()
            }
            .padding(30)
        }
    }
}

private struct WidgetBasicSettings: View {
    @ObservedObject var setupManager: SetupManager

    var body: some View {
        SettingsSection(title: "Floating Widget") {
            Text("A floating widget that shows Claude's status on your desktop")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom, 8)

            VStack(spacing: 16) {
                SettingsToggle(
                    title: "Show Widget",
                    subtitle: "Display floating status widget on desktop",
                    isOn: $setupManager.widgetEnabled
                )

                Divider()

                SettingsToggle(
                    title: "Auto Show/Hide",
                    subtitle: "Automatically show when Claude is active, hide when idle",
                    isOn: $setupManager.widgetAutoShow
                )
                .disabled(!setupManager.widgetEnabled)
                .opacity(setupManager.widgetEnabled ? 1 : 0.5)

                Divider()

                SettingsPicker(
                    title: "Style",
                    subtitle: "Widget appearance style",
                    selection: $setupManager.widgetStyle,
                    options: WidgetStyle.allCases.map { ($0.rawValue, $0.displayName) }
                )
                .disabled(!setupManager.widgetEnabled)
                .opacity(setupManager.widgetEnabled ? 1 : 0.5)

                Divider()

                SettingsPicker(
                    title: "Position",
                    subtitle: "Where to display the widget",
                    selection: $setupManager.widgetPosition,
                    options: WidgetPosition.allCases.map { ($0.rawValue, $0.displayName) }
                )
                .disabled(!setupManager.widgetEnabled)
                .opacity(setupManager.widgetEnabled ? 1 : 0.5)
            }
        }
    }
}

private struct WidgetAppearanceSettings: View {
    @ObservedObject var setupManager: SetupManager

    var body: some View {
        SettingsSection(title: "Appearance") {
            VStack(spacing: 16) {
                SettingsPicker(
                    title: "Theme",
                    subtitle: "Widget color theme",
                    selection: $setupManager.widgetTheme,
                    options: WidgetTheme.allCases.map { ($0.rawValue, $0.displayName) }
                )
                .disabled(!setupManager.widgetEnabled)
                .opacity(setupManager.widgetEnabled ? 1 : 0.5)

                Divider()

                AccentColorPicker(setupManager: setupManager)
                    .disabled(!setupManager.widgetEnabled)
                    .opacity(setupManager.widgetEnabled ? 1 : 0.5)

                Divider()

                OpacitySlider(setupManager: setupManager)
                    .disabled(!setupManager.widgetEnabled)
                    .opacity(setupManager.widgetEnabled ? 1 : 0.5)
            }
        }
    }
}

private struct AccentColorPicker: View {
    @ObservedObject var setupManager: SetupManager

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Accent Color")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Color for 'working' status")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                ForEach(AccentColorPreset.allCases, id: \.rawValue) { preset in
                    Circle()
                        .fill(preset.color)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(Color.primary, lineWidth: setupManager.widgetAccentColor == preset.rawValue ? 2 : 0)
                        )
                        .onTapGesture {
                            setupManager.widgetAccentColor = preset.rawValue
                        }
                }
            }
        }
    }
}

private struct OpacitySlider: View {
    @ObservedObject var setupManager: SetupManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Opacity")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Widget background transparency")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(Int(setupManager.widgetOpacity * 100))%")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(width: 40)
            }

            Slider(
                value: $setupManager.widgetOpacity,
                in: UIConstants.minWidgetOpacity...UIConstants.maxWidgetOpacity,
                step: UIConstants.opacitySliderStep
            )
        }
    }
}

// MARK: - Sounds Settings

struct SoundsSettingsView: View {
    @StateObject private var setupManager = SetupManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsSection(title: "Notification Sounds") {
                    Text("Play sounds when Claude finishes a task or needs your input")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)

                    VStack(spacing: 16) {
                        SoundPickerRow(
                            title: "Task Complete",
                            subtitle: "When Claude finishes working",
                            selection: $setupManager.idleSound
                        )

                        Divider()

                        SoundPickerRow(
                            title: "Needs Input",
                            subtitle: "When Claude needs your response",
                            selection: $setupManager.needsInputSound
                        )
                    }
                }

                Spacer()
            }
            .padding(30)
        }
    }
}

// MARK: - License Settings

struct LicenseSettingsView: View {
    @StateObject private var licenseManager = LicenseManager.shared
    @State private var licenseKeyInput: String = ""
    @State private var showingKeyField: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                LicenseStatusSection(licenseManager: licenseManager, showingKeyField: $showingKeyField)

                if showingKeyField || !licenseManager.isLicensed {
                    LicenseKeyInputSection(
                        licenseManager: licenseManager,
                        licenseKeyInput: $licenseKeyInput,
                        showingKeyField: $showingKeyField
                    )
                }

                LicenseInfoSection()

                Spacer()
            }
            .padding(30)
        }
        .onAppear {
            licenseKeyInput = licenseManager.licenseKey
        }
    }
}

private struct LicenseStatusSection: View {
    @ObservedObject var licenseManager: LicenseManager
    @Binding var showingKeyField: Bool

    var body: some View {
        SettingsSection(title: "License Status") {
            HStack(spacing: 16) {
                Image(systemName: licenseManager.isLicensed ? "checkmark.seal.fill" : "key.slash")
                    .font(.system(size: 32))
                    .foregroundColor(licenseManager.isLicensed ? .green : .orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text(licenseManager.licenseStatus.displayName)
                        .font(.headline)

                    if licenseManager.isLicensed, let validatedAt = licenseManager.lastValidatedAt {
                        Text("Validated \(validatedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else if !licenseManager.isLicensed {
                        Text("Enter a license key to unlock all features")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if licenseManager.isLicensed {
                    VStack(spacing: 8) {
                        Button("Change Key") {
                            showingKeyField = true
                        }

                        Button("Remove") {
                            licenseManager.clearLicense()
                            showingKeyField = false
                        }
                        .foregroundColor(.red)
                    }
                }
            }

            if let error = licenseManager.validationError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
        }
    }
}

private struct LicenseKeyInputSection: View {
    @ObservedObject var licenseManager: LicenseManager
    @Binding var licenseKeyInput: String
    @Binding var showingKeyField: Bool

    var body: some View {
        SettingsSection(title: "Enter License Key") {
            VStack(alignment: .leading, spacing: 16) {
                Text("Paste your license key below to activate Vibe Status")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField("XXXX-XXXX-XXXX-XXXX", text: $licenseKeyInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                HStack {
                    Button(action: {
                        Task {
                            await licenseManager.validateLicense(key: licenseKeyInput)
                            if licenseManager.isLicensed {
                                showingKeyField = false
                            }
                        }
                    }) {
                        if licenseManager.isValidating {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 80)
                        } else {
                            Text("Activate")
                                .frame(width: 80)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppConstants.brandOrange)
                    .disabled(licenseManager.isValidating || licenseKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)

                    if licenseManager.isLicensed {
                        Button("Cancel") {
                            licenseKeyInput = licenseManager.licenseKey
                            showingKeyField = false
                        }
                    }
                }
            }
        }
    }
}

private struct LicenseInfoSection: View {
    var body: some View {
        SettingsSection(title: "Get a License") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Vibe Status is $4.99 for a lifetime license.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Link(destination: URL(string: LicenseConstants.checkoutURL)!) {
                    HStack {
                        Image(systemName: "cart")
                        Text("Purchase License")
                    }
                    .font(.subheadline)
                }
            }
        }
    }
}

// MARK: - About Settings

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)

            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 28, height: 28)
                    Text("Vibe Status")
                        .font(.system(size: 24, weight: .semibold))
                }

                Text("Version \(Bundle.main.appVersion)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text("A menu bar status indicator for Claude Code")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 12) {
                Link(destination: URL(string: "https://github.com/Vladimirbabic/vibestatus")!) {
                    HStack {
                        Image(systemName: "link")
                        Text("GitHub Repository")
                    }
                    .font(.subheadline)
                }

                Link(destination: URL(string: "https://github.com/Vladimirbabic/vibestatus/issues")!) {
                    HStack {
                        Image(systemName: "exclamationmark.bubble")
                        Text("Report an Issue")
                    }
                    .font(.subheadline)
                }
            }
            .padding(.top, 8)

            Spacer()

            Text("© 2025 Vladimir Babic")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Reusable Components

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
        }
    }
}

struct SettingsToggle: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .toggleStyle(.switch)
    }
}

struct SettingsPicker: View {
    let title: String
    let subtitle: String
    @Binding var selection: String
    let options: [(value: String, label: String)]

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Picker("", selection: $selection) {
                ForEach(options, id: \.value) { option in
                    Text(option.label).tag(option.value)
                }
            }
            .frame(width: 150)
        }
    }
}

struct StatusRow: View {
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct SoundPickerRow: View {
    let title: String
    let subtitle: String
    @Binding var selection: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Picker("", selection: $selection) {
                ForEach(NotificationSound.allCases, id: \.rawValue) { sound in
                    Text(sound.displayName).tag(sound.rawValue)
                }
            }
            .frame(width: 130)

            Button(action: {
                NotificationSound(rawValue: selection)?.play()
            }) {
                Image(systemName: "speaker.wave.2")
            }
            .buttonStyle(.borderless)
            .help("Test sound")
        }
    }
}

// MARK: - Bundle Extension

extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

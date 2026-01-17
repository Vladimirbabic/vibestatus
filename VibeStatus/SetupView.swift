import SwiftUI

enum SettingsTab: String, CaseIterable {
    case general = "General"
    case sounds = "Sounds"
    case about = "About"

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .sounds: return "speaker.wave.2"
        case .about: return "info.circle"
        }
    }
}

struct SetupView: View {
    @EnvironmentObject var setupManager: SetupManager
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab: SettingsTab = .general

    private let vibeOrange = Color(red: 0.757, green: 0.373, blue: 0.235)

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(SettingsTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            // Content
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView(setupManager: setupManager)
                case .sounds:
                    SoundsSettingsView(setupManager: setupManager)
                case .about:
                    AboutSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 650, height: 480)
    }
}

// MARK: - General Settings
struct GeneralSettingsView: View {
    @ObservedObject var setupManager: SetupManager
    private let vibeOrange = Color(red: 0.757, green: 0.373, blue: 0.235)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Integration Status
                SettingsSection(title: "Integration") {
                    if setupManager.isConfigured {
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
                    } else {
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
                                Task {
                                    await setupManager.configure()
                                }
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
                            .tint(vibeOrange)
                            .disabled(setupManager.isSettingUp)
                        }
                    }

                    if let error = setupManager.setupError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 8)
                    }
                }

                // Status Guide
                SettingsSection(title: "Status Indicators") {
                    VStack(alignment: .leading, spacing: 14) {
                        StatusRow(color: vibeOrange, title: "Working", description: "Claude is processing your request")
                        StatusRow(color: .green, title: "Ready", description: "Idle, waiting for next task")
                        StatusRow(color: .blue, title: "Needs Input", description: "Claude needs your response")
                        StatusRow(color: .gray, title: "Not Running", description: "No active Claude sessions")
                    }
                }

                if setupManager.isConfigured {
                    // Restart notice
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

                Spacer()
            }
            .padding(30)
        }
    }
}

// MARK: - Sounds Settings
struct SoundsSettingsView: View {
    @ObservedObject var setupManager: SetupManager

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

// MARK: - About Settings
struct AboutSettingsView: View {
    private let vibeOrange = Color(red: 0.757, green: 0.373, blue: 0.235)

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App Icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)

            // App Name & Version
            VStack(spacing: 6) {
                Text("Vibe Status")
                    .font(.system(size: 24, weight: .semibold))

                Text("Version \(Bundle.main.appVersion)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Description
            Text("A menu bar status indicator for Claude Code")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Links
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

            // Copyright
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
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

// MARK: - Preview
struct SetupView_Previews: PreviewProvider {
    static var previews: some View {
        SetupView()
            .environmentObject(SetupManager.shared)
    }
}

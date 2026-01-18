// SetupManager.swift
// VibeStatus
//
// Manages application configuration and Claude Code hook integration.
// Responsible for:
// - Persisting user preferences via UserDefaults
// - Installing/removing Claude Code hooks
// - Providing reactive settings via Combine
//
// Hook Integration:
// The app works by installing a shell script hook that Claude Code calls
// on status changes. This script writes JSON files to /tmp that StatusManager reads.

import Foundation
import AppKit
import Combine

/// Manages app configuration and Claude Code hook setup.
///
/// Use `SetupManager.shared` to access the singleton instance.
/// All properties are @Published for SwiftUI binding.
@MainActor
final class SetupManager: ObservableObject {
    static let shared = SetupManager()

    // MARK: - Published State

    /// Whether Claude Code hooks are configured
    @Published private(set) var isConfigured: Bool = false

    /// Error message from last setup attempt, if any
    @Published private(set) var setupError: String?

    /// Whether setup is currently in progress
    @Published private(set) var isSettingUp: Bool = false

    // MARK: - Sound Settings

    @Published var idleSound: String {
        didSet { UserDefaults.standard.set(idleSound, forKey: UserDefaultsKey.idleSound.rawValue) }
    }

    @Published var needsInputSound: String {
        didSet { UserDefaults.standard.set(needsInputSound, forKey: UserDefaultsKey.needsInputSound.rawValue) }
    }

    // MARK: - Widget Settings

    @Published var widgetEnabled: Bool {
        didSet { UserDefaults.standard.set(widgetEnabled, forKey: UserDefaultsKey.widgetEnabled.rawValue) }
    }

    @Published var widgetAutoShow: Bool {
        didSet { UserDefaults.standard.set(widgetAutoShow, forKey: UserDefaultsKey.widgetAutoShow.rawValue) }
    }

    @Published var widgetPosition: String {
        didSet { UserDefaults.standard.set(widgetPosition, forKey: UserDefaultsKey.widgetPosition.rawValue) }
    }

    @Published var widgetStyle: String {
        didSet { UserDefaults.standard.set(widgetStyle, forKey: UserDefaultsKey.widgetStyle.rawValue) }
    }

    // MARK: - Theme Settings

    @Published var widgetTheme: String {
        didSet { UserDefaults.standard.set(widgetTheme, forKey: UserDefaultsKey.widgetTheme.rawValue) }
    }

    @Published var widgetOpacity: Double {
        didSet { UserDefaults.standard.set(widgetOpacity, forKey: UserDefaultsKey.widgetOpacity.rawValue) }
    }

    @Published var widgetAccentColor: String {
        didSet { UserDefaults.standard.set(widgetAccentColor, forKey: UserDefaultsKey.widgetAccentColor.rawValue) }
    }

    // MARK: - Private Properties

    private nonisolated let claudeSettingsPath: String
    private nonisolated let hookScriptPath: String
    private nonisolated let hookScriptDir: String

    // MARK: - Initialization

    private init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        claudeSettingsPath = "\(homeDir)/.claude/settings.json"
        hookScriptDir = "\(homeDir)/.claude/hooks"
        hookScriptPath = "\(hookScriptDir)/vibestatus.sh"

        // Load persisted settings with defaults
        idleSound = UserDefaults.standard.string(forKey: UserDefaultsKey.idleSound.rawValue)
            ?? NotificationSound.glass.rawValue
        needsInputSound = UserDefaults.standard.string(forKey: UserDefaultsKey.needsInputSound.rawValue)
            ?? NotificationSound.purr.rawValue

        widgetEnabled = UserDefaults.standard.object(forKey: UserDefaultsKey.widgetEnabled.rawValue) as? Bool ?? true
        widgetAutoShow = UserDefaults.standard.object(forKey: UserDefaultsKey.widgetAutoShow.rawValue) as? Bool ?? true
        widgetPosition = UserDefaults.standard.string(forKey: UserDefaultsKey.widgetPosition.rawValue)
            ?? WidgetPosition.bottomRight.rawValue

        widgetTheme = UserDefaults.standard.string(forKey: UserDefaultsKey.widgetTheme.rawValue)
            ?? WidgetTheme.dark.rawValue
        widgetOpacity = UserDefaults.standard.object(forKey: UserDefaultsKey.widgetOpacity.rawValue) as? Double
            ?? UIConstants.defaultWidgetOpacity
        widgetAccentColor = UserDefaults.standard.string(forKey: UserDefaultsKey.widgetAccentColor.rawValue)
            ?? AccentColorPreset.orange.rawValue
        widgetStyle = UserDefaults.standard.string(forKey: UserDefaultsKey.widgetStyle.rawValue)
            ?? WidgetStyle.standard.rawValue

        checkIfConfigured()
    }

    // MARK: - Public API

    /// Check if Claude Code hooks are properly configured
    func checkIfConfigured() {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: hookScriptPath) else {
            isConfigured = false
            return
        }

        guard let settingsData = fileManager.contents(atPath: claudeSettingsPath),
              let settings = try? JSONSerialization.jsonObject(with: settingsData) as? [String: Any],
              let hooks = settings["hooks"] as? [String: Any],
              hooks["Stop"] != nil else {
            isConfigured = false
            return
        }

        isConfigured = true
    }

    /// Configure Claude Code hooks asynchronously
    func configure() async -> Bool {
        isSettingUp = true
        setupError = nil

        do {
            try await Task.detached(priority: .userInitiated) { [claudeSettingsPath, hookScriptPath, hookScriptDir] in
                try Self.createHookScript(at: hookScriptPath, in: hookScriptDir)
                try Self.updateClaudeSettings(at: claudeSettingsPath, hookScriptPath: hookScriptPath)
            }.value

            isConfigured = true
            isSettingUp = false
            return true
        } catch {
            setupError = error.localizedDescription
            isSettingUp = false
            return false
        }
    }

    /// Remove Claude Code hooks
    func unconfigure() throws {
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: hookScriptPath) {
            try fileManager.removeItem(atPath: hookScriptPath)
        }

        if let existingData = fileManager.contents(atPath: claudeSettingsPath),
           var settings = try? JSONSerialization.jsonObject(with: existingData) as? [String: Any],
           var hooks = settings["hooks"] as? [String: Any] {

            hooks.removeValue(forKey: "UserPromptSubmit")
            hooks.removeValue(forKey: "Stop")
            hooks.removeValue(forKey: "Notification")

            if hooks.isEmpty {
                settings.removeValue(forKey: "hooks")
            } else {
                settings["hooks"] = hooks
            }

            let jsonData = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
            try jsonData.write(to: URL(fileURLWithPath: claudeSettingsPath))
        }

        isConfigured = false
    }

    // MARK: - Hook Script Generation

    /// Creates the hook script that Claude Code will execute on status changes.
    /// This script writes session status to /tmp for StatusManager to read.
    private nonisolated static func createHookScript(at hookScriptPath: String, in hookScriptDir: String) throws {
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: hookScriptDir) {
            try fileManager.createDirectory(atPath: hookScriptDir, withIntermediateDirectories: true)
        }

        let scriptContent = """
        #!/bin/bash
        # VibeStatus Status Hook
        # This script is called by Claude Code hooks to update the VibeStatus widget
        # Supports multiple Claude sessions with project names

        TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

        # Read the hook event from stdin
        INPUT=$(cat)
        HOOK_EVENT=$(echo "$INPUT" | grep -o '"hook_event_name":"[^"]*"' | cut -d'"' -f4)

        # Extract session_id for multi-terminal support
        SESSION_ID=$(echo "$INPUT" | grep -o '"session_id":"[^"]*"' | cut -d'"' -f4)
        if [ -z "$SESSION_ID" ]; then
            # Fallback to script PID if no session_id
            SESSION_ID="$$"
        fi

        # Find the main Claude process - walk up the process tree
        # PPID is the immediate parent (usually a shell), so we look for the actual Claude process
        # Check for 'claude', 'Claude', or 'node' (when run via node directly)
        CLAUDE_PID=$PPID
        CURRENT_PID=$PPID
        for _ in 1 2 3 4 5 6 7 8; do
            PARENT_NAME=$(ps -p "$CURRENT_PID" -o comm= 2>/dev/null | xargs basename 2>/dev/null)
            PARENT_NAME_LOWER=$(echo "$PARENT_NAME" | tr '[:upper:]' '[:lower:]')
            if [ "$PARENT_NAME_LOWER" = "claude" ] || [ "$PARENT_NAME_LOWER" = "node" ]; then
                CLAUDE_PID=$CURRENT_PID
                break
            fi
            CURRENT_PID=$(ps -p "$CURRENT_PID" -o ppid= 2>/dev/null | tr -d ' ')
            [ -z "$CURRENT_PID" ] && break
        done

        # Extract working directory and get project name (last folder in path)
        WORKING_DIR=$(echo "$INPUT" | grep -o '"cwd":"[^"]*"' | cut -d'"' -f4)
        if [ -z "$WORKING_DIR" ]; then
            PROJECT_NAME="Unknown"
        else
            PROJECT_NAME=$(basename "$WORKING_DIR")
        fi

        STATUS_FILE="/tmp/vibestatus-${SESSION_ID}.json"

        case "$HOOK_EVENT" in
            "UserPromptSubmit")
                echo "{\\"state\\":\\"working\\",\\"project\\":\\"$PROJECT_NAME\\",\\"timestamp\\":\\"$TIMESTAMP\\",\\"pid\\":$CLAUDE_PID}" > "$STATUS_FILE"
                ;;
            "Stop")
                echo "{\\"state\\":\\"idle\\",\\"project\\":\\"$PROJECT_NAME\\",\\"timestamp\\":\\"$TIMESTAMP\\",\\"pid\\":$CLAUDE_PID}" > "$STATUS_FILE"
                ;;
            "Notification")
                # Check if it's an idle_prompt notification
                if echo "$INPUT" | grep -q "idle_prompt"; then
                    echo "{\\"state\\":\\"needs_input\\",\\"project\\":\\"$PROJECT_NAME\\",\\"timestamp\\":\\"$TIMESTAMP\\",\\"pid\\":$CLAUDE_PID}" > "$STATUS_FILE"
                fi
                ;;
        esac

        exit 0
        """

        try scriptContent.write(toFile: hookScriptPath, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hookScriptPath)
    }

    /// Updates Claude's settings.json to register our hooks
    private nonisolated static func updateClaudeSettings(at claudeSettingsPath: String, hookScriptPath: String) throws {
        let fileManager = FileManager.default

        let claudeDir = (claudeSettingsPath as NSString).deletingLastPathComponent
        if !fileManager.fileExists(atPath: claudeDir) {
            try fileManager.createDirectory(atPath: claudeDir, withIntermediateDirectories: true)
        }

        var settings: [String: Any] = [:]
        if let existingData = fileManager.contents(atPath: claudeSettingsPath),
           let existingSettings = try? JSONSerialization.jsonObject(with: existingData) as? [String: Any] {
            settings = existingSettings
        }

        var hooks = settings["hooks"] as? [String: Any] ?? [:]

        let hookConfig: [[String: Any]] = [
            [
                "hooks": [
                    [
                        "type": "command",
                        "command": hookScriptPath
                    ]
                ]
            ]
        ]

        hooks["UserPromptSubmit"] = hookConfig
        hooks["Stop"] = hookConfig

        hooks["Notification"] = [
            [
                "matcher": "idle_prompt",
                "hooks": [
                    [
                        "type": "command",
                        "command": hookScriptPath
                    ]
                ]
            ]
        ]

        settings["hooks"] = hooks

        let jsonData = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        try jsonData.write(to: URL(fileURLWithPath: claudeSettingsPath))
    }
}

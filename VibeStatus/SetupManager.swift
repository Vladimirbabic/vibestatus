import SwiftUI
import Foundation

class SetupManager: ObservableObject {
    static let shared = SetupManager()

    @Published var isConfigured: Bool = false
    @Published var setupError: String?
    @Published var isSettingUp: Bool = false

    private let claudeSettingsPath: String
    private let hookScriptPath: String
    private let hookScriptDir: String

    init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        claudeSettingsPath = "\(homeDir)/.claude/settings.json"
        hookScriptDir = "\(homeDir)/.claude/hooks"
        hookScriptPath = "\(hookScriptDir)/vibestatus.sh"

        checkIfConfigured()
    }

    func checkIfConfigured() {
        let fileManager = FileManager.default

        // Check if hook script exists
        guard fileManager.fileExists(atPath: hookScriptPath) else {
            isConfigured = false
            return
        }

        // Check if settings.json has our hooks configured
        guard let settingsData = fileManager.contents(atPath: claudeSettingsPath),
              let settings = try? JSONSerialization.jsonObject(with: settingsData) as? [String: Any],
              let hooks = settings["hooks"] as? [String: Any],
              hooks["Stop"] != nil else {
            isConfigured = false
            return
        }

        isConfigured = true
    }

    func configure() async -> Bool {
        await MainActor.run {
            isSettingUp = true
            setupError = nil
        }

        do {
            try await createHookScript()
            try await updateClaudeSettings()

            await MainActor.run {
                isConfigured = true
                isSettingUp = false
            }
            return true
        } catch {
            await MainActor.run {
                setupError = error.localizedDescription
                isSettingUp = false
            }
            return false
        }
    }

    private func createHookScript() async throws {
        let fileManager = FileManager.default

        // Create hooks directory if needed
        if !fileManager.fileExists(atPath: hookScriptDir) {
            try fileManager.createDirectory(atPath: hookScriptDir, withIntermediateDirectories: true)
        }

        let scriptContent = """
        #!/bin/bash
        # VibeStatus Status Hook
        # This script is called by Claude Code hooks to update the VibeStatus widget

        STATUS_FILE="/tmp/vibestatus-status.json"
        TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

        # Read the hook event from stdin
        INPUT=$(cat)
        HOOK_EVENT=$(echo "$INPUT" | grep -o '"hook_event_name":"[^"]*"' | cut -d'"' -f4)

        case "$HOOK_EVENT" in
            "UserPromptSubmit")
                echo "{\\"state\\":\\"working\\",\\"message\\":\\"Processing...\\",\\"timestamp\\":\\"$TIMESTAMP\\"}" > "$STATUS_FILE"
                ;;
            "Stop")
                echo "{\\"state\\":\\"idle\\",\\"message\\":\\"Ready\\",\\"timestamp\\":\\"$TIMESTAMP\\"}" > "$STATUS_FILE"
                ;;
            "Notification")
                # Check if it's an idle_prompt notification
                if echo "$INPUT" | grep -q "idle_prompt"; then
                    echo "{\\"state\\":\\"needs_input\\",\\"message\\":\\"Waiting for input\\",\\"timestamp\\":\\"$TIMESTAMP\\"}" > "$STATUS_FILE"
                fi
                ;;
        esac

        exit 0
        """

        try scriptContent.write(toFile: hookScriptPath, atomically: true, encoding: .utf8)

        // Make executable
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hookScriptPath)
    }

    private func updateClaudeSettings() async throws {
        let fileManager = FileManager.default

        // Create .claude directory if needed
        let claudeDir = (claudeSettingsPath as NSString).deletingLastPathComponent
        if !fileManager.fileExists(atPath: claudeDir) {
            try fileManager.createDirectory(atPath: claudeDir, withIntermediateDirectories: true)
        }

        // Read existing settings or create new
        var settings: [String: Any] = [:]
        if let existingData = fileManager.contents(atPath: claudeSettingsPath),
           let existingSettings = try? JSONSerialization.jsonObject(with: existingData) as? [String: Any] {
            settings = existingSettings
        }

        // Get or create hooks section
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

        // Add our hooks for each event
        hooks["UserPromptSubmit"] = hookConfig
        hooks["Stop"] = hookConfig

        // Add notification hook with matcher
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

        // Write back
        let jsonData = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        try jsonData.write(to: URL(fileURLWithPath: claudeSettingsPath))
    }

    func unconfigure() throws {
        let fileManager = FileManager.default

        // Remove hook script
        if fileManager.fileExists(atPath: hookScriptPath) {
            try fileManager.removeItem(atPath: hookScriptPath)
        }

        // Remove hooks from settings
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
}

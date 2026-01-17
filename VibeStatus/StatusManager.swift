// StatusManager.swift
// VibeStatus
//
// Responsible for monitoring Claude Code session status by polling status files
// written by the hook script. This is the single source of truth for session state.
//
// Architecture:
// - Hook script (vibestatus.sh) writes JSON to /tmp/vibestatus-{session_id}.json
// - StatusManager polls these files every second
// - State changes trigger sound notifications and UI updates via Combine
//
// Thread Safety:
// - All published properties are @MainActor isolated
// - File I/O runs on detached background tasks
// - State updates always happen on MainActor

import AppKit
import Combine

/// Monitors Claude Code sessions and aggregates their status.
///
/// Use `StatusManager.shared` to access the singleton instance.
/// Call `start()` to begin polling and `stop()` to halt polling.
@MainActor
final class StatusManager: ObservableObject {
    static let shared = StatusManager()

    // MARK: - Published State

    /// The aggregated status across all active sessions
    @Published private(set) var currentStatus: VibeStatus = .notRunning

    /// All currently active Claude sessions
    @Published private(set) var sessions: [SessionInfo] = []

    /// Human-readable status text for UI display
    var statusText: String {
        let count = sessions.count
        switch currentStatus {
        case .working:
            return count > 1 ? "Working (\(count))" : "Working..."
        case .idle:
            return count > 1 ? "Ready (\(count))" : "Ready"
        case .needsInput:
            return count > 1 ? "Input (\(count))" : "Input needed"
        case .notRunning:
            return "Run Claude"
        }
    }

    // MARK: - Private State

    private var pollingTask: Task<Void, Never>?
    private var previousSessionStatuses: [String: VibeStatus] = [:]

    private init() {}

    deinit {
        pollingTask?.cancel()
    }

    // MARK: - Public API

    /// Start polling for status updates. Safe to call multiple times.
    func start() {
        pollingTask?.cancel()

        pollingTask = Task { [weak self] in
            guard let self else { return }

            await self.update()

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(StatusFileConstants.pollingIntervalSeconds * 1_000_000_000))
                guard !Task.isCancelled else { break }
                await self.update()
            }
        }
    }

    /// Stop polling for status updates.
    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Private Methods

    private func update() async {
        let result = await Task.detached(priority: .utility) {
            Self.readStatusFiles()
        }.value

        processUpdate(result)
    }

    /// Reads all status files from disk. Runs on background thread.
    /// Returns parsed session data and error count for diagnostics.
    private nonisolated static func readStatusFiles() -> ParsedSessions {
        let fileManager = FileManager.default
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let files: [String]
        do {
            files = try fileManager.contentsOfDirectory(atPath: StatusFileConstants.directory)
        } catch {
            return ParsedSessions(sessions: [:], errorCount: 1)
        }

        let now = Date()
        var sessions: [String: ParsedSession] = [:]
        var errorCount = 0

        for file in files {
            guard file.hasPrefix(StatusFileConstants.filePrefix),
                  file.hasSuffix(StatusFileConstants.fileExtension) else {
                continue
            }

            let filePath = "\(StatusFileConstants.directory)/\(file)"
            let fileURL = URL(fileURLWithPath: filePath)

            do {
                let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
                guard !data.isEmpty else { continue }

                let status = try decoder.decode(StatusData.self, from: data)
                let timestamp = status.timestamp ?? now
                let project = status.project ?? "Unknown"

                // Check if process is still alive
                if let pid = status.pid, !isProcessRunning(pid: pid) {
                    try? fileManager.removeItem(atPath: filePath)
                    continue
                }

                // Check session timeout
                if now.timeIntervalSince(timestamp) < StatusFileConstants.sessionTimeoutSeconds {
                    sessions[file] = ParsedSession(status: status.state, project: project, timestamp: timestamp)
                } else {
                    try? fileManager.removeItem(atPath: filePath)
                }
            } catch {
                errorCount += 1
                #if DEBUG
                print("[StatusManager] Failed to decode \(file): \(error)")
                #endif
            }
        }

        return ParsedSessions(sessions: sessions, errorCount: errorCount)
    }

    /// Process parsed sessions and update published state.
    private func processUpdate(_ result: ParsedSessions) {
        // Determine sound triggers before updating state
        var shouldPlayIdleSound = false
        var shouldPlayNeedsInputSound = false

        for (sessionId, session) in result.sessions {
            let previous = previousSessionStatuses[sessionId]

            if previous == .working && session.status != .working {
                if session.status == .needsInput {
                    shouldPlayNeedsInputSound = true
                } else if session.status == .idle {
                    shouldPlayIdleSound = true
                }
            }
        }

        previousSessionStatuses = result.sessions.mapValues { $0.status }

        let newSessions = result.sessions.map { (id, data) in
            SessionInfo(id: id, status: data.status, project: data.project, timestamp: data.timestamp)
        }.sorted { $0.project < $1.project }

        let aggregatedStatus = Self.aggregateStatuses(result.sessions)

        // Only update if changed to minimize SwiftUI redraws
        if currentStatus != aggregatedStatus {
            currentStatus = aggregatedStatus
        }

        if sessions != newSessions {
            sessions = newSessions
        }

        // Play notification sounds
        if shouldPlayNeedsInputSound {
            playNotificationSound(for: .needsInput)
        } else if shouldPlayIdleSound {
            playNotificationSound(for: .idle)
        }
    }

    /// Determine the aggregate status from multiple sessions.
    /// Priority: needsInput > working > idle > notRunning
    private static func aggregateStatuses(_ sessions: [String: ParsedSession]) -> VibeStatus {
        guard !sessions.isEmpty else { return .notRunning }

        var hasWorking = false
        var hasIdle = false

        for session in sessions.values {
            switch session.status {
            case .needsInput:
                return .needsInput
            case .working:
                hasWorking = true
            case .idle:
                hasIdle = true
            case .notRunning:
                break
            }
        }

        if hasWorking { return .working }
        if hasIdle { return .idle }
        return .notRunning
    }

    private func playNotificationSound(for status: VibeStatus) {
        let soundName: String
        switch status {
        case .idle:
            soundName = SetupManager.shared.idleSound
        case .needsInput:
            soundName = SetupManager.shared.needsInputSound
        case .working, .notRunning:
            return
        }

        NotificationSound(rawValue: soundName)?.play()
    }

    /// Check if a process with the given PID is still running.
    private nonisolated static func isProcessRunning(pid: Int) -> Bool {
        kill(Int32(pid), 0) == 0
    }
}

// MARK: - Internal Types

private extension StatusManager {
    struct ParsedSession {
        let status: VibeStatus
        let project: String
        let timestamp: Date
    }

    struct ParsedSessions {
        let sessions: [String: ParsedSession]
        let errorCount: Int
    }
}

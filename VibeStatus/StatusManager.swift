import SwiftUI
import AppKit

enum VibeStatus: String, Codable {
    case working
    case idle
    case needsInput = "needs_input"
    case notRunning = "not_running"

    var borderColor: Color {
        switch self {
        case .working:
            return Color(red: 0.757, green: 0.373, blue: 0.235)
        case .idle:
            return .green
        case .needsInput:
            return .blue
        case .notRunning:
            return .gray
        }
    }
}

struct StatusData: Codable {
    let state: VibeStatus
    let message: String?
    let timestamp: Date?
    let project: String?
}

struct SessionInfo: Identifiable {
    let id: String
    let status: VibeStatus
    let project: String
    let timestamp: Date
}

class StatusManager: ObservableObject {
    static let shared = StatusManager()
    static let statusDirectory = "/tmp"
    static let statusFilePrefix = "vibestatus-"

    @Published var currentStatus: VibeStatus = .notRunning
    @Published var statusMessage: String?
    @Published var activeSessionCount: Int = 0
    @Published var sessions: [SessionInfo] = []

    private var timer: Timer?
    private var previousSessionStatuses: [String: VibeStatus] = [:]
    private let sessionTimeout: TimeInterval = 300

    var statusText: String {
        let count = activeSessionCount
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

    init() {
        // Single timer that does everything
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.update()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)

        // Initial update
        DispatchQueue.main.async { [weak self] in
            self?.update()
        }
    }

    private func update() {
        let fileManager = FileManager.default
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let files = try? fileManager.contentsOfDirectory(atPath: Self.statusDirectory) else {
            return
        }

        let now = Date()
        var updatedSessions: [String: (status: VibeStatus, project: String, timestamp: Date)] = [:]

        for file in files where file.hasPrefix(Self.statusFilePrefix) && file.hasSuffix(".json") {
            let filePath = "\(Self.statusDirectory)/\(file)"

            guard let data = fileManager.contents(atPath: filePath),
                  let status = try? decoder.decode(StatusData.self, from: data) else {
                continue
            }

            let sessionId = file
            let timestamp = status.timestamp ?? now
            let project = status.project ?? "Unknown"

            if now.timeIntervalSince(timestamp) < sessionTimeout {
                updatedSessions[sessionId] = (status.state, project, timestamp)
            } else {
                try? fileManager.removeItem(atPath: filePath)
            }
        }

        // Check for sounds
        var shouldPlayIdleSound = false
        var shouldPlayNeedsInputSound = false

        for (sessionId, sessionData) in updatedSessions {
            let currentSessionStatus = sessionData.status
            let previousSessionStatus = previousSessionStatuses[sessionId]

            if previousSessionStatus == .working && currentSessionStatus != .working {
                if currentSessionStatus == .needsInput {
                    shouldPlayNeedsInputSound = true
                } else if currentSessionStatus == .idle {
                    shouldPlayIdleSound = true
                }
            }
        }

        previousSessionStatuses = updatedSessions.mapValues { $0.status }

        let newSessions = updatedSessions.map { (id, data) in
            SessionInfo(id: id, status: data.status, project: data.project, timestamp: data.timestamp)
        }.sorted { $0.project < $1.project }

        let aggregatedStatus = aggregateStatuses(updatedSessions)

        // Update published properties
        self.activeSessionCount = updatedSessions.count
        self.currentStatus = aggregatedStatus
        self.sessions = newSessions

        // Play sounds
        if shouldPlayNeedsInputSound {
            playNotificationSound(for: .needsInput)
        } else if shouldPlayIdleSound {
            playNotificationSound(for: .idle)
        }
    }

    private func aggregateStatuses(_ sessions: [String: (status: VibeStatus, project: String, timestamp: Date)]) -> VibeStatus {
        if sessions.isEmpty {
            return .notRunning
        }

        var hasWorking = false
        var hasIdle = false

        for (_, session) in sessions {
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

        if let sound = NotificationSound(rawValue: soundName) {
            sound.play()
        }
    }
}

import SwiftUI
import Combine
import AppKit

enum VibeStatus: String, Codable {
    case working
    case idle
    case needsInput = "needs_input"
    case notRunning = "not_running"

    var borderColor: Color {
        switch self {
        case .working:
            return Color(red: 0.757, green: 0.373, blue: 0.235) // #C15F3C
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

    enum CodingKeys: String, CodingKey {
        case state, message, timestamp, project
    }

    init(state: VibeStatus, message: String? = nil, timestamp: Date? = nil, project: String? = nil) {
        self.state = state
        self.message = message
        self.timestamp = timestamp
        self.project = project
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        state = try container.decode(VibeStatus.self, forKey: .state)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp)
        project = try container.decodeIfPresent(String.self, forKey: .project)
    }
}

// Session info for widget display
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

    // Use MainActor to ensure thread safety
    @Published var currentStatus: VibeStatus = .notRunning
    @Published var statusMessage: String?
    @Published var activeSessionCount: Int = 0
    @Published var sessions: [SessionInfo] = []

    private var fileMonitor: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var pollTimer: Timer?

    // Track individual session statuses
    private var sessionStatuses: [String: (status: VibeStatus, project: String, timestamp: Date)] = [:]
    private var previousSessionStatuses: [String: VibeStatus] = [:] // Track previous status for each session
    private let sessionTimeout: TimeInterval = 300 // Consider session dead after 5 minutes of no updates

    // Debounce to prevent rapid updates
    private var pendingUpdate: DispatchWorkItem?
    private let debounceInterval: TimeInterval = 0.1

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
        startFileMonitoring()
        startPolling()
        startClaudeDetection()
    }

    deinit {
        stopFileMonitoring()
        pollTimer?.invalidate()
        claudeDetectionTimer?.invalidate()
        pendingUpdate?.cancel()
    }

    private var claudeDetectionTimer: Timer?

    private func startPolling() {
        // Poll every 0.5 seconds as a backup in case file monitoring misses changes
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                self?.readAllStatusFiles()
            }
            if let timer = self.pollTimer {
                RunLoop.main.add(timer, forMode: .common)
            }
        }
    }

    private func startClaudeDetection() {
        // Check every 2 seconds if Claude is running
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.claudeDetectionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                self?.checkClaudeRunning()
            }
            if let timer = self.claudeDetectionTimer {
                RunLoop.main.add(timer, forMode: .common)
            }
            // Initial check
            self.checkClaudeRunning()
        }
    }

    private func checkClaudeRunning() {
        let isRunning = isClaudeProcessRunning()

        if !isRunning && self.activeSessionCount == 0 && self.currentStatus != .notRunning {
            self.currentStatus = .notRunning
        } else if isRunning && self.currentStatus == .notRunning {
            // Claude started, read all status files to get actual state
            self.readAllStatusFiles()
        }
    }

    private func isClaudeProcessRunning() -> Bool {
        let task = Process()
        task.launchPath = "/usr/bin/pgrep"
        task.arguments = ["-f", "claude"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func startFileMonitoring() {
        // Monitor the /tmp directory for vibestatus files
        fileDescriptor = open(Self.statusDirectory, O_RDONLY)

        guard fileDescriptor != -1 else {
            print("Failed to open status directory for monitoring")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.startFileMonitoring()
            }
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write],
            queue: DispatchQueue.main
        )

        source.setEventHandler { [weak self] in
            self?.readAllStatusFiles()
        }

        source.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd != -1 {
                close(fd)
            }
        }

        source.resume()
        fileMonitor = source

        // Initial read
        readAllStatusFiles()
    }

    private func stopFileMonitoring() {
        fileMonitor?.cancel()
        fileMonitor = nil
    }

    private func readAllStatusFiles() {
        // Cancel any pending update
        pendingUpdate?.cancel()

        // Debounce updates to prevent rapid state changes
        let workItem = DispatchWorkItem { [weak self] in
            self?.performStatusUpdate()
        }
        pendingUpdate = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
    }

    private func performStatusUpdate() {
        let fileManager = FileManager.default
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let files = try? fileManager.contentsOfDirectory(atPath: Self.statusDirectory) else {
            return
        }

        let now = Date()
        var updatedSessions: [String: (status: VibeStatus, project: String, timestamp: Date)] = [:]

        // Read all vibestatus files
        for file in files where file.hasPrefix(Self.statusFilePrefix) && file.hasSuffix(".json") {
            let filePath = "\(Self.statusDirectory)/\(file)"

            guard let data = fileManager.contents(atPath: filePath),
                  let status = try? decoder.decode(StatusData.self, from: data) else {
                continue
            }

            let sessionId = file
            let timestamp = status.timestamp ?? now
            let project = status.project ?? "Unknown"

            // Only include sessions that have been updated recently
            if now.timeIntervalSince(timestamp) < sessionTimeout {
                updatedSessions[sessionId] = (status.state, project, timestamp)
            } else {
                // Clean up old session files
                try? fileManager.removeItem(atPath: filePath)
            }
        }

        // Check for individual session transitions (working -> idle/needsInput)
        var shouldPlayIdleSound = false
        var shouldPlayNeedsInputSound = false

        for (sessionId, sessionData) in updatedSessions {
            let currentSessionStatus = sessionData.status
            let previousSessionStatus = previousSessionStatuses[sessionId]

            // If this session was working and now finished
            if previousSessionStatus == .working && currentSessionStatus != .working {
                if currentSessionStatus == .needsInput {
                    shouldPlayNeedsInputSound = true
                } else if currentSessionStatus == .idle {
                    shouldPlayIdleSound = true
                }
            }
        }

        // Update previous session statuses for next comparison
        previousSessionStatuses = updatedSessions.mapValues { $0.status }

        // Update session tracking
        sessionStatuses = updatedSessions

        // Convert to SessionInfo array sorted by project name
        let newSessions = updatedSessions.map { (id, data) in
            SessionInfo(id: id, status: data.status, project: data.project, timestamp: data.timestamp)
        }.sorted { $0.project < $1.project }

        // Aggregate status (priority: needsInput > working > idle)
        let aggregatedStatus = aggregateStatuses(updatedSessions)

        // Update state without animation to prevent crashes
        self.activeSessionCount = updatedSessions.count
        self.currentStatus = aggregatedStatus
        self.sessions = newSessions

        // Play sound when any individual session finishes (needsInput has priority)
        if shouldPlayNeedsInputSound {
            self.playNotificationSound(for: .needsInput)
        } else if shouldPlayIdleSound {
            self.playNotificationSound(for: .idle)
        }
    }

    private func aggregateStatuses(_ sessions: [String: (status: VibeStatus, project: String, timestamp: Date)]) -> VibeStatus {
        if sessions.isEmpty {
            return .notRunning
        }

        // Priority: needsInput > working > idle
        var hasWorking = false
        var hasIdle = false

        for (_, session) in sessions {
            switch session.status {
            case .needsInput:
                return .needsInput // Highest priority
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
            return  // No sound when starting work or not running
        }

        if let sound = NotificationSound(rawValue: soundName) {
            sound.play()
        }
    }

    // For previews
    static func preview(status: VibeStatus) -> StatusManager {
        let manager = StatusManager()
        manager.currentStatus = status
        return manager
    }

    // For previews with multiple sessions
    static func previewMultiSession() -> StatusManager {
        let manager = StatusManager()
        manager.currentStatus = .working
        manager.activeSessionCount = 3
        manager.sessions = [
            SessionInfo(id: "1", status: .working, project: "MyApp", timestamp: Date()),
            SessionInfo(id: "2", status: .idle, project: "Backend", timestamp: Date()),
            SessionInfo(id: "3", status: .needsInput, project: "Frontend", timestamp: Date())
        ]
        return manager
    }
}

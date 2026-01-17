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

    enum CodingKeys: String, CodingKey {
        case state, message, timestamp
    }

    init(state: VibeStatus, message: String? = nil, timestamp: Date? = nil) {
        self.state = state
        self.message = message
        self.timestamp = timestamp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        state = try container.decode(VibeStatus.self, forKey: .state)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp)
    }
}

class StatusManager: ObservableObject {
    static let shared = StatusManager()
    static let statusDirectory = "/tmp"
    static let statusFilePrefix = "vibestatus-"

    @Published var currentStatus: VibeStatus = .idle
    @Published var statusMessage: String?
    @Published var pulseScale: CGFloat = 1.0
    @Published var activeSessionCount: Int = 0

    private var fileMonitor: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var pulseTimer: Timer?
    private var pollTimer: Timer?

    // Track individual session statuses
    private var sessionStatuses: [String: (status: VibeStatus, timestamp: Date)] = [:]
    private let sessionTimeout: TimeInterval = 30 // Consider session dead after 30s of no updates

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
        createStatusFileIfNeeded()
        startFileMonitoring()
        startPulseAnimation()
        startPolling()
        startClaudeDetection()
    }

    deinit {
        stopFileMonitoring()
        pulseTimer?.invalidate()
        pollTimer?.invalidate()
        claudeDetectionTimer?.invalidate()
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

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if !isRunning && self.activeSessionCount == 0 && self.currentStatus != .notRunning {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.currentStatus = .notRunning
                }
            } else if isRunning && self.currentStatus == .notRunning {
                // Claude started, read all status files to get actual state
                self.readAllStatusFiles()
            }
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

    private func createStatusFileIfNeeded() {
        // No longer needed for multi-session support
        // Each session creates its own file
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
        let fileManager = FileManager.default
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let files = try? fileManager.contentsOfDirectory(atPath: Self.statusDirectory) else {
            return
        }

        let now = Date()
        var updatedSessions: [String: (status: VibeStatus, timestamp: Date)] = [:]

        // Read all vibestatus files
        for file in files where file.hasPrefix(Self.statusFilePrefix) && file.hasSuffix(".json") {
            let filePath = "\(Self.statusDirectory)/\(file)"

            guard let data = fileManager.contents(atPath: filePath),
                  let status = try? decoder.decode(StatusData.self, from: data) else {
                continue
            }

            let sessionId = file
            let timestamp = status.timestamp ?? now

            // Only include sessions that have been updated recently
            if now.timeIntervalSince(timestamp) < sessionTimeout {
                updatedSessions[sessionId] = (status.state, timestamp)
            } else {
                // Clean up old session files
                try? fileManager.removeItem(atPath: filePath)
            }
        }

        // Update session tracking
        sessionStatuses = updatedSessions

        // Aggregate status (priority: needsInput > working > idle)
        let aggregatedStatus = aggregateStatuses(updatedSessions)
        let previousStatus = currentStatus

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            withAnimation(.easeInOut(duration: 0.3)) {
                self.activeSessionCount = updatedSessions.count
                self.currentStatus = aggregatedStatus
            }

            // Play sound when any session transitions from working to idle or needsInput
            if previousStatus == .working && aggregatedStatus != .working {
                self.playNotificationSound(for: aggregatedStatus)
            }
        }
    }

    private func aggregateStatuses(_ sessions: [String: (status: VibeStatus, timestamp: Date)]) -> VibeStatus {
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

    private func startPulseAnimation() {
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self = self, self.currentStatus == .needsInput else { return }
            withAnimation(.easeOut(duration: 1.5)) {
                self.pulseScale = 2.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.pulseScale = 1.0
            }
        }
    }

    // For previews
    static func preview(status: VibeStatus) -> StatusManager {
        let manager = StatusManager()
        manager.currentStatus = status
        return manager
    }
}

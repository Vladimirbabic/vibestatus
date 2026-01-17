import SwiftUI
import Combine
import AppKit

enum VibeStatus: String, Codable {
    case working
    case idle
    case needsInput = "needs_input"

    var borderColor: Color {
        switch self {
        case .working:
            return Color(red: 0.757, green: 0.373, blue: 0.235) // #C15F3C
        case .idle:
            return .green
        case .needsInput:
            return .blue
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
    static let statusFilePath = "/tmp/vibestatus-status.json"
    @Published var currentStatus: VibeStatus = .idle
    @Published var statusMessage: String?
    @Published var pulseScale: CGFloat = 1.0

    private var fileMonitor: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var pulseTimer: Timer?
    private var pollTimer: Timer?

    var statusText: String {
        switch currentStatus {
        case .working:
            return "Working..."
        case .idle:
            return "Ready"
        case .needsInput:
            return "Input needed"
        }
    }

    init() {
        createStatusFileIfNeeded()
        startFileMonitoring()
        startPulseAnimation()
        startPolling()
    }

    deinit {
        stopFileMonitoring()
        pulseTimer?.invalidate()
        pollTimer?.invalidate()
    }

    private func startPolling() {
        // Poll every 0.5 seconds as a backup in case file monitoring misses changes
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                self?.readStatusFile()
            }
            if let timer = self.pollTimer {
                RunLoop.main.add(timer, forMode: .common)
            }
        }
    }

    private func createStatusFileIfNeeded() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: Self.statusFilePath) {
            let initialStatus = StatusData(state: .idle, message: "Ready")
            if let data = try? JSONEncoder().encode(initialStatus) {
                fileManager.createFile(atPath: Self.statusFilePath, contents: data)
            }
        }
    }

    private func startFileMonitoring() {
        let path = Self.statusFilePath
        fileDescriptor = open(path, O_RDONLY)

        guard fileDescriptor != -1 else {
            print("Failed to open status file for monitoring")
            // Try again in a second
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.startFileMonitoring()
            }
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .rename, .delete],
            queue: DispatchQueue.main
        )

        source.setEventHandler { [weak self] in
            self?.readStatusFile()
        }

        source.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd != -1 {
                close(fd)
            }
        }

        source.resume()
        fileMonitor = source

        // Initial read
        readStatusFile()
    }

    private func stopFileMonitoring() {
        fileMonitor?.cancel()
        fileMonitor = nil
    }

    private func readStatusFile() {
        guard let data = FileManager.default.contents(atPath: Self.statusFilePath) else {
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let status = try? decoder.decode(StatusData.self, from: data) else {
            return
        }

        if currentStatus != status.state {
            let previousStatus = currentStatus
            DispatchQueue.main.async { [weak self] in
                withAnimation(.easeInOut(duration: 0.3)) {
                    self?.currentStatus = status.state
                    self?.statusMessage = status.message
                }

                // Play sound when transitioning from working to idle or needsInput
                if previousStatus == .working {
                    self?.playNotificationSound(for: status.state)
                }
            }
        }
    }

    private func playNotificationSound(for status: VibeStatus) {
        let soundName: String
        switch status {
        case .idle:
            soundName = "Glass"  // Pleasant completion sound
        case .needsInput:
            soundName = "Purr"   // Attention-getting sound
        case .working:
            return  // No sound when starting work
        }

        if let sound = NSSound(named: NSSound.Name(soundName)) {
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

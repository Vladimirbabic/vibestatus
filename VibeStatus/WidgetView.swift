import SwiftUI

// Root view with single TimelineView for animations
struct WidgetView: View {
    @EnvironmentObject var statusManager: StatusManager

    var body: some View {
        // Single TimelineView at root - passes time down as parameter
        TimelineView(.animation(minimumInterval: 0.05)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            WidgetContent(time: time)
                .environmentObject(statusManager)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// Content view receives time as parameter (no internal animation state)
struct WidgetContent: View {
    @EnvironmentObject var statusManager: StatusManager
    let time: Double

    var body: some View {
        VStack(spacing: 0) {
            // Header with title and settings
            HStack {
                Text("vibe status")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.35))

                Spacer()

                Button(action: {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.35))
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 2)

            // Main content
            Group {
                if statusManager.sessions.count <= 1 {
                    SingleSessionView(time: time)
                } else {
                    MultiSessionView(time: time)
                }
            }
        }
    }
}

// Notification for opening settings
extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
}

// Single session view
struct SingleSessionView: View {
    @EnvironmentObject var statusManager: StatusManager
    let time: Double

    private var projectName: String {
        statusManager.sessions.first?.project ?? ""
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(statusManager.statusText)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))

                if !projectName.isEmpty && statusManager.currentStatus != .notRunning {
                    Text(projectName)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 88, alignment: .leading)

            Spacer()

            StatusIndicator(status: statusManager.currentStatus, time: time)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}

// Multiple sessions view
struct MultiSessionView: View {
    @EnvironmentObject var statusManager: StatusManager
    let time: Double
    private let maxVisibleSessions = 10

    var body: some View {
        Group {
            if statusManager.sessions.count > maxVisibleSessions {
                ScrollView(.vertical, showsIndicators: true) {
                    sessionList
                }
            } else {
                sessionList
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var sessionList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(statusManager.sessions) { session in
                SessionRowView(session: session, time: time)
            }
        }
    }
}

// Individual session row
struct SessionRowView: View {
    let session: SessionInfo
    let time: Double

    var body: some View {
        HStack(spacing: 11) {
            SmallStatusIndicator(status: session.status, time: time)

            Text(session.project)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)

            Spacer()

            Text(statusLabel(for: session.status))
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
        }
    }

    private func statusLabel(for status: VibeStatus) -> String {
        switch status {
        case .working: return "working"
        case .idle: return "ready"
        case .needsInput: return "input"
        case .notRunning: return "offline"
        }
    }
}

// Full-size status indicator - receives time, no internal state
struct StatusIndicator: View {
    let status: VibeStatus
    let time: Double
    private let vibeOrange = Color(red: 0.757, green: 0.373, blue: 0.235)

    var body: some View {
        switch status {
        case .working:
            // Shimmering 5 dots
            HStack(spacing: 7) {
                ForEach(0..<5, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(vibeOrange)
                        .frame(width: 9, height: 9)
                        .opacity(shimmerOpacity(for: index, dotCount: 5))
                }
            }
        case .idle:
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.green.opacity(0.9))
                .frame(width: 11, height: 11)
        case .needsInput:
            // Pulsing blue
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.blue.opacity(0.9))
                .frame(width: 11, height: 11)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.blue.opacity(pulseOpacity), lineWidth: 2)
                        .scaleEffect(pulseScale)
                )
        case .notRunning:
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.5))
                .frame(width: 11, height: 11)
        }
    }

    private func shimmerOpacity(for index: Int, dotCount: Int) -> Double {
        let waveSpeed = 2.0
        let position = time * waveSpeed
        let waveCenter = position.truncatingRemainder(dividingBy: Double(dotCount + 2)) - 1
        let distance = abs(Double(index) - waveCenter)
        let brightness = exp(-distance * distance * 0.8)
        return 0.25 + 0.75 * brightness
    }

    private var pulseScale: Double {
        1.0 + 0.4 * (0.5 + 0.5 * sin(time * 4))
    }

    private var pulseOpacity: Double {
        0.4 * (1 - (pulseScale - 1) / 0.4)
    }
}

// Small status indicator - receives time, no internal state
struct SmallStatusIndicator: View {
    let status: VibeStatus
    let time: Double
    private let vibeOrange = Color(red: 0.757, green: 0.373, blue: 0.235)

    var body: some View {
        switch status {
        case .working:
            // Shimmering 3 dots
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(vibeOrange)
                        .frame(width: 7, height: 7)
                        .opacity(shimmerOpacity(for: index))
                }
            }
        case .idle:
            Circle()
                .fill(Color.green.opacity(0.9))
                .frame(width: 9, height: 9)
        case .needsInput:
            // Pulsing blue
            Circle()
                .fill(Color.blue.opacity(0.9))
                .frame(width: 9, height: 9)
                .opacity(0.5 + 0.5 * sin(time * 3))
        case .notRunning:
            Circle()
                .fill(Color.gray.opacity(0.5))
                .frame(width: 9, height: 9)
        }
    }

    private func shimmerOpacity(for index: Int) -> Double {
        let waveSpeed = 2.5
        let position = time * waveSpeed
        let waveCenter = position.truncatingRemainder(dividingBy: 5) - 1
        let distance = abs(Double(index) - waveCenter)
        let brightness = exp(-distance * distance * 0.6)
        return 0.3 + 0.7 * brightness
    }
}

// Preview
struct WidgetView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            WidgetView()
                .environmentObject(StatusManager.preview(status: .working))
                .frame(width: 220, height: 50)

            WidgetView()
                .environmentObject(StatusManager.preview(status: .idle))
                .frame(width: 220, height: 50)

            WidgetView()
                .environmentObject(StatusManager.preview(status: .needsInput))
                .frame(width: 220, height: 50)

            WidgetView()
                .environmentObject(StatusManager.preview(status: .notRunning))
                .frame(width: 220, height: 50)

            WidgetView()
                .environmentObject(StatusManager.previewMultiSession())
                .frame(width: 220, height: 100)
        }
        .padding()
        .background(Color.gray)
    }
}

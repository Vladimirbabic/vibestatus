import SwiftUI

struct WidgetView: View {
    @EnvironmentObject var statusManager: StatusManager

    var body: some View {
        VStack(spacing: 0) {
            // Header
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
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 2)

            // Content
            if statusManager.sessions.count <= 1 {
                SingleSessionView()
            } else {
                MultiSessionView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// Notification for opening settings
extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
}

// Single session view
struct SingleSessionView: View {
    @EnvironmentObject var statusManager: StatusManager

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(statusManager.statusText)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))

                if let project = statusManager.sessions.first?.project,
                   !project.isEmpty,
                   statusManager.currentStatus != .notRunning {
                    Text(project)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 88, alignment: .leading)

            Spacer()

            StatusIndicator(status: statusManager.currentStatus)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}

// Multiple sessions view
struct MultiSessionView: View {
    @EnvironmentObject var statusManager: StatusManager

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(statusManager.sessions) { session in
                    SessionRowView(session: session)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// Individual session row
struct SessionRowView: View {
    let session: SessionInfo

    var body: some View {
        HStack(spacing: 11) {
            SmallStatusIndicator(status: session.status)

            Text(session.project)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)

            Spacer()

            Text(statusLabel)
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
        }
    }

    private var statusLabel: String {
        switch session.status {
        case .working: return "working"
        case .idle: return "ready"
        case .needsInput: return "input"
        case .notRunning: return "offline"
        }
    }
}

// Status indicator - STATIC, NO ANIMATIONS
struct StatusIndicator: View {
    let status: VibeStatus
    private let vibeOrange = Color(red: 0.757, green: 0.373, blue: 0.235)

    var body: some View {
        switch status {
        case .working:
            HStack(spacing: 7) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(vibeOrange)
                        .frame(width: 9, height: 9)
                        .opacity(0.4 + Double(i) * 0.15)
                }
            }
        case .idle:
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.green.opacity(0.9))
                .frame(width: 11, height: 11)
        case .needsInput:
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.blue.opacity(0.9))
                .frame(width: 11, height: 11)
        case .notRunning:
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.5))
                .frame(width: 11, height: 11)
        }
    }
}

// Small status indicator - STATIC, NO ANIMATIONS
struct SmallStatusIndicator: View {
    let status: VibeStatus
    private let vibeOrange = Color(red: 0.757, green: 0.373, blue: 0.235)

    var body: some View {
        switch status {
        case .working:
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(vibeOrange)
                        .frame(width: 7, height: 7)
                        .opacity(0.5 + Double(i) * 0.25)
                }
            }
        case .idle:
            Circle()
                .fill(Color.green.opacity(0.9))
                .frame(width: 9, height: 9)
        case .needsInput:
            Circle()
                .fill(Color.blue.opacity(0.9))
                .frame(width: 9, height: 9)
        case .notRunning:
            Circle()
                .fill(Color.gray.opacity(0.5))
                .frame(width: 9, height: 9)
        }
    }
}

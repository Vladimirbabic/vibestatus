import SwiftUI

struct WidgetView: View {
    @EnvironmentObject var statusManager: StatusManager

    var body: some View {
        Group {
            if statusManager.sessions.count <= 1 {
                // Single session or no sessions - show simple view
                SingleSessionView()
            } else {
                // Multiple sessions - show each with project name
                MultiSessionView()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.8))
        )
    }
}

// Single session view (original layout)
struct SingleSessionView: View {
    @EnvironmentObject var statusManager: StatusManager

    var body: some View {
        HStack(spacing: 16) {
            // Status text first
            Text(statusManager.statusText)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 80, alignment: .leading)

            Spacer()

            // Runway lights or status indicator
            StatusIndicator(status: statusManager.currentStatus, pulseScale: statusManager.pulseScale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// Multiple sessions view
struct MultiSessionView: View {
    @EnvironmentObject var statusManager: StatusManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(statusManager.sessions) { session in
                SessionRowView(session: session, pulseScale: statusManager.pulseScale)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// Individual session row
struct SessionRowView: View {
    let session: SessionInfo
    let pulseScale: CGFloat

    var body: some View {
        HStack(spacing: 10) {
            // Status indicator (small)
            SmallStatusIndicator(status: session.status, pulseScale: pulseScale)

            // Project name
            Text(session.project)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)

            Spacer()

            // Status text (small, grayed)
            Text(statusLabel(for: session.status))
                .font(.system(size: 10, weight: .regular, design: .rounded))
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

// Full-size status indicator
struct StatusIndicator: View {
    let status: VibeStatus
    let pulseScale: CGFloat

    var body: some View {
        Group {
            switch status {
            case .working:
                RunwayLightsView()
            case .idle:
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.green.opacity(0.9))
                    .frame(width: 10, height: 10)
            case .needsInput:
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.blue.opacity(0.9))
                    .frame(width: 10, height: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color.blue.opacity(0.4), lineWidth: 2)
                            .scaleEffect(pulseScale)
                            .opacity(2 - pulseScale)
                    )
            case .notRunning:
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 10, height: 10)
            }
        }
    }
}

// Small status indicator for multi-session rows
struct SmallStatusIndicator: View {
    let status: VibeStatus
    let pulseScale: CGFloat
    private let vibeOrange = Color(red: 0.757, green: 0.373, blue: 0.235)

    var body: some View {
        Group {
            switch status {
            case .working:
                // Small animated dot for working
                Circle()
                    .fill(vibeOrange)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(vibeOrange.opacity(0.4), lineWidth: 1)
                            .scaleEffect(pulseScale * 0.8)
                            .opacity(2 - pulseScale)
                    )
            case .idle:
                Circle()
                    .fill(Color.green.opacity(0.9))
                    .frame(width: 8, height: 8)
            case .needsInput:
                Circle()
                    .fill(Color.blue.opacity(0.9))
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(Color.blue.opacity(0.4), lineWidth: 1)
                            .scaleEffect(pulseScale * 0.8)
                            .opacity(2 - pulseScale)
                    )
            case .notRunning:
                Circle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 8, height: 8)
            }
        }
    }
}

struct RunwayLightsView: View {
    @State private var activeDotIndex: Int = 0
    private let dotCount = 5
    private let vibeOrange = Color(red: 0.757, green: 0.373, blue: 0.235) // #C15F3C

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<dotCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(dotColor(for: index))
                    .frame(width: 8, height: 8)
            }
        }
        .onAppear {
            startAnimation()
        }
    }

    private func dotColor(for index: Int) -> Color {
        // Create a trailing effect: active dot is brightest, previous dots fade
        let distance = (index - activeDotIndex + dotCount) % dotCount

        if distance == 0 {
            return vibeOrange
        } else if distance == dotCount - 1 {
            return vibeOrange.opacity(0.7)
        } else if distance == dotCount - 2 {
            return vibeOrange.opacity(0.4)
        } else {
            return vibeOrange.opacity(0.12)
        }
    }

    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.1)) {
                activeDotIndex = (activeDotIndex + 1) % dotCount
            }
        }
    }
}

// Preview
struct WidgetView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Single session states
            WidgetView()
                .environmentObject(StatusManager.preview(status: .working))
                .frame(width: 180, height: 44)

            WidgetView()
                .environmentObject(StatusManager.preview(status: .idle))
                .frame(width: 180, height: 44)

            WidgetView()
                .environmentObject(StatusManager.preview(status: .needsInput))
                .frame(width: 180, height: 44)

            WidgetView()
                .environmentObject(StatusManager.preview(status: .notRunning))
                .frame(width: 180, height: 44)

            // Multi-session view
            WidgetView()
                .environmentObject(StatusManager.previewMultiSession())
                .frame(width: 180, height: 80)
        }
        .padding()
        .background(Color.gray)
    }
}

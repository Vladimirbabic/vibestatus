import SwiftUI

struct WidgetView: View {
    @EnvironmentObject var statusManager: StatusManager

    var body: some View {
        Group {
            if statusManager.sessions.count <= 1 {
                SingleSessionView()
            } else {
                MultiSessionView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.8))
        )
    }
}

// Single session view
struct SingleSessionView: View {
    @EnvironmentObject var statusManager: StatusManager

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
                SessionRowView(session: session)
            }
        }
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

// Full-size status indicator
struct StatusIndicator: View {
    let status: VibeStatus

    var body: some View {
        switch status {
        case .working:
            RunwayLightsView()
        case .idle:
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.green.opacity(0.9))
                .frame(width: 11, height: 11)
        case .needsInput:
            PulsingIndicator(color: .blue, size: 11, cornerRadius: 3)
        case .notRunning:
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.5))
                .frame(width: 11, height: 11)
        }
    }
}

// Small status indicator for multi-session rows
struct SmallStatusIndicator: View {
    let status: VibeStatus

    var body: some View {
        switch status {
        case .working:
            SmallRunwayLightsView()
        case .idle:
            Circle()
                .fill(Color.green.opacity(0.9))
                .frame(width: 9, height: 9)
        case .needsInput:
            SmallPulsingIndicator(color: .blue)
        case .notRunning:
            Circle()
                .fill(Color.gray.opacity(0.5))
                .frame(width: 9, height: 9)
        }
    }
}

// Small runway lights for multi-session rows (3 dots)
struct SmallRunwayLightsView: View {
    private let vibeOrange = Color(red: 0.757, green: 0.373, blue: 0.235)
    @State private var animationPhase: Double = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(vibeOrange)
                    .frame(width: 7, height: 7)
                    .opacity(opacityFor(index))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                animationPhase = 1
            }
        }
    }

    private func opacityFor(_ index: Int) -> Double {
        let offset = Double(index) / 3.0
        let phase = (animationPhase + offset).truncatingRemainder(dividingBy: 1.0)
        return 0.3 + 0.7 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2)
    }
}

// Pulsing indicator
struct PulsingIndicator: View {
    let color: Color
    let size: CGFloat
    let cornerRadius: CGFloat
    @State private var isPulsing = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(color.opacity(0.9))
            .frame(width: size, height: size)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(color.opacity(isPulsing ? 0.1 : 0.4), lineWidth: 2)
                    .scaleEffect(isPulsing ? 1.5 : 1.0)
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

// Small pulsing indicator
struct SmallPulsingIndicator: View {
    let color: Color
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 9, height: 9)
            .opacity(isPulsing ? 1.0 : 0.5)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

// Runway lights animation - shimmering dots
struct RunwayLightsView: View {
    private let vibeOrange = Color(red: 0.757, green: 0.373, blue: 0.235)
    @State private var animationPhase: Double = 0

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(vibeOrange)
                    .frame(width: 9, height: 9)
                    .opacity(opacityFor(index))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                animationPhase = 1
            }
        }
    }

    private func opacityFor(_ index: Int) -> Double {
        // Create shimmer wave across 5 dots
        let offset = Double(index) / 5.0
        let phase = (animationPhase + offset).truncatingRemainder(dividingBy: 1.0)

        // Gaussian-like brightness curve
        let distance = abs(phase - 0.5) * 2 // 0 at center, 1 at edges
        let brightness = exp(-distance * distance * 2)

        return 0.25 + 0.75 * brightness
    }
}

// Preview
struct WidgetView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
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

            WidgetView()
                .environmentObject(StatusManager.previewMultiSession())
                .frame(width: 180, height: 80)
        }
        .padding()
        .background(Color.gray)
    }
}

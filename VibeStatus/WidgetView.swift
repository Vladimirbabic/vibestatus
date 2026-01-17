import SwiftUI

struct WidgetView: View {
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
            Group {
                switch statusManager.currentStatus {
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
                                .scaleEffect(statusManager.pulseScale)
                                .opacity(2 - statusManager.pulseScale)
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.8))
        )
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
            WidgetView()
                .environmentObject(StatusManager.preview(status: .working))

            WidgetView()
                .environmentObject(StatusManager.preview(status: .idle))

            WidgetView()
                .environmentObject(StatusManager.preview(status: .needsInput))
        }
        .padding()
        .background(Color.gray)
    }
}

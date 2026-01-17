import SwiftUI

struct SetupView: View {
    @EnvironmentObject var setupManager: SetupManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 72))
                    .foregroundColor(Color(red: 0.757, green: 0.373, blue: 0.235))

                Text("Claude Indicator")
                    .font(.system(size: 28, weight: .semibold))
            }
            .padding(.top, 36)
            .padding(.bottom, 30)

            Divider()

            // Content
            if setupManager.isConfigured {
                configuredView
            } else {
                setupRequiredView
            }

            Spacer()

            // Footer
            if let error = setupManager.setupError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            Divider()

            HStack {
                if setupManager.isConfigured {
                    Button("Remove Integration") {
                        try? setupManager.unconfigure()
                    }
                    .foregroundColor(.red)
                }

                Spacer()

                Button("Close") {
                    dismiss()
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.escape)
            }
            .padding()
        }
        .frame(width: 630, height: 620)
    }

    var setupRequiredView: some View {
        VStack(spacing: 24) {
            Text("Setup Required")
                .font(.system(size: 20, weight: .semibold))
                .padding(.top, 24)

            Text("To show Claude Code's status, this app needs to configure hooks that communicate with the indicator widget.")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            VStack(alignment: .leading, spacing: 12) {
                Label("Create ~/.claude/hooks/claude-indicator.sh", systemImage: "doc.badge.plus")
                Label("Update ~/.claude/settings.json", systemImage: "gearshape")
            }
            .font(.system(size: 14))
            .foregroundColor(.secondary)
            .padding(18)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)

            Button(action: {
                Task {
                    await setupManager.configure()
                }
            }) {
                if setupManager.isSettingUp {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 240)
                } else {
                    Text("Configure Integration")
                        .font(.system(size: 16))
                        .frame(width: 240)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.757, green: 0.373, blue: 0.235))
            .disabled(setupManager.isSettingUp)
            .controlSize(.large)
        }
    }

    var configuredView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(.green)
                .padding(.top, 24)

            Text("Integration Active")
                .font(.system(size: 20, weight: .semibold))

            Text("Claude Code hooks are configured. The indicator widget will now show Claude's status.")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color(red: 0.757, green: 0.373, blue: 0.235))
                        .frame(width: 14, height: 14)
                    Text("Orange animated dots = Claude is working")
                        .font(.system(size: 14))
                }
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 14, height: 14)
                    Text("Green = Idle, ready for next task")
                        .font(.system(size: 14))
                }
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 14, height: 14)
                    Text("Blue = Claude needs your input")
                        .font(.system(size: 14))
                }
            }
            .padding(18)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)

            Text("Restart Claude Code to activate hooks")
                .font(.system(size: 14))
                .foregroundColor(.orange)
        }
    }
}

struct SetupView_Previews: PreviewProvider {
    static var previews: some View {
        SetupView()
            .environmentObject(SetupManager.shared)
    }
}

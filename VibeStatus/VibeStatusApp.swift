import SwiftUI
import AppKit
import Sparkle

@main
struct VibeStatusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// Custom panel that never becomes key window (doesn't steal focus)
class NonActivatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var floatingWindow: NSWindow?
    var statusManager = StatusManager.shared
    let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    private let windowWidth: CGFloat = 220
    private let singleSessionHeight: CGFloat = 62
    private let sessionRowHeight: CGFloat = 28
    private let maxVisibleSessions = 10

    // Simple timer for UI updates
    private var uiUpdateTimer: Timer?
    private var lastSessionCount: Int = 0
    private var lastStatus: VibeStatus = .notRunning

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupFloatingWindow()
        startUIUpdates()

        // Listen for settings open request from widget
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showSetupWindow),
            name: .openSettings,
            object: nil
        )

        // Check if setup is needed
        if !SetupManager.shared.isConfigured {
            showSetupWindow()
        }
    }

    private func startUIUpdates() {
        // Simple timer to check for changes - no Combine, no async
        uiUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.checkForUIUpdates()
        }
    }

    private func checkForUIUpdates() {
        // Update menu bar icon if status changed
        if statusManager.currentStatus != lastStatus {
            lastStatus = statusManager.currentStatus
            updateMenuBarIcon()
        }

        // Update window size if session count changed
        let currentCount = statusManager.sessions.count
        if currentCount != lastSessionCount {
            lastSessionCount = currentCount
            updateFloatingWindowSize(sessionCount: currentCount)
        }
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateMenuBarIcon()

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Widget", action: #selector(showWidget), keyEquivalent: "s"))
        menu.addItem(NSMenuItem(title: "Hide Widget", action: #selector(hideWidget), keyEquivalent: "h"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSetupWindow), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        let checkForUpdatesItem = NSMenuItem(title: "Check for Updates...", action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "u")
        checkForUpdatesItem.target = updaterController
        menu.addItem(checkForUpdatesItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    private func updateFloatingWindowSize(sessionCount: Int) {
        guard let window = floatingWindow, let screen = NSScreen.main else { return }

        let newHeight: CGFloat
        if sessionCount <= 1 {
            newHeight = singleSessionHeight
        } else {
            // Cap at maxVisibleSessions to prevent giant window
            let visibleCount = min(sessionCount, maxVisibleSessions)
            newHeight = CGFloat(visibleCount) * sessionRowHeight + 20
        }

        let padding: CGFloat = 20
        let position = WidgetPosition(rawValue: SetupManager.shared.widgetPosition) ?? .bottomRight

        let xPos: CGFloat
        switch position {
        case .bottomRight:
            xPos = screen.visibleFrame.maxX - windowWidth - padding
        case .bottomLeft:
            xPos = screen.visibleFrame.minX + padding
        }
        let yPos = screen.visibleFrame.minY + padding

        let newFrame = NSRect(x: xPos, y: yPos, width: windowWidth, height: newHeight)
        window.setFrame(newFrame, display: true)
    }

    func updateMenuBarIcon() {
        guard let button = statusItem?.button else { return }

        let iconName: String
        let accessibilityLabel: String
        let color: NSColor

        switch statusManager.currentStatus {
        case .working:
            iconName = "circle.fill"
            accessibilityLabel = "VibeStatus Working"
            color = NSColor(red: 0.757, green: 0.373, blue: 0.235, alpha: 1.0) // vibeOrange
        case .idle:
            iconName = "circle.fill"
            accessibilityLabel = "VibeStatus Ready"
            color = NSColor.systemGreen
        case .needsInput:
            iconName = "questionmark.circle.fill"
            accessibilityLabel = "VibeStatus Needs Input"
            color = NSColor.systemBlue
        case .notRunning:
            iconName = "circle"
            accessibilityLabel = "VibeStatus Not Running"
            color = NSColor.systemGray
        }

        let config = NSImage.SymbolConfiguration(paletteColors: [color])
        if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: accessibilityLabel)?.withSymbolConfiguration(config) {
            button.image = image
            button.image?.isTemplate = false
        }
    }

    func setupFloatingWindow() {
        let initialHeight = singleSessionHeight

        let contentView = WidgetView()
            .environmentObject(statusManager)

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: windowWidth, height: initialHeight)

        // Calculate position based on setting
        guard let screen = NSScreen.main else { return }
        let padding: CGFloat = 20
        let position = WidgetPosition(rawValue: SetupManager.shared.widgetPosition) ?? .bottomRight

        let xPos: CGFloat
        switch position {
        case .bottomRight:
            xPos = screen.visibleFrame.maxX - windowWidth - padding
        case .bottomLeft:
            xPos = screen.visibleFrame.minX + padding
        }
        let yPos = screen.visibleFrame.minY + padding

        // Use NSPanel with nonactivating style so it doesn't steal focus
        let panel = NonActivatingPanel(
            contentRect: NSRect(x: xPos, y: yPos, width: windowWidth, height: initialHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.contentView = hostingView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hasShadow = true
        panel.hidesOnDeactivate = false

        panel.orderFront(nil)
        floatingWindow = panel
    }

    @objc func showWidget() {
        floatingWindow?.orderFront(nil)
    }

    @objc func hideWidget() {
        floatingWindow?.orderOut(nil)
    }

    @objc func showSetupWindow() {
        let setupView = SetupView()
            .environmentObject(SetupManager.shared)

        let hostingView = NSHostingView(rootView: setupView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 630, height: 620),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.contentView = hostingView
        window.title = "Settings"
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

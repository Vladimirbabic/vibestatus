import SwiftUI
import AppKit
import Combine
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

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var floatingWindow: NSWindow?
    var statusManager = StatusManager.shared
    var statusObserver: NSObjectProtocol?
    let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupFloatingWindow()
        observeStatusChanges()

        // Check if setup is needed
        if !SetupManager.shared.isConfigured {
            showSetupWindow()
        }
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateMenuBarIcon()

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Widget", action: #selector(showWidget), keyEquivalent: "s"))
        menu.addItem(NSMenuItem(title: "Hide Widget", action: #selector(hideWidget), keyEquivalent: "h"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Configure Hooks...", action: #selector(showSetupWindow), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        let checkForUpdatesItem = NSMenuItem(title: "Check for Updates...", action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "u")
        checkForUpdatesItem.target = updaterController
        menu.addItem(checkForUpdatesItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    func observeStatusChanges() {
        statusObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("VibeStatusStatusChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateMenuBarIcon()
        }

        // Also use Combine to observe the published property
        statusManager.$currentStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBarIcon()
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    func updateMenuBarIcon() {
        guard let button = statusItem?.button else { return }

        let iconName: String
        let accessibilityLabel: String

        switch statusManager.currentStatus {
        case .working:
            iconName = "circle.dotted"
            accessibilityLabel = "VibeStatus Working"
        case .idle:
            iconName = "circle.fill"
            accessibilityLabel = "VibeStatus Ready"
        case .needsInput:
            iconName = "questionmark.circle.fill"
            accessibilityLabel = "VibeStatus Needs Input"
        case .notRunning:
            iconName = "circle"
            accessibilityLabel = "VibeStatus Not Running"
        }

        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: accessibilityLabel)
        button.image?.isTemplate = true
    }

    func setupFloatingWindow() {
        let windowWidth: CGFloat = 220
        let windowHeight: CGFloat = 50

        let contentView = WidgetView()
            .environmentObject(statusManager)
            .frame(width: windowWidth, height: windowHeight)

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)

        // Calculate position (bottom-right corner)
        guard let screen = NSScreen.main else { return }
        let padding: CGFloat = 20

        let xPos = screen.visibleFrame.maxX - windowWidth - padding
        let yPos = screen.visibleFrame.minY + padding

        let window = NSWindow(
            contentRect: NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.contentView = hostingView
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isMovableByWindowBackground = true
        window.hasShadow = true

        window.orderFront(nil)
        floatingWindow = window
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
        window.title = "VibeStatus Setup"
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

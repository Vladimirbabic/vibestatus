// VibeStatusApp.swift
// VibeStatus
//
// Application entry point and main AppDelegate.
// This is a menu bar (LSUIElement) app that:
// - Shows Claude Code status in the system menu bar
// - Manages a floating desktop widget
// - Provides a settings window for configuration
// - Auto-updates via Sparkle
//
// The app runs as an accessory (no dock icon) and never steals focus
// from other applications except when the Settings window is shown.

import SwiftUI
import AppKit
import Sparkle
import Combine

// MARK: - App Entry Point

@main
struct VibeStatusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// MARK: - App Delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties

    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private let statusManager = StatusManager.shared
    private let licenseManager = LicenseManager.shared
    private let widgetController = FloatingWidgetController()
    private var lastSessionCount: Int = 0
    private var cancellables = Set<AnyCancellable>()

    /// Sparkle updater controller for auto-updates
    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    // MARK: - App Lifecycle

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as accessory app - no dock icon, never steals focus
        NSApp.setActivationPolicy(.accessory)

        setupMenuBar()
        setupSubscriptions()
        setupNotificationObservers()
        statusManager.start()

        // Show widget if enabled (auto-show handles visibility based on sessions)
        if SetupManager.shared.widgetEnabled {
            widgetController.show()
        }

        // Show setup window on first launch
        if !SetupManager.shared.isConfigured {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showSetupWindow()
            }
        }

        // Revalidate license periodically (every 24 hours)
        if licenseManager.needsRevalidation() {
            Task {
                await licenseManager.validateLicense()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusManager.stop()
        cancellables.removeAll()
    }

    // MARK: - Subscriptions

    private func setupSubscriptions() {
        // Update menu bar when status changes
        statusManager.$currentStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusBar()
            }
            .store(in: &cancellables)

        // Rebuild menu when session count changes
        statusManager.$sessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                guard let self else { return }
                if sessions.count != lastSessionCount {
                    lastSessionCount = sessions.count
                    rebuildMenu()
                }
                updateStatusBar()
            }
            .store(in: &cancellables)

        // Toggle widget visibility based on settings
        SetupManager.shared.$widgetEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                guard let self else { return }
                if enabled {
                    widgetController.show()
                } else {
                    widgetController.hide()
                }
                rebuildMenu()
            }
            .store(in: &cancellables)

        // Update menu bar when license status changes
        licenseManager.$licenseStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusBar()
                self?.rebuildMenu()
            }
            .store(in: &cancellables)
    }

    // MARK: - Notification Observers

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenLicenseSettings),
            name: .openLicenseSettings,
            object: nil
        )
    }

    @objc private func handleOpenLicenseSettings() {
        openSettingsWindow(tab: .license)
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusBar()
        rebuildMenu()
    }

    private func updateStatusBar() {
        guard let button = statusItem?.button else { return }

        // Show lock icon if not licensed
        if !licenseManager.isLicensed {
            button.title = ""
            button.image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "License required")
            button.image?.isTemplate = true
            return
        }

        let sessions = statusManager.sessions

        if sessions.isEmpty {
            button.title = ""
            button.image = NSImage(systemSymbolName: "circle", accessibilityDescription: "No sessions")
            button.image?.isTemplate = true
            return
        }

        // Build attributed string with colored dots and project abbreviations
        let result = NSMutableAttributedString()

        for (index, session) in sessions.prefix(5).enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: " "))
            }

            let dotColor = statusColor(for: session.status)
            let dot = NSAttributedString(string: "● ", attributes: [
                .foregroundColor: dotColor,
                .font: NSFont.systemFont(ofSize: 11)
            ])
            result.append(dot)

            let abbrev = String(session.project.prefix(3))
            let text = NSAttributedString(string: abbrev, attributes: [
                .foregroundColor: NSColor.labelColor,
                .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
            ])
            result.append(text)
        }

        button.image = nil
        button.attributedTitle = result
    }

    private func statusColor(for status: VibeStatus) -> NSColor {
        switch status {
        case .working: return AppConstants.brandOrangeNS
        case .idle: return .systemGreen
        case .needsInput: return .systemBlue
        case .notRunning: return .systemGray
        }
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        // Status text
        let statusMenuItem = NSMenuItem(title: statusManager.statusText, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        // Session list (if multiple)
        if statusManager.sessions.count > 1 {
            menu.addItem(NSMenuItem.separator())
            for session in statusManager.sessions {
                let emoji = statusEmoji(for: session.status)
                let sessionItem = NSMenuItem(title: "\(emoji) \(session.project)", action: nil, keyEquivalent: "")
                sessionItem.isEnabled = false
                menu.addItem(sessionItem)
            }
        } else if let session = statusManager.sessions.first {
            let projectItem = NSMenuItem(title: session.project, action: nil, keyEquivalent: "")
            projectItem.isEnabled = false
            menu.addItem(projectItem)
        }

        menu.addItem(NSMenuItem.separator())

        // Widget toggle
        let widgetTitle = SetupManager.shared.widgetEnabled ? "Hide Widget" : "Show Widget"
        menu.addItem(NSMenuItem(title: widgetTitle, action: #selector(toggleWidget), keyEquivalent: "w"))

        // Settings
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSetupWindow), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())

        // Updates
        let checkForUpdatesItem = NSMenuItem(
            title: "Check for Updates...",
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
            keyEquivalent: "u"
        )
        checkForUpdatesItem.target = updaterController
        menu.addItem(checkForUpdatesItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    private func statusEmoji(for status: VibeStatus) -> String {
        switch status {
        case .working: return "🟠"
        case .idle: return "🟢"
        case .needsInput: return "🔵"
        case .notRunning: return "⚪"
        }
    }

    // MARK: - Actions

    @objc func showSetupWindow() {
        openSettingsWindow(tab: nil)
    }

    private func openSettingsWindow(tab: SettingsTab?) {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            // If a specific tab is requested, post notification to switch
            if let tab = tab {
                NotificationCenter.default.post(name: .switchSettingsTab, object: tab)
            }
            return
        }

        let setupView = SetupView(initialTab: tab ?? .general)
        let hostingView = NSHostingView(rootView: setupView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 630, height: 620),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.contentView = hostingView
        window.title = "Settings"
        window.backgroundColor = NSColor.black
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }

    @objc func toggleWidget() {
        SetupManager.shared.widgetEnabled.toggle()
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

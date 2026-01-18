// FloatingWidgetController.swift
// VibeStatus
//
// Manages the floating desktop widget window.
// Uses a NonActivatingPanel to display status without stealing focus.
//
// Architecture:
// - NonActivatingPanel: Custom NSPanel that never becomes key/main window
// - WidgetViewModel: Observable model that bridges StatusManager to SwiftUI
// - The view is created once and updated via bindings to avoid crashes during drag

import AppKit
import SwiftUI
import Combine

// MARK: - Non-Activating Panel

/// A panel that doesn't activate the app or steal focus from other windows.
/// Essential for a status widget that should be visible but non-intrusive.
final class NonActivatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
    }
}

// MARK: - Widget View Model

/// Observable data source for the widget view.
/// Separates data updates from view recreation to prevent crashes during drag.
@MainActor
final class WidgetViewModel: ObservableObject {
    @Published var status: VibeStatus = .notRunning
    @Published var statusText: String = "Run Claude"
    @Published var sessions: [SessionInfo] = []
    @Published var style: WidgetStyle = .standard
    @Published var theme: WidgetThemeConfig?
    @Published var isLicensed: Bool = false

    func update(from manager: StatusManager) {
        status = manager.currentStatus
        statusText = manager.statusText
        sessions = manager.sessions
    }

    func updateLicenseStatus() {
        isLicensed = LicenseManager.shared.isLicensed
    }

    func updateStyle(_ newStyle: WidgetStyle) {
        style = newStyle
    }

    func updateTheme() {
        theme = WidgetThemeConfig.current()
    }

    func openLicenseSettings() {
        NotificationCenter.default.post(name: .openLicenseSettings, object: nil)
    }
}

// MARK: - Observable Widget View

/// SwiftUI wrapper that observes the view model for reactive updates
struct ObservableWidgetView: View {
    @ObservedObject var viewModel: WidgetViewModel

    var body: some View {
        WidgetView(
            data: WidgetData(
                status: viewModel.status,
                statusText: viewModel.statusText,
                sessions: viewModel.sessions
            ),
            style: viewModel.style,
            theme: viewModel.theme,
            isLicensed: viewModel.isLicensed,
            onUnlicensedTap: viewModel.openLicenseSettings
        )
    }
}

// MARK: - Floating Widget Controller

/// Controls the floating widget panel lifecycle and positioning.
@MainActor
final class FloatingWidgetController: ObservableObject {
    private var panel: NonActivatingPanel?
    private var cancellables = Set<AnyCancellable>()
    private let statusManager = StatusManager.shared
    private let setupManager = SetupManager.shared
    private let licenseManager = LicenseManager.shared
    private let viewModel = WidgetViewModel()

    @Published private(set) var isVisible: Bool = false

    init() {
        setupSubscriptions()
    }

    deinit {
        panel?.close()
    }

    // MARK: - Public API

    func show() {
        guard setupManager.widgetEnabled else { return }

        if panel == nil {
            createPanel()
        }

        viewModel.update(from: statusManager)
        viewModel.updateTheme()
        viewModel.updateStyle(WidgetStyle(rawValue: setupManager.widgetStyle) ?? .standard)
        viewModel.updateLicenseStatus()

        updatePanelSize()
        updatePosition()
        panel?.orderFront(nil)
        isVisible = true
    }

    func hide() {
        panel?.orderOut(nil)
        isVisible = false
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    // MARK: - Private Methods

    private func setupSubscriptions() {
        // Update widget when sessions change
        statusManager.$sessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, isVisible else { return }
                viewModel.update(from: statusManager)
                updatePanelSize()
            }
            .store(in: &cancellables)

        // Update widget when status changes
        statusManager.$currentStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, isVisible else { return }
                viewModel.update(from: statusManager)
            }
            .store(in: &cancellables)

        // Auto show/hide based on session presence
        statusManager.$sessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                guard let self, setupManager.widgetEnabled else { return }

                if setupManager.widgetAutoShow {
                    if sessions.isEmpty {
                        hide()
                    } else if !isVisible {
                        show()
                    }
                }
            }
            .store(in: &cancellables)

        // React to position changes
        setupManager.$widgetPosition
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, isVisible else { return }
                updatePosition()
            }
            .store(in: &cancellables)

        // React to style changes - recreate panel for new dimensions
        // Note: Don't update viewModel.style here as it triggers SwiftUI during teardown
        // The style is correctly set in show() -> createPanel() after recreation
        setupManager.$widgetStyle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, isVisible else { return }
                recreatePanel()
            }
            .store(in: &cancellables)

        // React to theme changes
        Publishers.Merge3(
            setupManager.$widgetTheme.map { _ in () },
            setupManager.$widgetOpacity.map { _ in () },
            setupManager.$widgetAccentColor.map { _ in () }
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            guard let self, isVisible else { return }
            viewModel.updateTheme()
        }
        .store(in: &cancellables)

        // React to license status changes
        licenseManager.$licenseStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, isVisible else { return }
                viewModel.updateLicenseStatus()
            }
            .store(in: &cancellables)
    }

    private func createPanel() {
        let size = calculateSize()
        let frame = NSRect(x: 0, y: 0, width: size.width, height: size.height)

        panel = NonActivatingPanel(contentRect: frame)

        let style = WidgetStyle(rawValue: setupManager.widgetStyle) ?? .standard
        viewModel.updateStyle(style)
        viewModel.updateTheme()

        let widgetView = ObservableWidgetView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: widgetView)
        panel?.contentView = hostingView

        updatePosition()
    }

    private func recreatePanel() {
        let wasVisible = isVisible
        panel?.close()
        panel = nil

        if wasVisible {
            show()
        }
    }

    private func updatePanelSize() {
        guard let panel else { return }

        let newSize = calculateSize()
        var frame = panel.frame

        guard abs(frame.width - newSize.width) > 1 || abs(frame.height - newSize.height) > 1 else { return }

        // Adjust origin to keep widget anchored at its position
        let position = WidgetPosition(rawValue: setupManager.widgetPosition) ?? .bottomRight

        switch position {
        case .bottomRight, .bottomLeft:
            frame.origin.y -= (newSize.height - frame.height)
        case .topRight, .topLeft, .notch:
            break
        }

        frame.size = newSize
        panel.setFrame(frame, display: true, animate: true)
    }

    private func calculateSize() -> NSSize {
        let style = WidgetStyle(rawValue: setupManager.widgetStyle) ?? .standard
        let sessionCount = statusManager.sessions.count

        switch style {
        case .mini:
            return NSSize(
                width: WidgetLayoutConstants.Mini.collapsedSize,
                height: WidgetLayoutConstants.Mini.collapsedSize
            )
        case .compact:
            return NSSize(
                width: WidgetLayoutConstants.Compact.width,
                height: WidgetLayoutConstants.Compact.height
            )
        case .standard:
            if sessionCount <= 1 {
                return NSSize(
                    width: WidgetLayoutConstants.Standard.width,
                    height: WidgetLayoutConstants.Standard.singleSessionHeight
                )
            } else {
                let visibleSessions = min(sessionCount, WidgetLayoutConstants.Standard.maxVisibleSessions)
                let height = WidgetLayoutConstants.Standard.multiSessionBaseHeight
                    + CGFloat(visibleSessions) * WidgetLayoutConstants.Standard.sessionRowHeight
                return NSSize(width: WidgetLayoutConstants.Standard.width, height: height)
            }
        }
    }

    private func updatePosition() {
        guard let panel, let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size
        let margin = WidgetLayoutConstants.screenMargin

        let position = WidgetPosition(rawValue: setupManager.widgetPosition) ?? .bottomRight

        var origin: NSPoint
        switch position {
        case .bottomRight:
            origin = NSPoint(
                x: screenFrame.maxX - panelSize.width - margin,
                y: screenFrame.minY + margin
            )
        case .bottomLeft:
            origin = NSPoint(
                x: screenFrame.minX + margin,
                y: screenFrame.minY + margin
            )
        case .topRight:
            origin = NSPoint(
                x: screenFrame.maxX - panelSize.width - margin,
                y: screenFrame.maxY - panelSize.height - margin
            )
        case .topLeft:
            origin = NSPoint(
                x: screenFrame.minX + margin,
                y: screenFrame.maxY - panelSize.height - margin
            )
        case .notch:
            let fullFrame = screen.frame
            origin = NSPoint(
                x: fullFrame.midX - panelSize.width / 2,
                y: fullFrame.maxY - panelSize.height - WidgetLayoutConstants.notchTopOffset
            )
        }

        panel.setFrameOrigin(origin)
    }
}

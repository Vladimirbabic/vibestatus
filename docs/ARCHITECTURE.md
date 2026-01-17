# Architecture & Risk Assessment

## System Overview

VibeStatus is a macOS menu bar application that monitors Claude Code sessions via file-based IPC. It uses a polling architecture to read status files written by hook scripts that Claude Code executes on state changes.

## Component Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                           VibeStatus App                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                         AppDelegate                             │ │
│  │  - Manages app lifecycle                                        │ │
│  │  - Owns StatusManager, SetupManager, WidgetController           │ │
│  │  - Handles menu bar updates                                     │ │
│  └──────────────────────────┬─────────────────────────────────────┘ │
│                             │                                        │
│         ┌───────────────────┼───────────────────┐                   │
│         │                   │                   │                    │
│         ▼                   ▼                   ▼                    │
│  ┌─────────────┐    ┌─────────────┐    ┌──────────────────┐        │
│  │StatusManager│    │SetupManager │    │FloatingWidget    │        │
│  │             │    │             │    │Controller        │        │
│  │ @MainActor  │    │ @MainActor  │    │ @MainActor       │        │
│  │ ObservableO │    │ ObservableO │    │ ObservableObject │        │
│  └──────┬──────┘    └──────┬──────┘    └────────┬─────────┘        │
│         │                  │                     │                   │
│         │ @Published       │ @Published          │ Combine           │
│         │ currentStatus    │ widgetEnabled       │ subscriptions     │
│         │ sessions         │ widgetPosition      │                   │
│         │                  │ etc.                │                   │
│         │                  │                     │                   │
│         ▼                  ▼                     ▼                   │
│  ┌─────────────────────────────────────────────────────────────────┐│
│  │                      SwiftUI Views                               ││
│  │  SetupView, WidgetView, ObservableWidgetView                    ││
│  └─────────────────────────────────────────────────────────────────┘│
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │ File I/O
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         File System                                  │
├─────────────────────────────────────────────────────────────────────┤
│  /tmp/vibestatus-*.json     Status files (read by StatusManager)    │
│  ~/.claude/settings.json    Claude config (modified by SetupManager)│
│  ~/.claude/hooks/           Hook scripts (created by SetupManager)  │
│  ~/Library/Preferences/     UserDefaults (app settings)             │
└─────────────────────────────────────────────────────────────────────┘
```

## Data Flow

### Status Update Flow

1. User submits prompt in Claude Code
2. Claude Code executes `UserPromptSubmit` hook
3. Hook script writes `{"state":"working",...}` to `/tmp/vibestatus-{session}.json`
4. StatusManager polls file, detects change
5. StatusManager updates `@Published` properties
6. Combine propagates to subscribers (menu bar, widget, sounds)

### Configuration Flow

1. User clicks "Configure" in Settings
2. SetupManager creates hook script at `~/.claude/hooks/vibestatus.sh`
3. SetupManager modifies `~/.claude/settings.json` to register hooks
4. User restarts Claude Code
5. Claude Code loads new hook configuration

## Thread Safety Model

All managers are `@MainActor` isolated:

```swift
@MainActor
final class StatusManager: ObservableObject {
    // All @Published properties are MainActor-safe
    @Published private(set) var currentStatus: VibeStatus
    @Published private(set) var sessions: [SessionInfo]

    // File I/O runs on background tasks
    private func update() async {
        let result = await Task.detached(priority: .utility) {
            Self.readStatusFiles()  // nonisolated static method
        }.value

        processUpdate(result)  // Back on MainActor
    }
}
```

## Risk Assessment

### High Severity

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Hook script modification by malicious actor | Arbitrary code execution | Low | Script permissions 755, owned by user |
| JSON parsing of untrusted files | Potential crash | Medium | Graceful error handling, JSON decoding in try/catch |

### Medium Severity

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Stale status files | Incorrect status display | Medium | 5-minute timeout, PID validation |
| Claude Code API changes | Hook events stop working | Medium | Document supported Claude Code versions |
| Memory growth from polling | App slowdown | Low | Using `.mappedIfSafe` for file reads |

### Low Severity

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Widget positioning on screen changes | Widget off-screen | Low | Uses `visibleFrame`, could add screen change detection |
| UserDefaults corruption | Settings reset | Very Low | Defaults are non-critical, app works without them |

## Bottlenecks & Inefficiencies

### Current Bottlenecks

1. **1-second polling interval**: Not ideal for battery life, but necessary for responsiveness
2. **Full directory scan per poll**: Reads all files matching pattern, could use FSEvents
3. **Widget recreation on style change**: Creates new panel, could morph existing

### Potential Optimizations

| Area | Current | Proposed | Effort | Impact |
|------|---------|----------|--------|--------|
| Polling | Timer-based | FSEvents file watching | M | M |
| Status files | JSON text | Binary plist or mmap | M | S |
| Widget updates | Recreate panel | Animate size changes | S | S |

## Improvement Roadmap

### Phase 0: Immediate (Low Risk)

- [x] Extract types to dedicated file
- [x] Extract constants to dedicated file
- [x] Add file-level documentation
- [x] Create README with architecture

### Phase 1: Near-term (Medium Effort)

- [ ] Add FSEvents watcher to replace polling (reduces battery usage)
- [ ] Add logging infrastructure for debugging
- [ ] Add telemetry opt-in for crash reporting
- [ ] Support multiple monitors for widget positioning

### Phase 2: Future (Larger Changes)

- [ ] Migrate to App Sandbox with security-scoped bookmarks
- [ ] Add menu bar icon customization
- [ ] Add global keyboard shortcuts
- [ ] Support other AI coding tools (Copilot, Cursor)

## Deployment Safety

### Pre-deployment Checklist

- [ ] Build succeeds with no warnings
- [ ] App launches without crash
- [ ] Menu bar shows correct status
- [ ] Widget appears and updates
- [ ] Settings window opens
- [ ] Hook configuration works
- [ ] Sound notifications play

### Rollback Plan

1. Users can manually delete hook script: `rm ~/.claude/hooks/vibestatus.sh`
2. Users can remove hooks from Claude config: edit `~/.claude/settings.json`
3. Previous app version available in releases

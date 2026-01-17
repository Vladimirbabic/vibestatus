# Vibe Status

A macOS menu bar app that shows the real-time status of your Claude Code sessions.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Menu bar indicator** with colored dots showing status per session
- **Floating desktop widget** with three styles (Standard, Mini, Compact)
- **Multi-session support** - track multiple Claude Code terminals
- **Customizable notifications** - sounds when Claude finishes or needs input
- **Auto-updates** via Sparkle

## Installation

1. Download the latest release from [Releases](https://github.com/Vladimirbabic/vibestatus/releases)
2. Move `VibeStatus.app` to your Applications folder
3. Open the app and click "Configure" to set up Claude Code hooks
4. Restart Claude Code to activate the integration

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                        Claude Code                               │
│  (Terminal)                                                      │
│                                                                  │
│  ┌──────────────────┐    Hook Events    ┌──────────────────┐   │
│  │ User sends       │ ─────────────────▶│ vibestatus.sh    │   │
│  │ prompt           │                   │ (hook script)    │   │
│  └──────────────────┘                   └────────┬─────────┘   │
│                                                   │              │
│  ┌──────────────────┐                            │              │
│  │ Claude finishes  │ ─────────────────▶         │              │
│  │ processing       │                            │              │
│  └──────────────────┘                            │              │
│                                                   ▼              │
└─────────────────────────────────────────────────────────────────┘
                                                   │
                                          Writes JSON to
                                          /tmp/vibestatus-{id}.json
                                                   │
                                                   ▼
┌─────────────────────────────────────────────────────────────────┐
│                        VibeStatus App                            │
│                                                                  │
│  ┌──────────────────┐                   ┌──────────────────┐   │
│  │ StatusManager    │◀─── Polls ────────│ /tmp/vibestatus- │   │
│  │ (1s interval)    │      files        │ *.json           │   │
│  └────────┬─────────┘                   └──────────────────┘   │
│           │                                                      │
│           │ Publishes via Combine                               │
│           ▼                                                      │
│  ┌────────────────────────────────────────────────────────────┐│
│  │                                                             ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐││
│  │  │ Menu Bar    │  │ Floating    │  │ Sound Notifications │││
│  │  │ Status      │  │ Widget      │  │                     │││
│  │  └─────────────┘  └─────────────┘  └─────────────────────┘││
│  │                                                             ││
│  └────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Hook Installation**: The app installs a shell script (`~/.claude/hooks/vibestatus.sh`) that Claude Code calls on status changes
2. **Status Writing**: The hook script writes JSON files to `/tmp/vibestatus-{session_id}.json` with state, project name, and PID
3. **Polling**: `StatusManager` polls these files every second
4. **State Aggregation**: Multiple sessions are aggregated (needsInput > working > idle > notRunning)
5. **UI Updates**: Status changes propagate via Combine to menu bar, widget, and sound notifications

### Status States

| Status | Color | Description |
|--------|-------|-------------|
| Working | 🟠 Orange | Claude is processing a request |
| Ready | 🟢 Green | Idle, waiting for input |
| Needs Input | 🔵 Blue | Claude requires user response |
| Not Running | ⚪ Gray | No active sessions |

## Architecture

### Source Files

| File | Responsibility |
|------|----------------|
| `Types.swift` | Core domain types (VibeStatus, SessionInfo, enums) |
| `Constants.swift` | App-wide constants (paths, timeouts, layout values) |
| `StatusManager.swift` | Polls status files, aggregates state, triggers sounds |
| `SetupManager.swift` | Configuration persistence, hook installation |
| `FloatingWidgetController.swift` | Floating panel lifecycle and positioning |
| `WidgetView.swift` | SwiftUI views for the widget (3 styles) |
| `SetupView.swift` | Settings window UI |
| `VibeStatusApp.swift` | App entry point, menu bar, window management |

### Key Design Decisions

1. **@MainActor Isolation**: All managers use @MainActor for thread safety
2. **Combine for Reactivity**: Published properties drive UI updates
3. **NonActivatingPanel**: Widget never steals focus from other apps
4. **Observable ViewModel**: Prevents crashes when dragging the widget

## Configuration Files

The app modifies these files:

- `~/.claude/settings.json` - Adds hook configuration
- `~/.claude/hooks/vibestatus.sh` - Hook script (created by app)
- `/tmp/vibestatus-*.json` - Runtime status files (temporary)

## Development

### Requirements

- macOS 13.0+
- Xcode 15.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (optional, for regenerating project)

### Building

```bash
# Generate Xcode project (if needed)
xcodegen generate

# Build
xcodebuild -scheme VibeStatus -configuration Debug build

# Or open in Xcode
open VibeStatus.xcodeproj
```

### Testing Status States

Use the provided test script to simulate status changes:

```bash
./test-states.sh
```

### Releasing

```bash
# Build, sign, notarize, and staple
APPLE_APP_PASSWORD=xxxx-xxxx-xxxx-xxxx ./scripts/build-and-notarize.sh
```

## Security Notes

- **App Sandbox Disabled**: Required to read/write `/tmp` and `~/.claude`
- **Hardened Runtime**: Enabled for notarization
- **No Network Access**: App only reads local files (except Sparkle updates)

## Troubleshooting

### Widget not showing status

1. Verify hooks are configured (Settings > General > Integration)
2. Restart Claude Code after configuring
3. Check `/tmp` for `vibestatus-*.json` files

### Status stuck on "Working"

The session may have crashed. Status files auto-expire after 5 minutes, or restart the app.

### Multiple sessions not tracked

Each Claude Code terminal needs a unique session ID. Check that `~/.claude/hooks/vibestatus.sh` exists and is executable.

## License

MIT License - see LICENSE file for details.

## Credits

Created by Vladimir Babic.

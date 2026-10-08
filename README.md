# Veil

A macOS menu bar app that plays a video of your choice as a faint, looping,
click-through layer over your entire screen. You keep working underneath it;
the overlay never takes a click, a keystroke or focus.

## Build & run

Requires macOS 14 or later and the Xcode Command Line Tools (Swift 5.9+).

```sh
make app        # builds build/Veil.app (release)
make run        # builds and launches it
make install    # copies it to /Applications (needed for "Launch at login")
```

The build script compiles with SwiftPM, renders the app icon from
`Tools/make-icon.swift`, assembles the `.app` bundle and ad-hoc signs it.
No third-party dependencies, no Xcode project.

## Using it

Veil lives in the menu bar. On first launch it opens Settings so you can
drop in a video. After that:

| Action | How |
| --- | --- |
| Quick controls (show/hide, play/pause, opacity, volume) | Click the menu bar icon |
| Toggle the overlay instantly | ⌥-click the icon, or press **⌃⌥⌘V** anywhere |
| Quick menu | Right-click the icon |
| Settings | Menu bar panel → Settings…, or ⌘, |
| Replace the video | Drop a file on the Settings window or the menu bar panel, or "Open With → Veil" in Finder |

## What's in Settings

**Video** – current video with poster frame, duration, resolution, file size
and audio-track check; recent videos for quick switching.

**Appearance** – opacity, saturation, blur, scaling (fill / fit / stretch),
which display(s) to cover, whether the overlay sits above everything or below
the menu bar and Dock, and an option to hide it from screenshots and screen
sharing.

**Playback** – show/hide, play/pause, speed (0.25×–2×, pitch-corrected),
automatic pause while the screen is locked or asleep, and a volume slider plus
mute that affect only the overlay video. System volume is never touched.

**General** – launch at login, Dock icon, and a configurable global shortcut.

## How it works

- One `NSPanel` per display: borderless, non-activating, `ignoresMouseEvents`,
  present on every Space and over full-screen apps.
- A single `AVQueuePlayer` + `AVPlayerLooper` drives every display's
  `AVPlayerLayer`, so the video is decoded once and stays in sync everywhere.
- Opacity is window alpha (composited by WindowServer, effectively free);
  saturation and blur are Core Image layer filters.
- The player is configured so it never keeps your display awake.
- The global shortcut uses Carbon hot keys, so no Accessibility permission is
  needed. Veil asks for no permissions at all.

## Layout

```
Sources/Veil/
  App/      entry point, app delegate, main menu, debug snapshot helper
  Model/    AppModel (state + persistence), value types, video metadata
  Engine/   overlay windows, player engine, hot keys, system events, login item
  UI/       menu bar controller, settings window, SwiftUI panes & components
Resources/Info.plist
Tools/make-icon.swift
build.sh, Makefile
```

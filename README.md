# Quiet Front

A free-to-play, calm tactical first-person shooter for Android with LAN multiplayer
(2–20 players). One phone hosts over its hotspot or a shared Wi-Fi network, other phones
find it automatically. No internet, accounts or servers are needed.

Working title and package id (`com.quietfront.game`) can be changed later in
`project.godot` and `export_presets.cfg`.

## Quick start

1. Put the whole repository on GitHub (private).
2. Open the **Actions** tab, choose **Build Android APK**, press **Run workflow**.
3. When the run finishes, download an APK from **Artifacts** at the bottom of the run page.
4. Install it on your phone.

Full instructions: [docs/BUILD.md](docs/BUILD.md)

## Documentation

| File | Contents |
|---|---|
| [docs/BUILD.md](docs/BUILD.md) | How the build works, downloading and installing APKs, troubleshooting |
| [docs/TESTING.md](docs/TESTING.md) | Real-device test checklists for each phase |
| [docs/ASSETS.md](docs/ASSETS.md) | Asset rules and the license ledger |
| [docs/SIGNING.md](docs/SIGNING.md) | Test signing now, production signing later |

## Project layout

```
game/        GDScript source (autoload/, net/, ui/, match/, player/, weapons/, bombs/, pickups/, maps/)
data/        Balance and map layout data (JSON)
shaders/     Shaders
assets/      Downloaded models, textures and audio (one folder per pack)
tools/       CI scripts (build setup, icon generation, validation, tests)
tests/       Headless logic tests
docs/        Documentation
```

## Changing the code

Edit the files in a text editor, upload the changes to GitHub, and run the workflow again.
Your PC never compiles anything; GitHub Actions does all of it.

## Engine

Godot 4.6.3 (GDScript), Compatibility renderer, Android 10 or newer, arm64-v8a and
armeabi-v7a.
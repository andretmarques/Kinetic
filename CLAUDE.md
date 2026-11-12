# Kinetic

A macOS 26 app that makes a PC mouse and keyboard feel native on the Mac ([README](README.md)).

## Where things live

| Part | Its one job | Path |
|---|---|---|
| `KineticDomain` | Pure logic and models, no system I/O | [Sources/KineticDomain](Sources/KineticDomain) |
| `KineticInfrastructure` | The system I/O: config file, agent channel, processes | [Sources/KineticInfrastructure](Sources/KineticInfrastructure) |
| `Kinetic` | The settings app (executable) | [Sources/Kinetic](Sources/Kinetic) |
| `KineticAgent` | The background login item that applies the settings (executable) | [Sources/KineticAgent](Sources/KineticAgent) |
| `KineticMenuBar` | The menu bar icon and panel, a dynamic library the agent loads | [Sources/KineticMenuBar](Sources/KineticMenuBar) |
| Tests | `KineticDomainTests`, `KineticInfrastructureTests` | [Tests](Tests) |
| `Scripts/` | `release.sh` publishes a version; `make-icon.swift` renders the app icon | [Scripts](Scripts) |
| `Packaging/` | The Info.plists, the agent's launch plist and the icon that `build.sh` copies into the app | [Packaging](Packaging) |
| `ReleaseNotes/` | One file per release, named after its version (the tag without a leading `v`) | [ReleaseNotes](ReleaseNotes) |
| CI | Tests and builds every push to `main`; a release tag also publishes the DMG | [.github/workflows/build.yml](.github/workflows/build.yml) |

## Commands

- Test: `swift test`. On a Mac with Command Line Tools and no Xcode, the macro plugins are not found, so run `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk swift test -Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing`.
- Build the app: `./build.sh` (debug, this Mac's architecture) or `./build.sh release` (universal). Output is `build/Kinetic.app` ([build.sh](build.sh)). Open it only when the user asks: it has the installed app's bundle id, so it replaces the running agent and uses the user's live settings.
- Release, only when the user asks: `Scripts/release.sh <version>` pushes `main` and a tag, and CI then publishes a public DMG. Read the header of [Scripts/release.sh](Scripts/release.sh) first: the notes file it needs must already be on `main`.

## Status

The latest release is the newest git tag (`git tag --sort=-creatordate | head -1`). What it shipped is in `ReleaseNotes/<version>.md` (the tag without a leading `v`).

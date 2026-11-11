# Sure Footing

A round of fixes for the places where Kinetic could quietly do the wrong thing: lose your profiles, stop running, or send a key you didn't ask for. No new features.

## Your settings are safer

- **One bad entry no longer wipes your mouse and keyboard profiles.** If a single mouse or keyboard entry in the config was damaged, Kinetic used to fall back to defaults for everything and then save them over your file. It now drops only the damaged entry and keeps the rest.
- **The Kinetic Agent switch matches the login item.** Import and Reset to defaults could leave the switch saying off while the agent still ran, or on while nothing was registered. If macOS refuses the change, the switch now goes back to what macOS reports.

## The agent stays running

- **Updating Kinetic no longer risks stopping the agent.** Replacing `Kinetic.app` could look like a removal for a moment, so the agent quit and was never restarted. It now needs two checks in a row, about 10 seconds apart, before it decides the app is gone.
- **A failed relaunch keeps Settings open.** Before, Settings closed anyway and the repair spinner never finished.

## Keys and buttons

- **The Fn substitute key respects Pause.** With Kinetic paused, Right Control + F2 now reaches the app as written instead of plain F2. Pausing, or losing the keyboard that uses Mac F-keys, also ends a flipped F-key lock, so the menu no longer says "Flipped" when it isn't.
- **Actions that can't run now beep.** Three cases did something else:
  - A system shortcut you turned off in System Settings (such as "Move left a space") still sent its default key combo. It now beeps.
  - Middle Click and Right Click mapped to an F-key swallowed the key silently. The F-key picker no longer offers them, and a saved one beeps.
  - A hand-edited desktop number outside 1 to 16 could fire an unrelated shortcut such as Spotlight. It now beeps.

## Menu bar

- **The speed slider and acceleration toggle reach every connected mouse.** With two or more mice, any mouse that had its own profile ignored them. They now apply to every attached, enabled mouse that has a profile.

## Worth knowing

- Moving the menu slider with several mice attached overwrites any per-mouse speed you set in Settings.
- If you turned off Command+Space for another launcher such as Raycast or Alfred, F4 in Mac F-key mode now beeps instead of opening it.
- Release builds now fail on a bad code signature, and a release tag must match the app version.

## Install

1. [Download `Kinetic.dmg`](https://github.com/andretmarques/Kinetic/releases/download/alpha-1.3/Kinetic.dmg), open it and drag **Kinetic** to **Applications**.
2. Open Kinetic, then turn on **Kinetic Agent** under **Accessibility** and **Input Monitoring** if asked.

Requires macOS 26 or later. Runs on Apple silicon and Intel.

This is an alpha, so expect rough edges and please report what you find.

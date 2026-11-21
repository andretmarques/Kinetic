# Through the Lock

Mac F-keys could stop working, most often after a restart. The cause was macOS Secure Input. While an app holds it, macOS hides every key press from Kinetic. Password managers, a terminal's Secure Keyboard Entry and open password fields all turn it on. This release keeps the media keys working through it and tells you when it's on.

## F-keys under Secure Input

- **Brightness, media and volume F-keys keep working while Secure Input is on.** Kinetic now remaps these keys on the keyboard itself, below the point where macOS hides key presses. This covers F1, F2 and F7 to F12 in Mac F-key mode.
- **Holding the Fn substitute still sends the standard F-key.** Right Control + F11 sends F11 instead of turning the volume down, even with the remap in place. Held keys repeat the way a real F-key does.

## Seeing when it's on

- **The menu bar says "Secure Input is on"** in place of "Kinetic is active".
- **The Keyboard settings show a warning** that says which F-keys still work in your current mode and what usually turns Secure Input on.

## Worth knowing

- F3 to F6 (Mission Control, Spotlight, Dictation and Launchpad) and the double-tap to flip the F-key lock still wait until Secure Input turns off. macOS offers no way to remap them below the event tap.
- Closing or quitting the app that holds Secure Input turns it off. Locking the screen doesn't help. A password manager such as Proton Pass is a common cause.
- Brightness keys only change Apple displays. External monitors ignore them.
- Kinetic now sets the keyboard's key remapping on every PC keyboard that uses Mac F-keys, not only those with Alt and Win swapped. If you remap keys yourself with `hidutil`, Kinetic replaces that mapping on those keyboards.

## Install

1. [Download `Kinetic.dmg`](https://github.com/andretmarques/Kinetic/releases/download/alpha-1.4/Kinetic.dmg), open it and drag **Kinetic** to **Applications**.
2. Open Kinetic, then turn on **Kinetic Agent** under **Accessibility** and **Input Monitoring** if asked.

Requires macOS 26 or later. Runs on Apple silicon and Intel.

This is an alpha, so expect rough edges and please report what you find.

extension KineticConfig {
    /// What still works while an app holds Secure Input, which hides key presses but not the keyboard's HID mapping.
    public func secureInputWarning(fnLocked: Bool) -> String {
        let mapped = keyboards.values.contains(where: \.macFunctionKeys) && (keyboard.fKeyMode == .mac) != fnLocked
        let waiting = keyboard.fnSubstitute == .none ? "other F-key actions" : "other F-key actions and \(keyboard.fnSubstitute.title)"
        let status = mapped
            ? "Brightness, media and volume F-keys still work; \(waiting) wait until it turns off."
            : "F-key actions wait until it turns off."
        return "An app has Secure Input on, so macOS hides key presses from Kinetic. \(status) "
            + "Password managers, a terminal's Secure Keyboard Entry and open password fields turn it on; closing or quitting that app turns it off."
    }
}

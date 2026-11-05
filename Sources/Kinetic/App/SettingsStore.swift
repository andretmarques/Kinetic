import KineticDomain
import SwiftUI

typealias SettingsStore = Store<SettingsReducer>

extension Store where R == SettingsReducer {
    func binding<Value>(
        _ value: @escaping (SettingsState) -> Value,
        send intent: @escaping (Value) -> SettingsIntent
    ) -> Binding<Value> {
        Binding(
            get: { value(self.state) },
            set: { self.send(intent($0)) }
        )
    }

    func edit<Value>(
        _ value: @escaping (SettingsState) -> Value,
        _ edit: @escaping (Value) -> ConfigEdit
    ) -> Binding<Value> {
        binding(value) { .edit(edit($0)) }
    }
}

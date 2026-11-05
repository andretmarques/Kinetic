import Observation

public protocol Reducer {
    associatedtype State
    associatedtype Intent
    associatedtype Effect

    static func reduce(_ state: inout State, _ intent: Intent) -> [Effect]
}

/// The one place state changes: an intent goes through a pure reducer, and any resulting effects
/// are handed to the outside world, which reports back with more intents.
@MainActor
@Observable
public final class Store<R: Reducer> {
    public private(set) var state: R.State

    @ObservationIgnored
    public var effectHandler: ((R.Effect) -> Void)?

    public init(initialState: R.State) {
        state = initialState
    }

    public func send(_ intent: R.Intent) {
        let effects = R.reduce(&state, intent)
        for effect in effects {
            effectHandler?(effect)
        }
    }
}

import Dispatch

MainActor.assumeIsolated {
    AgentController().run()
}

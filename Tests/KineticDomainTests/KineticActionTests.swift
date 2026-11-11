import Testing
@testable import KineticDomain

@Suite struct KineticActionTests {
    @Test func functionKeysOfferNoMouseButtonClicks() {
        let actions = KineticAction.functionKeyCatalog
        #expect(!actions.contains(.middleClick))
        #expect(!actions.contains(.rightClick))
        #expect(actions.contains(.doubleClick))
        #expect(actions.contains(.passThrough))
        #expect(actions.contains(.none))
    }
}

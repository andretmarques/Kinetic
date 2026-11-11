import Testing
@testable import KineticInfrastructure

@Suite struct AppRemovalCheckTests {
    private let installed = "/Applications/Kinetic.app/Contents/MacOS/KineticAgent"
    private let trashed = "/Users/me/.Trash/Kinetic.app/Contents/MacOS/KineticAgent"

    private func isRemoved(launch: String?, current: String?, existing: Set<String>) -> Bool {
        AppRemovalCheck.isRemoved(launchPath: launch, currentPath: current) { existing.contains($0) }
    }

    @Test func staysWhenNothingMoved() {
        #expect(!isRemoved(launch: installed, current: installed, existing: [installed]))
    }

    @Test func removedWhenMovedToTrash() {
        #expect(isRemoved(launch: installed, current: trashed, existing: [trashed]))
    }

    @Test func removedWhenMovedToTrashOnAnotherVolume() {
        let path = "/Volumes/Disk/.Trashes/501/Kinetic.app/Contents/MacOS/KineticAgent"
        #expect(isRemoved(launch: "/Volumes/Disk/Kinetic.app/Contents/MacOS/KineticAgent", current: path, existing: [path]))
    }

    @Test func removedWhenDeleted() {
        #expect(isRemoved(launch: installed, current: nil, existing: []))
        #expect(isRemoved(launch: installed, current: trashed, existing: []))
    }

    @Test func removedWhenLaunchedFromTrashAtLogin() {
        #expect(isRemoved(launch: trashed, current: trashed, existing: [trashed]))
    }

    @Test func staysWhenMovedToAnotherFolder() {
        let moved = "/Users/me/Apps/Kinetic.app/Contents/MacOS/KineticAgent"
        #expect(!isRemoved(launch: installed, current: moved, existing: [moved]))
    }

    @Test func staysWhenReplacedByNewVersion() {
        #expect(!isRemoved(launch: installed, current: trashed, existing: [installed, trashed]))
        #expect(!isRemoved(launch: installed, current: nil, existing: [installed]))
    }

    @Test func oneRemovedSampleIsNotConfirmed() {
        var check = AppRemovalCheck()
        let confirmed = check.confirm(true)
        #expect(!confirmed)
    }

    @Test func twoRemovedSamplesInARowConfirm() {
        var check = AppRemovalCheck()
        _ = check.confirm(true)
        let confirmed = check.confirm(true)
        #expect(confirmed)
    }

    @Test func aPresentSampleResetsConfirmation() {
        var check = AppRemovalCheck()
        _ = check.confirm(true)
        _ = check.confirm(false)
        let confirmed = check.confirm(true)
        #expect(!confirmed)
    }
}

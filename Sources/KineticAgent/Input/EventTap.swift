import ApplicationServices
import Foundation
import KineticDomain
import KineticInfrastructure
import os

/// Owns the CGEventTap on its own thread, so work on the main thread can never stall input.
/// Every decision is made by `InputRouter`; this class only translates to and from CGEvent.
final class EventTap: @unchecked Sendable {
    private struct Shared {
        var rules = InputRules()
        var learnUntil: TimeInterval = 0
        var isActive = false
        var isLocked = false
        var tap: CFMachPort?
    }

    private static let learnLease: TimeInterval = 2.5
    private static let retryInterval: TimeInterval = 2
    private static let eventMask: CGEventMask = [
        CGEventType.scrollWheel, .otherMouseDown, .otherMouseUp, .otherMouseDragged, .keyDown, .keyUp, .flagsChanged,
    ].reduce(0) { $0 | (1 << $1.rawValue) }

    private let actions: ActionRunner
    private let shared = OSAllocatedUnfairLock(initialState: Shared())
    private var router = InputRouter()

    var onStateChange: (@Sendable () -> Void)?

    init(actions: ActionRunner) {
        self.actions = actions
    }

    var isActive: Bool {
        shared.withLock { state in
            guard state.isActive, let tap = state.tap else { return false }
            return CGEvent.tapIsEnabled(tap: tap)
        }
    }

    var isLocked: Bool {
        shared.withLock { $0.isLocked }
    }

    func start() {
        let thread = Thread { [self] in
            run()
        }
        thread.name = "kinetic.eventtap"
        thread.qualityOfService = .userInteractive
        thread.start()
    }

    func update(rules: InputRules) {
        let lockCleared = shared.withLock { state in
            state.rules = rules
            let cleared = state.isLocked && rules.substituteKeyCode == nil
            if cleared {
                state.isLocked = false
            }
            return cleared
        }
        if lockCleared {
            onStateChange?()
        }
    }

    func renewLearnMode() {
        let expiry = ProcessInfo.processInfo.systemUptime + Self.learnLease
        shared.withLock { $0.learnUntil = expiry }
    }

    func stopLearnMode() {
        shared.withLock { $0.learnUntil = 0 }
    }

    func reviveIfDisabled() {
        let tap = shared.withLock { $0.tap }
        if let tap, !CGEvent.tapIsEnabled(tap: tap) {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    private func run() {
        let tap = createTapWhenPermitted()
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        shared.withLock { state in
            state.tap = tap
            state.isActive = true
        }
        onStateChange?()
        CFRunLoopRun()
    }

    private func createTapWhenPermitted() -> CFMachPort {
        var failuresWithPermission = 0
        while true {
            if let tap = makeTap() {
                return tap
            }
            if AXIsProcessTrusted() && CGPreflightListenEventAccess() {
                failuresWithPermission += 1
                // macOS can refuse a process granted access after launch; launchd starts a fresh one.
                if failuresWithPermission >= 2 {
                    exit(EXIT_FAILURE)
                }
            }
            Thread.sleep(forTimeInterval: Self.retryInterval)
        }
    }

    private func makeTap() -> CFMachPort? {
        CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: Self.eventMask,
            callback: { _, type, event, context in
                Unmanaged<EventTap>.fromOpaque(context!).takeUnretainedValue().handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            reviveIfDisabled()
            router.tapWasReenabled()
            return Unmanaged.passUnretained(event)
        }
        if event.getIntegerValueField(.eventSourceUserData) == EventPoster.tag {
            return Unmanaged.passUnretained(event)
        }

        let context = makeContext()
        switch type {
        case .otherMouseDown:
            return handleButton(event, phase: .down, context: context)
        case .otherMouseDragged:
            return handleButton(event, phase: .dragged, context: context)
        case .otherMouseUp:
            return handleButton(event, phase: .up, context: context)
        case .keyDown:
            return handleKey(event, isDown: true, context: context)
        case .keyUp:
            return handleKey(event, isDown: false, context: context)
        case .flagsChanged:
            handleFlags(event, context: context)
        case .scrollWheel where context.rules.isEnabled:
            rewriteScroll(event, rules: context.rules)
        default:
            break
        }
        return Unmanaged.passUnretained(event)
    }

    private func makeContext() -> InputContext {
        let now = ProcessInfo.processInfo.systemUptime
        return shared.withLock { state in
            InputContext(rules: state.rules, isLearning: state.learnUntil > now, isLocked: state.isLocked)
        }
    }

    private func handleButton(_ event: CGEvent, phase: ButtonPhase, context: InputContext) -> Unmanaged<CGEvent>? {
        let button = Int(event.getIntegerValueField(.mouseEventButtonNumber))
        let (route, command) = router.routeButton(button, phase: phase, context: context)
        perform(command, location: event.location)

        switch route {
        case .pass:
            break
        case .swallow:
            return nil
        case .asMiddle:
            event.setIntegerValueField(.mouseEventButtonNumber, value: 2)
        case .asRight:
            event.type = switch phase {
            case .down: .rightMouseDown
            case .dragged: .rightMouseDragged
            case .up: .rightMouseUp
            }
            event.setIntegerValueField(.mouseEventButtonNumber, value: 1)
        }
        return Unmanaged.passUnretained(event)
    }

    private func handleKey(_ event: CGEvent, isDown: Bool, context: InputContext) -> Unmanaged<CGEvent>? {
        let (route, command) = router.routeKey(
            code: UInt16(event.getIntegerValueField(.keyboardEventKeycode)),
            isDown: isDown,
            isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0,
            flags: event.flags.rawValue,
            context: context
        )
        perform(command, location: nil)

        switch route {
        case .pass:
            break
        case .swallow:
            return nil
        case let .passWithFlags(flags):
            event.flags = CGEventFlags(rawValue: flags)
        }
        return Unmanaged.passUnretained(event)
    }

    private func handleFlags(_ event: CGEvent, context: InputContext) {
        let didFlip = router.routeFlags(
            keyCode: UInt16(event.getIntegerValueField(.keyboardEventKeycode)),
            flags: event.flags.rawValue,
            now: ProcessInfo.processInfo.systemUptime,
            context: context
        )
        if didFlip {
            shared.withLock { $0.isLocked.toggle() }
            onStateChange?()
        }
    }

    private func rewriteScroll(_ event: CGEvent, rules: InputRules) {
        let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        let hasPhase = event.getIntegerValueField(.scrollWheelEventScrollPhase) != 0
            || event.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0
        guard !isContinuous, !hasPhase else { return }

        rewriteAxis(
            event,
            delta: .scrollWheelEventDeltaAxis1,
            points: .scrollWheelEventPointDeltaAxis1,
            fixed: .scrollWheelEventFixedPtDeltaAxis1,
            multiplier: rules.scrollMultiplier,
            invert: rules.reverseVertical
        )
        rewriteAxis(
            event,
            delta: .scrollWheelEventDeltaAxis2,
            points: .scrollWheelEventPointDeltaAxis2,
            fixed: .scrollWheelEventFixedPtDeltaAxis2,
            multiplier: rules.scrollMultiplier,
            invert: rules.reverseHorizontal
        )
    }

    private func rewriteAxis(
        _ event: CGEvent,
        delta: CGEventField,
        points: CGEventField,
        fixed: CGEventField,
        multiplier: Double?,
        invert: Bool
    ) {
        let scale = (multiplier ?? 1) * (invert ? -1 : 1)

        // Writing the line delta makes macOS recalculate the other two, so all three are read first.
        let originalLines = Double(event.getIntegerValueField(delta))
        let originalPoints = event.getDoubleValueField(points)
        let originalFixed = event.getDoubleValueField(fixed)

        event.setIntegerValueField(delta, value: Int64((originalLines * scale).rounded(.awayFromZero)))
        event.setDoubleValueField(points, value: originalPoints * scale)
        event.setDoubleValueField(fixed, value: originalFixed * scale)
    }

    private func perform(_ command: InputCommand?, location: CGPoint?) {
        guard let command else { return }
        let actions = actions
        DispatchQueue.main.async {
            switch command {
            case let .run(action):
                actions.run(action, at: location)
            case let .reportButton(button):
                AgentChannel.post(.buttonPressed, payload: String(button))
            }
        }
    }
}

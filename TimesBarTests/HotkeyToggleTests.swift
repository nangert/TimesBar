import Testing
import Foundation
@testable import TimesBar

// MARK: - toggleTimerAction decision logic

@Test func toggleTimerAction_stopWhenRunning() {
    // A timer is running → action must be .stop regardless of recent entries.
    let action = TimerStore.toggleTimerAction(isRunning: true, recentIds: [42, 7])
    #expect(action == .stop)
}

@Test func toggleTimerAction_stopWhenRunningAndNoRecent() {
    let action = TimerStore.toggleTimerAction(isRunning: true, recentIds: [])
    #expect(action == .stop)
}

@Test func toggleTimerAction_resumeMostRecentWhenIdle() {
    // No timer running, recent list has entries → resume the first (most recent) one.
    let action = TimerStore.toggleTimerAction(isRunning: false, recentIds: [99, 12, 3])
    #expect(action == .resume(id: 99))
}

@Test func toggleTimerAction_noOpWhenIdleAndNoRecent() {
    // No timer running, no recent entries → nothing to do.
    let action = TimerStore.toggleTimerAction(isRunning: false, recentIds: [])
    #expect(action == .noOp)
}

@Test func toggleTimerAction_resumesSingleRecentEntry() {
    let action = TimerStore.toggleTimerAction(isRunning: false, recentIds: [5])
    #expect(action == .resume(id: 5))
}

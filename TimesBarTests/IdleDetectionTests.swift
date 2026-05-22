import Testing
import Foundation
@testable import TimesBar

// MARK: - idleStartedAt pure helper

@Test func idleStartedAtReturnsNowMinusSecondsIdle() {
    let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
    let secondsIdle: TimeInterval = 300
    let result = TimerStore.idleStartedAt(now: now, secondsIdle: secondsIdle)
    #expect(result == now - secondsIdle)
}

// MARK: - IdleMonitor.didCrossThreshold pure helper

@Test func didCrossThresholdReturnsFalseWhenPreviousIsNil() {
    #expect(IdleMonitor.didCrossThreshold(previous: nil, current: 900, threshold: 900) == false)
}

@Test func didCrossThresholdReturnsFalseWhenBothBelowThreshold() {
    #expect(IdleMonitor.didCrossThreshold(previous: 100, current: 800, threshold: 900) == false)
}

@Test func didCrossThresholdReturnsFalseWhenBothAboveThreshold() {
    #expect(IdleMonitor.didCrossThreshold(previous: 950, current: 1000, threshold: 900) == false)
}

@Test func didCrossThresholdReturnsTrueWhenCrossingUpward() {
    // previous was 800 (below), current is 900 (at threshold)
    #expect(IdleMonitor.didCrossThreshold(previous: 800, current: 900, threshold: 900) == true)
}

@Test func didCrossThresholdReturnsTrueWhenCurrentExceedsThreshold() {
    #expect(IdleMonitor.didCrossThreshold(previous: 800, current: 950, threshold: 900) == true)
}

@Test func didCrossThresholdReturnsFalseWhenCurrentJustBelowThreshold() {
    #expect(IdleMonitor.didCrossThreshold(previous: 800, current: 899, threshold: 900) == false)
}

// MARK: - handleIdleCrossedThreshold on TimerStore

@MainActor
@Test func handleIdleDoesNotSetPromptWhenNoActiveTimer() {
    let store = TimerStore()
    // active is nil by default
    store.handleIdleCrossedThreshold(secondsIdle: 900)
    #expect(store.pendingIdlePrompt == nil)
}

@MainActor
@Test func handleIdleDoesNotSetPromptWhenIdleStartBeforeTimerBegin() {
    let store = TimerStore()
    let begin = Date(timeIntervalSinceReferenceDate: 1_000_000)
    // Simulate a running entry that began at t=1_000_000
    let entry = TimesheetEntity(id: 1, project: 10, activity: 20,
                                begin: begin, end: nil, description: "work")
    store.active = entry

    // Compute parameters so that idleStart = now - secondsIdle falls before begin.
    // now = begin + 100, secondsIdle = 200 → idleStart = begin - 100 (before begin)
    let now = begin.addingTimeInterval(100)
    store.handleIdleCrossedThreshold(secondsIdle: 200, now: now)
    #expect(store.pendingIdlePrompt == nil)
}

@MainActor
@Test func handleIdleSetsPromptCorrectlyWhenTimerIsRunning() {
    let store = TimerStore()
    let begin = Date(timeIntervalSinceReferenceDate: 1_000_000)
    let entry = TimesheetEntity(id: 7, project: 3, activity: 5,
                                begin: begin, end: nil, description: "coding",
                                tags: ["focus"])
    store.active = entry

    // now = begin + 1800, secondsIdle = 900 → idleStart = begin + 900 (after begin)
    let now = begin.addingTimeInterval(1800)
    store.handleIdleCrossedThreshold(secondsIdle: 900, now: now)

    let prompt = store.pendingIdlePrompt
    #expect(prompt != nil)
    #expect(prompt?.runningEntryId == 7)
    #expect(prompt?.project == 3)
    #expect(prompt?.activity == 5)
    #expect(prompt?.description == "coding")
    #expect(prompt?.tags == ["focus"])
    // idleStart should equal now - secondsIdle
    #expect(prompt?.idleStart == now.addingTimeInterval(-900))
}

@MainActor
@Test func handleIdleSetsPromptWhenIdleStartEqualsTimerBegin() {
    // Edge: idleStart == entry.begin — exactly at the boundary, should be accepted
    // (guard is idleStart >= entry.begin).
    let store = TimerStore()
    let begin = Date(timeIntervalSinceReferenceDate: 1_000_000)
    let entry = TimesheetEntity(id: 99, project: 1, activity: 2,
                                begin: begin, end: nil, description: nil)
    store.active = entry

    // now = begin + 900, secondsIdle = 900 → idleStart = begin (exactly equal)
    let now = begin.addingTimeInterval(900)
    store.handleIdleCrossedThreshold(secondsIdle: 900, now: now)
    #expect(store.pendingIdlePrompt != nil)
}

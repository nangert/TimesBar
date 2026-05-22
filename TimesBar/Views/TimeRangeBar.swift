import SwiftUI
import AppKit

/// Horizontal drag-to-set time range strip used by the past-entry and
/// edit-active forms. Spans 12 hours: for today, the window is
/// `[now − 10h, now + 2h]` (so "now" sits at the 10/12 position); for other
/// days the window is `[09:00, 21:00]` of the selected day.
///
/// Selected interval renders as a green band with grab handles. Drag a handle
/// to resize, drag the band to translate both endpoints. All edits snap to
/// 5-minute boundaries; the parent form provides ±1-minute nudge buttons for
/// fine-tuning.
///
/// Modes:
/// - `.range`: both handles are draggable. End is required (non-nil).
/// - `.beginOnly`: only the begin handle is draggable; the band extends to
///   "now" (or the window end for non-today). Used by the edit-active form.
struct TimeRangeBar: View {
    enum Mode { case range, beginOnly }

    let day: Date
    let mode: Mode
    @Binding var begin: Date
    /// Only used in `.range` mode. Ignored in `.beginOnly`.
    @Binding var end: Date

    /// Existing timesheets to render as muted blocks behind the selected band
    /// — so the user can see what's already logged in the window and avoid
    /// double-logging or overlapping. Entries fully outside the window are
    /// skipped; entries partially inside are clipped at the window bounds.
    var existingEntries: [TimesheetEntity] = []

    /// Timesheet ID to exclude from `existingEntries` rendering — typically
    /// the active timer's own row in the edit-active form, since drawing it
    /// as a muted block on top of the green selection is just visual noise.
    var excludeEntryId: Int? = nil

    /// Maps a project ID to its display color. Passed as a closure so the bar
    /// remains testable without a full TimerStore dependency.
    var colorForProject: (Int) -> Color = { id in Color.forProject(id: id, hex: nil) }

    /// Snap resolution while dragging.
    private let snapSeconds: TimeInterval = 300

    @State private var dragTarget: DragTarget?
    @State private var dragStartBegin: Date = .distantPast
    @State private var dragStartEnd: Date = .distantPast

    private enum DragTarget { case beginHandle, endHandle, band }

    private static let cal: Calendar = {
        var c = Calendar(identifier: .iso8601)
        c.timeZone = .current
        return c
    }()
    private var cal: Calendar { Self.cal }

    /// Window the strip represents. For today: `[now−10h, now+2h]`. For other
    /// days: `[09:00, 21:00]` of that day.
    var window: (start: Date, end: Date) {
        let now = Date()
        if cal.isDateInToday(day) {
            return (now.addingTimeInterval(-10 * 3600),
                    now.addingTimeInterval(2 * 3600))
        }
        let startOfDay = cal.startOfDay(for: day)
        let start = cal.date(byAdding: .hour, value: 9, to: startOfDay) ?? startOfDay
        let end = cal.date(byAdding: .hour, value: 21, to: startOfDay) ?? startOfDay
        return (start, end)
    }

    private var nowMarker: Date? {
        cal.isDateInToday(day) ? Date() : nil
    }

    /// Visual end position. In `.range` mode this is the bound `end`. In
    /// `.beginOnly` mode the band extends to "now" (today) or the window end.
    private var visualEnd: Date {
        switch mode {
        case .range: return end
        case .beginOnly: return nowMarker ?? window.end
        }
    }

    var body: some View {
        GeometryReader { geo in
            let win = window
            let total = win.end.timeIntervalSince(win.start)
            let width = geo.size.width

            ZStack(alignment: .topLeading) {
                // Track
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.primary.opacity(0.07))
                    .frame(height: 32)
                    .offset(y: 10)

                // Existing entries — drawn behind the selected band so the
                // user can see what's already logged in the window.
                ForEach(visibleExistingEntries, id: \.id) { entry in
                    let entryBegin = max(entry.begin, win.start)
                    let entryEnd = min(entry.end ?? Date(), win.end)
                    if entryEnd > entryBegin {
                        let x1 = xPos(for: entryBegin, in: win, total: total, width: width)
                        let x2 = xPos(for: entryEnd, in: win, total: total, width: width)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(colorForProject(entry.project).opacity(0.28))
                            .frame(width: max(2, x2 - x1), height: 18)
                            .offset(x: x1, y: 17)
                            .help(entryTooltip(entry))
                    }
                }

                // Hour ticks + labels
                ForEach(hourTicks(in: win), id: \.self) { tick in
                    let x = xPos(for: tick, in: win, total: total, width: width)
                    let hour = cal.component(.hour, from: tick)
                    let major = hour % 3 == 0
                    Rectangle()
                        .fill(Color.secondary.opacity(major ? 0.45 : 0.25))
                        .frame(width: major ? 1 : 1, height: major ? 10 : 6)
                        .offset(x: x - 0.5, y: 42 - (major ? 10 : 6))
                    if major {
                        Text(String(format: "%02d", hour))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, alignment: .center)
                            .offset(x: x - 11, y: 44)
                    }
                }

                // "Now" marker — only on today
                if let now = nowMarker {
                    let x = xPos(for: now, in: win, total: total, width: width)
                    Rectangle()
                        .fill(Color.kimaiGreen.opacity(0.6))
                        .frame(width: 1.5, height: 38)
                        .offset(x: x - 0.75, y: 7)
                    Text("now")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.kimaiGreen)
                        .offset(x: x - 12, y: -2)
                }

                // Selected band
                let beginX = xPos(for: begin, in: win, total: total, width: width)
                let endX = xPos(for: visualEnd, in: win, total: total, width: width)
                let bandWidth = max(2, endX - beginX)
                let overlapping = mode == .range
                    && overlapsAnyExisting(begin: begin, end: end)
                RoundedRectangle(cornerRadius: 5)
                    .fill(overlapping
                          ? Color.kimaiStopTint.opacity(0.45)
                          : Color.kimaiGreen.opacity(0.35))
                    .frame(width: bandWidth, height: 28)
                    .offset(x: beginX, y: 12)
                    .overlay(
                        // Subtle right-edge stripe when running (beginOnly)
                        Group {
                            if mode == .beginOnly {
                                LinearGradient(
                                    colors: [Color.kimaiGreen.opacity(0), Color.kimaiGreen.opacity(0.5)],
                                    startPoint: .leading, endPoint: .trailing)
                                    .frame(width: min(28, bandWidth), height: 28)
                                    .offset(x: beginX + bandWidth - min(28, bandWidth), y: 12)
                            }
                        }
                    )

                // Begin handle
                handle(at: beginX, label: "begin")

                // End handle (only in .range)
                if mode == .range {
                    handle(at: endX, label: "end")
                }
            }
            .frame(height: 60)
            .contentShape(Rectangle())
            .gesture(dragGesture(win: win, total: total, width: width))
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case .active(let loc):
                    // Don't override the closed-hand cursor mid-drag.
                    if dragTarget == .band { return }
                    switch target(at: loc.x, in: win, total: total, width: width) {
                    case .beginHandle, .endHandle:
                        NSCursor.resizeLeftRight.set()
                    case .band:
                        NSCursor.openHand.set()
                    case nil:
                        NSCursor.arrow.set()
                    }
                case .ended:
                    if dragTarget != .band { NSCursor.arrow.set() }
                }
            }
        }
        .frame(height: 60)
    }

    private func handle(at x: CGFloat, label: String) -> some View {
        ZStack {
            Capsule()
                .fill(Color.kimaiGreen)
                .frame(width: 10, height: 36)
            Capsule()
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
                .frame(width: 10, height: 36)
        }
        .frame(width: 24, height: 40) // generous tap target around the visual
        .contentShape(Rectangle())
        .offset(x: x - 12, y: 10)
        .help(label)
    }

    /// Existing entries that overlap the window, with the excluded ID dropped.
    /// Computed once per render to avoid recomputation inside the ForEach.
    private var visibleExistingEntries: [TimesheetEntity] {
        let win = window
        return existingEntries.filter { entry in
            if let excludeEntryId, entry.id == excludeEntryId { return false }
            let entryEnd = entry.end ?? Date()
            return entry.begin < win.end && entryEnd > win.start
        }
    }

    private func entryTooltip(_ entry: TimesheetEntity) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        let begin = f.string(from: entry.begin)
        let end = entry.end.map(f.string(from:)) ?? "running"
        if let desc = entry.description, !desc.isEmpty {
            return "\(begin) — \(end)  \(desc)"
        }
        return "\(begin) — \(end)"
    }

    private func hourTicks(in win: (start: Date, end: Date)) -> [Date] {
        var ticks: [Date] = []
        // Round start up to the next whole hour
        let startHour = cal.component(.hour, from: win.start)
        guard var t = cal.date(bySettingHour: startHour, minute: 0, second: 0, of: win.start) else {
            return []
        }
        if t < win.start { t = cal.date(byAdding: .hour, value: 1, to: t) ?? t }
        while t <= win.end {
            ticks.append(t)
            guard let next = cal.date(byAdding: .hour, value: 1, to: t) else { break }
            t = next
        }
        return ticks
    }

    private func xPos(for date: Date,
                      in win: (start: Date, end: Date),
                      total: TimeInterval,
                      width: CGFloat) -> CGFloat {
        let clamped = max(win.start, min(win.end, date))
        let frac = clamped.timeIntervalSince(win.start) / total
        return CGFloat(frac) * width
    }

    private func dateFromX(_ x: CGFloat,
                           in win: (start: Date, end: Date),
                           total: TimeInterval,
                           width: CGFloat) -> Date {
        let clamped = max(0, min(width, x))
        let frac = Double(clamped / max(width, 1))
        let raw = win.start.addingTimeInterval(frac * total)
        let snapped = (raw.timeIntervalSince1970 / snapSeconds).rounded() * snapSeconds
        return Date(timeIntervalSince1970: snapped)
    }

    /// Decide which target a cursor x-position activates. Handle hit zones are
    /// 12pt either side of the handle center; anything strictly between the
    /// two handles activates band-translate; anywhere else is a no-op.
    private func target(at x: CGFloat,
                        in win: (start: Date, end: Date),
                        total: TimeInterval,
                        width: CGFloat) -> DragTarget? {
        let bX = xPos(for: begin, in: win, total: total, width: width)
        let eX = xPos(for: visualEnd, in: win, total: total, width: width)
        let hitRadius: CGFloat = 12
        let nearBegin = abs(x - bX) <= hitRadius
        let nearEnd = mode == .range && abs(x - eX) <= hitRadius
        // When handles are close together, prefer whichever is nearer.
        if nearBegin && nearEnd {
            return abs(x - bX) <= abs(x - eX) ? .beginHandle : .endHandle
        }
        if nearBegin { return .beginHandle }
        if nearEnd { return .endHandle }
        if mode == .range, x > bX, x < eX { return .band }
        return nil
    }

    private func dragGesture(win: (start: Date, end: Date),
                             total: TimeInterval,
                             width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                if dragTarget == nil {
                    if let t = target(at: value.startLocation.x, in: win, total: total, width: width) {
                        dragTarget = t
                        if t == .band {
                            dragStartBegin = begin
                            dragStartEnd = end
                            NSCursor.closedHand.set()
                        }
                    } else {
                        // Outside any target — ignore until release
                        return
                    }
                }
                switch dragTarget {
                case .beginHandle:
                    let raw = dateFromX(value.location.x, in: win, total: total, width: width)
                    // begin must stay before the upper cap (end-snap in range,
                    // visualEnd-snap in beginOnly) AND after any existing entry
                    // that ends before the current upper cap.
                    let upperCap = (mode == .range ? end : visualEnd)
                        .addingTimeInterval(-snapSeconds)
                    let lower = leftBlocker(when: mode == .range ? end : visualEnd)
                    begin = max(lower, min(raw, upperCap))
                case .endHandle:
                    let raw = dateFromX(value.location.x, in: win, total: total, width: width)
                    let lowerCap = begin.addingTimeInterval(snapSeconds)
                    let upper = rightBlocker(when: begin)
                    end = max(lowerCap, min(raw, upper))
                case .band:
                    // Translate freely during drag — clamp only to the window
                    // bounds. Crossing over existing entries is allowed; we
                    // validate on release. The visual band tints red while
                    // it's parked over an overlap as a warning.
                    let deltaSec = Double(value.translation.width / max(width, 1)) * total
                    let snapped = (deltaSec / snapSeconds).rounded() * snapSeconds
                    var newBegin = dragStartBegin.addingTimeInterval(snapped)
                    var newEnd = dragStartEnd.addingTimeInterval(snapped)
                    if newBegin < win.start {
                        let shift = win.start.timeIntervalSince(newBegin)
                        newBegin = win.start
                        newEnd = newEnd.addingTimeInterval(shift)
                    }
                    if newEnd > win.end {
                        let shift = newEnd.timeIntervalSince(win.end)
                        newEnd = win.end
                        newBegin = newBegin.addingTimeInterval(-shift)
                    }
                    begin = newBegin
                    end = newEnd
                case .none:
                    break
                }
            }
            .onEnded { _ in
                defer {
                    dragTarget = nil
                    NSCursor.arrow.set()
                }
                // On band release, if the final position overlaps any
                // existing entry, snap to the nearest free slot of the same
                // duration. If none is reachable inside the window, revert
                // to the pre-drag position.
                if dragTarget == .band, mode == .range,
                   overlapsAnyExisting(begin: begin, end: end) {
                    if let resolved = nearestFreeSlot(begin: begin, end: end) {
                        begin = resolved.begin
                        end = resolved.end
                    } else {
                        begin = dragStartBegin
                        end = dragStartEnd
                    }
                }
            }
    }

    // MARK: - Existing-entry blockers

    /// Lowest time `begin` can move to, given `end` is fixed at `endCap`.
    /// Returns the largest `entry.end` such that entry would overlap
    /// `[begin, endCap]` if begin moved earlier than that. Falls back to
    /// `window.start` if nothing constrains us.
    private func leftBlocker(when endCap: Date) -> Date {
        var bound = window.start
        for entry in existingEntries where entry.id != excludeEntryId {
            let eEnd = entry.end ?? Date()
            if entry.begin < endCap && eEnd > bound && eEnd <= endCap {
                bound = eEnd
            }
        }
        return bound
    }

    /// Highest time `end` can move to, given `begin` is fixed at `beginCap`.
    private func rightBlocker(when beginCap: Date) -> Date {
        var bound = window.end
        for entry in existingEntries where entry.id != excludeEntryId {
            let eEnd = entry.end ?? Date()
            if eEnd > beginCap && entry.begin < bound && entry.begin >= beginCap {
                bound = entry.begin
            }
        }
        return bound
    }

    /// Does the candidate `[begin, end]` overlap any existing entry (other
    /// than the excluded one)?
    func overlapsAnyExisting(begin: Date, end: Date) -> Bool {
        for entry in existingEntries where entry.id != excludeEntryId {
            let eEnd = entry.end ?? Date()
            if begin < eEnd && entry.begin < end {
                return true
            }
        }
        return false
    }

    /// Find a `[begin', end']` of the same duration that doesn't overlap any
    /// existing entry, sitting as close as possible to the user-released
    /// position. We consider every "just before this entry" and "just after
    /// this entry" candidate as well as the window endpoints, and pick
    /// whichever begin is closest to the released begin.
    private func nearestFreeSlot(begin: Date, end: Date) -> (begin: Date, end: Date)? {
        let duration = end.timeIntervalSince(begin)
        guard duration > 0 else { return nil }
        let win = window
        var candidates: [(begin: Date, end: Date)] = []

        func tryCandidate(_ b: Date) {
            let candidate = (begin: b, end: b.addingTimeInterval(duration))
            guard candidate.begin >= win.start, candidate.end <= win.end else { return }
            if !overlapsAnyExisting(begin: candidate.begin, end: candidate.end) {
                candidates.append(candidate)
            }
        }

        // Adjacent to each existing entry, on either side.
        for entry in existingEntries where entry.id != excludeEntryId {
            let eBegin = entry.begin
            let eEnd = entry.end ?? Date()
            tryCandidate(eBegin.addingTimeInterval(-duration)) // just before
            tryCandidate(eEnd)                                  // just after
        }
        // Window endpoints.
        tryCandidate(win.start)
        tryCandidate(win.end.addingTimeInterval(-duration))

        // Closest by begin time to the released begin.
        let target = begin.timeIntervalSinceReferenceDate
        return candidates.min { lhs, rhs in
            abs(lhs.begin.timeIntervalSinceReferenceDate - target)
                < abs(rhs.begin.timeIntervalSinceReferenceDate - target)
        }
    }
}

/// Compact read-out used below the TimeRangeBar — shows `HH:mm` with ±1min
/// nudge buttons. Used for fine-tuning after a coarse drag.
struct TimeNudgeField: View {
    let label: String
    @Binding var date: Date
    let minDate: Date?
    let maxDate: Date?

    init(label: String,
         date: Binding<Date>,
         minDate: Date? = nil,
         maxDate: Date? = nil) {
        self.label = label
        self._date = date
        self.minDate = minDate
        self.maxDate = maxDate
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            HStack(spacing: 0) {
                nudgeButton(systemName: "minus", delta: -60)
                Text(timeString)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .frame(minWidth: 52)
                    .padding(.vertical, 4)
                nudgeButton(systemName: "plus", delta: 60)
            }
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.08))
            )
        }
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func nudgeButton(systemName: String, delta: TimeInterval) -> some View {
        Button {
            var next = date.addingTimeInterval(delta)
            if let minDate, next < minDate { next = minDate }
            if let maxDate, next > maxDate { next = maxDate }
            date = next
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

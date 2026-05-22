import Carbon.HIToolbox
import Foundation

// Carbon virtual key code for the "T" key.
let kVK_ANSI_T: UInt32 = 17

// Signature used to identify our hotkey registration — "TBHK" as a FourCC.
private let kHotKeySignature: OSType = (0x54 << 24) | (0x42 << 16) | (0x48 << 8) | 0x4B

// Stable hotkey ID within this app.
private let kHotKeyLocalID: UInt32 = 1

// The default modifier mask: Cmd + Option.
// Carbon modifier constants: cmdKey = 256 (0x100), optionKey = 2048 (0x800).
let kDefaultHotkeyModifiers: UInt32 = UInt32(cmdKey | optionKey)

// Thread-safe bridge: maps a UInt32 hotkey ID to the Swift closure to invoke.
// Written only on the main thread (when register/unregister is called).
// Read from the Carbon event handler (called on the main thread via the event loop).
// nonisolated(unsafe) is intentional — access is always serialised through the
// main run loop so no data race can occur.
nonisolated(unsafe) private var hotkeyHandlers: [UInt32: () -> Void] = [:]

// Carbon event handler installed at registration time.
// Receives kEventHotKeyPressed events and dispatches to the registered closure.
private let carbonEventHandler: EventHandlerUPP = { _, event, _ -> OSStatus in
    guard let event else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return OSStatus(eventNotHandledErr) }
    if let handler = hotkeyHandlers[hotKeyID.id] {
        // We are already on the main thread — Carbon delivers hotkey events
        // through the application event loop which runs on the main thread.
        handler()
    }
    return noErr
}

/// Manages a single global Carbon hotkey registration.
///
/// Carbon's `RegisterEventHotKey` is the correct API for system-wide hotkeys
/// on macOS. It works in sandboxed apps without Accessibility permissions and
/// fires reliably from any foreground application.
///
/// Usage:
/// ```swift
/// let manager = HotkeyManager()
/// manager.register(keyCode: kVK_ANSI_T, modifiers: kDefaultHotkeyModifiers) {
///     // invoked on the main thread whenever Cmd+Option+T is pressed
/// }
/// ```
@MainActor
final class HotkeyManager {
    // nonisolated(unsafe) lets deinit (always nonisolated) access these refs
    // without a concurrency violation. Both are written only on the main thread
    // (during register/unregister) and read only in deinit which is effectively
    // called from the main thread for a @MainActor class — the unsafe opt-out
    // is safe in practice. Same pattern used by SleepObserver in this project.
    nonisolated(unsafe) private var hotKeyRef: EventHotKeyRef?
    nonisolated(unsafe) private var eventHandlerRef: EventHandlerRef?

    // MARK: - Public API

    /// Register the global hotkey. Replaces any existing registration.
    ///
    /// - Parameters:
    ///   - keyCode: Carbon virtual key code (e.g. `kVK_ANSI_T` = 17).
    ///   - modifiers: Carbon modifier mask (e.g. `cmdKey | optionKey`).
    ///   - onPress: Closure called on the main thread each time the combo fires.
    func register(keyCode: UInt32, modifiers: UInt32, onPress: @escaping () -> Void) {
        unregister()

        // Store the closure in the global bridge so the C callback can reach it.
        hotkeyHandlers[kHotKeyLocalID] = onPress

        let hotKeyID = EventHotKeyID(signature: kHotKeySignature, id: kHotKeyLocalID)
        let regStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if regStatus != noErr {
            NSLog("TimesBar: RegisterEventHotKey failed with status \(regStatus)")
            hotkeyHandlers.removeValue(forKey: kHotKeyLocalID)
            return
        }

        // Install the Carbon event handler that routes kEventHotKeyPressed to
        // our Swift closure. One handler covers all hotkeys registered for this
        // application event target.
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            carbonEventHandler,
            1,
            &eventSpec,
            nil,
            &eventHandlerRef
        )
        if installStatus != noErr {
            NSLog("TimesBar: InstallEventHandler failed with status \(installStatus)")
            // Roll back the hotkey registration so we don't leak.
            if let ref = hotKeyRef { UnregisterEventHotKey(ref); hotKeyRef = nil }
            hotkeyHandlers.removeValue(forKey: kHotKeyLocalID)
        }
    }

    /// Unregister the hotkey and remove the Carbon event handler.
    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
        hotkeyHandlers.removeValue(forKey: kHotKeyLocalID)
    }

    deinit {
        // deinit is nonisolated, so we cannot call the @MainActor unregister().
        // nonisolated(unsafe) on the stored refs allows direct access here.
        // In practice this object is only ever torn down on the main thread.
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        if let handler = eventHandlerRef { RemoveEventHandler(handler) }
        hotkeyHandlers.removeValue(forKey: kHotKeyLocalID)
    }
}

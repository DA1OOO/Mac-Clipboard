import AppKit
import Carbon.HIToolbox
import Combine
import Foundation

@MainActor
final class GlobalHotKey: ObservableObject {
  struct Shortcut: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    let keyDisplay: String

    static let standard = Shortcut(
      keyCode: UInt32(kVK_ANSI_V),
      modifiers: UInt32(cmdKey | shiftKey),
      keyDisplay: "V"
    )

    var displayString: String {
      var result = ""
      if modifiers & UInt32(cmdKey) != 0 { result += "⌘" }
      if modifiers & UInt32(shiftKey) != 0 { result += "⇧" }
      if modifiers & UInt32(optionKey) != 0 { result += "⌥" }
      if modifiers & UInt32(controlKey) != 0 { result += "⌃" }
      return result + keyDisplay
    }

    var isValid: Bool {
      let allowedModifiers = UInt32(cmdKey | shiftKey | optionKey | controlKey)
      let primaryModifiers = UInt32(cmdKey | optionKey | controlKey)
      return !keyDisplay.isEmpty
        && modifiers & ~allowedModifiers == 0
        && (modifiers & primaryModifiers != 0 || Self.isFunctionKey(keyCode))
    }

    init(keyCode: UInt32, modifiers: UInt32, keyDisplay: String) {
      self.keyCode = keyCode
      self.modifiers = modifiers
      self.keyDisplay = keyDisplay
    }

    init?(event: NSEvent) {
      let keyCode = UInt32(event.keyCode)
      let modifiers = Self.carbonModifiers(from: event.modifierFlags)
      let primaryModifiers = UInt32(cmdKey | optionKey | controlKey)

      guard modifiers & primaryModifiers != 0 || Self.isFunctionKey(keyCode),
        let keyDisplay = Self.keyDisplay(for: event),
        !keyDisplay.isEmpty
      else {
        return nil
      }

      self.init(
        keyCode: keyCode,
        modifiers: modifiers,
        keyDisplay: keyDisplay
      )
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
      let flags = flags.intersection(.deviceIndependentFlagsMask)
      var modifiers: UInt32 = 0
      if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
      if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
      if flags.contains(.option) { modifiers |= UInt32(optionKey) }
      if flags.contains(.control) { modifiers |= UInt32(controlKey) }
      return modifiers
    }

    private static func keyDisplay(for event: NSEvent) -> String? {
      if let specialKey = specialKeyDisplays[event.keyCode] {
        return specialKey
      }

      return event.charactersIgnoringModifiers?
        .trimmingCharacters(in: .controlCharacters)
        .uppercased()
    }

    private static func isFunctionKey(_ keyCode: UInt32) -> Bool {
      functionKeyCodes.contains(keyCode)
    }

    private static let functionKeyCodes: Set<UInt32> = [
      UInt32(kVK_F1), UInt32(kVK_F2), UInt32(kVK_F3), UInt32(kVK_F4),
      UInt32(kVK_F5), UInt32(kVK_F6), UInt32(kVK_F7), UInt32(kVK_F8),
      UInt32(kVK_F9), UInt32(kVK_F10), UInt32(kVK_F11), UInt32(kVK_F12),
      UInt32(kVK_F13), UInt32(kVK_F14), UInt32(kVK_F15), UInt32(kVK_F16),
      UInt32(kVK_F17), UInt32(kVK_F18), UInt32(kVK_F19), UInt32(kVK_F20),
    ]

    private static let specialKeyDisplays: [UInt16: String] = [
      UInt16(kVK_Return): "↩",
      UInt16(kVK_Tab): "⇥",
      UInt16(kVK_Space): "Space",
      UInt16(kVK_Delete): "⌫",
      UInt16(kVK_Escape): "⎋",
      UInt16(kVK_ForwardDelete): "⌦",
      UInt16(kVK_Home): "↖",
      UInt16(kVK_End): "↘",
      UInt16(kVK_PageUp): "⇞",
      UInt16(kVK_PageDown): "⇟",
      UInt16(kVK_LeftArrow): "←",
      UInt16(kVK_RightArrow): "→",
      UInt16(kVK_DownArrow): "↓",
      UInt16(kVK_UpArrow): "↑",
      UInt16(kVK_ANSI_KeypadEnter): "↩",
      UInt16(kVK_F1): "F1",
      UInt16(kVK_F2): "F2",
      UInt16(kVK_F3): "F3",
      UInt16(kVK_F4): "F4",
      UInt16(kVK_F5): "F5",
      UInt16(kVK_F6): "F6",
      UInt16(kVK_F7): "F7",
      UInt16(kVK_F8): "F8",
      UInt16(kVK_F9): "F9",
      UInt16(kVK_F10): "F10",
      UInt16(kVK_F11): "F11",
      UInt16(kVK_F12): "F12",
      UInt16(kVK_F13): "F13",
      UInt16(kVK_F14): "F14",
      UInt16(kVK_F15): "F15",
      UInt16(kVK_F16): "F16",
      UInt16(kVK_F17): "F17",
      UInt16(kVK_F18): "F18",
      UInt16(kVK_F19): "F19",
      UInt16(kVK_F20): "F20",
    ]
  }

  @Published private(set) var shortcut: Shortcut
  @Published private(set) var registrationError: String?

  private enum DefaultsKey {
    static let shortcut = "globalHotKeyShortcut"
  }

  private static let hotKeySignature = fourCharacterCode("MCBH")
  private static let panelCommandSignature = fourCharacterCode("MCPN")

  private enum PanelCommandIdentifier: UInt32, CaseIterable {
    case previous = 1
    case next = 2
    case submit = 3
    case keypadSubmit = 4
    case dismiss = 5
    case previousTab = 6
    case nextTab = 7

    var keyCode: UInt32 {
      switch self {
      case .previous:
        UInt32(kVK_UpArrow)
      case .next:
        UInt32(kVK_DownArrow)
      case .previousTab:
        UInt32(kVK_LeftArrow)
      case .nextTab:
        UInt32(kVK_RightArrow)
      case .submit:
        UInt32(kVK_Return)
      case .keypadSubmit:
        UInt32(kVK_ANSI_KeypadEnter)
      case .dismiss:
        UInt32(kVK_Escape)
      }
    }

    var command: PanelCommand {
      switch self {
      case .previous:
        .previous
      case .next:
        .next
      case .previousTab:
        .previousTab
      case .nextTab:
        .nextTab
      case .submit, .keypadSubmit:
        .submit
      case .dismiss:
        .dismiss
      }
    }
  }

  private let defaults: UserDefaults
  private var action: (() -> Void)?
  private var panelCommandAction: ((PanelCommand) -> Void)?
  private var hotKeyRef: EventHotKeyRef?
  private var panelCommandHotKeyRefs: [EventHotKeyRef] = []
  private var eventHandlerRef: EventHandlerRef?

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    self.shortcut = Self.loadShortcut(from: defaults)
  }

  deinit {
    if let hotKeyRef {
      UnregisterEventHotKey(hotKeyRef)
    }
    for reference in panelCommandHotKeyRefs {
      UnregisterEventHotKey(reference)
    }
    if let eventHandlerRef {
      RemoveEventHandler(eventHandlerRef)
    }
  }

  func activate(action: @escaping () -> Void) {
    self.action = action

    if eventHandlerRef == nil {
      let status = installHandler()
      guard status == noErr else {
        registrationError = "Could not install the shortcut handler (error \(status))."
        return
      }
    }

    unregisterHotKey()
    let status = register(shortcut)
    registrationError = status == noErr ? nil : Self.message(for: status)
  }

  @discardableResult
  func activatePanelCommands(action: @escaping (PanelCommand) -> Void) -> OSStatus {
    panelCommandAction = action
    guard eventHandlerRef != nil else { return OSStatus(eventNotHandledErr) }

    unregisterPanelCommandHotKeys()
    for identifier in PanelCommandIdentifier.allCases {
      var reference: EventHotKeyRef?
      let status = RegisterEventHotKey(
        identifier.keyCode,
        0,
        EventHotKeyID(signature: Self.panelCommandSignature, id: identifier.rawValue),
        GetApplicationEventTarget(),
        0,
        &reference
      )
      guard status == noErr, let reference else {
        unregisterPanelCommandHotKeys()
        return status == noErr ? OSStatus(eventInternalErr) : status
      }
      panelCommandHotKeyRefs.append(reference)
    }
    return noErr
  }

  func deactivatePanelCommands() {
    unregisterPanelCommandHotKeys()
    panelCommandAction = nil
  }

  func dispatchPanelCommand(_ command: PanelCommand) {
    panelCommandAction?(command)
  }

  @discardableResult
  func updateShortcut(_ candidate: Shortcut) -> Bool {
    guard candidate.isValid else {
      registrationError = "Use ⌘, ⌥, or ⌃ with a key, or choose a function key."
      return false
    }

    guard candidate != shortcut else {
      registrationError = nil
      return true
    }

    let previousShortcut = shortcut
    guard action != nil else {
      shortcut = candidate
      persist(candidate)
      registrationError = nil
      return true
    }

    unregisterHotKey()
    let status = register(candidate)
    guard status == noErr else {
      let restorationStatus = register(previousShortcut)
      registrationError = Self.message(
        for: status,
        previousShortcutRestored: restorationStatus == noErr
      )
      return false
    }

    shortcut = candidate
    persist(candidate)
    registrationError = nil
    return true
  }

  func restoreDefault() {
    updateShortcut(.standard)
  }

  private func installHandler() -> OSStatus {
    var eventType = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard),
      eventKind: UInt32(kEventHotKeyPressed)
    )

    let userData = Unmanaged.passUnretained(self).toOpaque()
    return InstallEventHandler(
      GetApplicationEventTarget(),
      { _, event, userData in
        guard let event, let userData else { return OSStatus(eventNotHandledErr) }

        var identifier = EventHotKeyID()
        let status = GetEventParameter(
          event,
          EventParamName(kEventParamDirectObject),
          EventParamType(typeEventHotKeyID),
          nil,
          MemoryLayout<EventHotKeyID>.size,
          nil,
          &identifier
        )
        let hotKey = Unmanaged<GlobalHotKey>
          .fromOpaque(userData)
          .takeUnretainedValue()

        if status == noErr,
          identifier.signature == GlobalHotKey.hotKeySignature,
          identifier.id == 1
        {
          DispatchQueue.main.async {
            hotKey.action?()
          }
          return noErr
        }

        if status == noErr,
          identifier.signature == GlobalHotKey.panelCommandSignature,
          let command = PanelCommandIdentifier(rawValue: identifier.id)?.command
        {
          DispatchQueue.main.async {
            hotKey.dispatchPanelCommand(command)
          }
          return noErr
        }

        return OSStatus(eventNotHandledErr)
      },
      1,
      &eventType,
      userData,
      &eventHandlerRef
    )
  }

  private func register(_ shortcut: Shortcut) -> OSStatus {
    guard eventHandlerRef != nil else { return OSStatus(eventNotHandledErr) }

    let identifier = EventHotKeyID(
      signature: Self.hotKeySignature,
      id: 1
    )
    var reference: EventHotKeyRef?
    let status = RegisterEventHotKey(
      shortcut.keyCode,
      shortcut.modifiers,
      identifier,
      GetApplicationEventTarget(),
      0,
      &reference
    )
    if status == noErr {
      hotKeyRef = reference
    }
    return status
  }

  private func unregisterHotKey() {
    guard let hotKeyRef else { return }
    UnregisterEventHotKey(hotKeyRef)
    self.hotKeyRef = nil
  }

  private func unregisterPanelCommandHotKeys() {
    for reference in panelCommandHotKeyRefs {
      UnregisterEventHotKey(reference)
    }
    panelCommandHotKeyRefs.removeAll()
  }

  private func persist(_ shortcut: Shortcut) {
    do {
      defaults.set(try JSONEncoder().encode(shortcut), forKey: DefaultsKey.shortcut)
    } catch {
      NSLog("MacClipboard could not save shortcut settings: %@", error.localizedDescription)
    }
  }

  private static func loadShortcut(from defaults: UserDefaults) -> Shortcut {
    guard let data = defaults.data(forKey: DefaultsKey.shortcut),
      let shortcut = try? JSONDecoder().decode(Shortcut.self, from: data),
      shortcut.isValid
    else {
      return .standard
    }
    return shortcut
  }

  private static func message(
    for status: OSStatus,
    previousShortcutRestored: Bool = true
  ) -> String {
    let message: String
    if status == OSStatus(eventHotKeyExistsErr) {
      message = "That shortcut is already in use. Choose another one."
    } else {
      message = "Could not register that shortcut (error \(status))."
    }

    return previousShortcutRestored
      ? message
      : message + " The previous shortcut could not be restored."
  }

  private static func fourCharacterCode(_ value: String) -> OSType {
    value.utf8.reduce(0) { result, character in
      (result << 8) + OSType(character)
    }
  }
}

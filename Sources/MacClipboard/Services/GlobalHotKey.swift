import Carbon.HIToolbox
import Foundation

final class GlobalHotKey {
  private var hotKeyRef: EventHotKeyRef?
  private var eventHandlerRef: EventHandlerRef?
  private let action: () -> Void

  init(action: @escaping () -> Void) {
    self.action = action
    installHandler()
    registerHotKey()
  }

  deinit {
    if let hotKeyRef {
      UnregisterEventHotKey(hotKeyRef)
    }
    if let eventHandlerRef {
      RemoveEventHandler(eventHandlerRef)
    }
  }

  private func installHandler() {
    var eventType = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard),
      eventKind: UInt32(kEventHotKeyPressed)
    )

    let userData = Unmanaged.passUnretained(self).toOpaque()
    InstallEventHandler(
      GetApplicationEventTarget(),
      { _, _, userData in
        guard let userData else { return OSStatus(eventNotHandledErr) }
        let hotKey = Unmanaged<GlobalHotKey>
          .fromOpaque(userData)
          .takeUnretainedValue()
        DispatchQueue.main.async {
          hotKey.action()
        }
        return noErr
      },
      1,
      &eventType,
      userData,
      &eventHandlerRef
    )
  }

  private func registerHotKey() {
    let identifier = EventHotKeyID(
      signature: Self.fourCharacterCode("MCBH"),
      id: 1
    )

    RegisterEventHotKey(
      UInt32(kVK_ANSI_V),
      UInt32(cmdKey | shiftKey),
      identifier,
      GetApplicationEventTarget(),
      0,
      &hotKeyRef
    )
  }

  private static func fourCharacterCode(_ value: String) -> OSType {
    value.utf8.reduce(0) { result, character in
      (result << 8) + OSType(character)
    }
  }
}

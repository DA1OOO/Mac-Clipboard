import AppKit

@MainActor
final class ClipboardPanel: NSPanel {
  init(contentSize: NSSize) {
    super.init(
      contentRect: NSRect(origin: .zero, size: contentSize),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )

    isReleasedWhenClosed = false
    isFloatingPanel = true
    becomesKeyOnlyIfNeeded = true
    level = .popUpMenu
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    isOpaque = false
    backgroundColor = .clear
    hasShadow = true
    animationBehavior = .utilityWindow
    hidesOnDeactivate = false
  }

  override var canBecomeKey: Bool {
    true
  }

  override var canBecomeMain: Bool {
    false
  }
}

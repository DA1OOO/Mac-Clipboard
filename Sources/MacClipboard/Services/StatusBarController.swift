import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
  private let statusItem: NSStatusItem
  private let popover: NSPopover
  private var globalHotKey: GlobalHotKey?

  init(store: ClipboardStore) {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    popover = NSPopover()
    super.init()

    if let button = statusItem.button {
      button.image = NSImage(
        systemSymbolName: "doc.on.clipboard",
        accessibilityDescription: "Mac Clipboard"
      )
      button.toolTip = "Mac Clipboard (⌘⇧V)"
      button.target = self
      button.action = #selector(togglePopover)
    }

    let rootView = ClipboardHistoryView(store: store) { [weak self] in
      self?.popover.performClose(nil)
    }
    popover.contentSize = NSSize(width: 440, height: 520)
    popover.behavior = .transient
    popover.animates = true
    popover.delegate = self
    popover.contentViewController = NSHostingController(rootView: rootView)

    globalHotKey = GlobalHotKey { [weak self] in
      self?.togglePopover()
    }
  }

  deinit {
    NSStatusBar.system.removeStatusItem(statusItem)
  }

  @objc private func togglePopover() {
    if popover.isShown {
      popover.performClose(nil)
    } else {
      showPopover()
    }
  }

  private func showPopover() {
    guard let button = statusItem.button else { return }
    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    NSApp.activate(ignoringOtherApps: true)
    popover.contentViewController?.view.window?.makeKey()
  }
}

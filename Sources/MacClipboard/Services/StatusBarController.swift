import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController: NSObject, NSWindowDelegate {
  private let statusItem: NSStatusItem
  private let panel: ClipboardPanel
  private let globalHotKey: GlobalHotKey
  private let focusedInputPaster: FocusedInputPaster
  private let panelCommandRouter: PanelCommandRouter
  private var shortcutObserver: AnyCancellable?
  private var outsideClickMonitor: Any?
  private var historyCommandsEnabled = true

  init(
    store: ClipboardStore,
    globalHotKey: GlobalHotKey,
    focusedInputPaster: FocusedInputPaster
  ) {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    panel = ClipboardPanel(contentSize: NSSize(width: 440, height: 520))
    self.globalHotKey = globalHotKey
    self.focusedInputPaster = focusedInputPaster
    panelCommandRouter = PanelCommandRouter()
    super.init()

    if let button = statusItem.button {
      button.image = NSImage(
        systemSymbolName: "doc.on.clipboard",
        accessibilityDescription: "Mac Clipboard"
      )
      button.target = self
      button.action = #selector(togglePanel)
    }

    let rootView = ClipboardHistoryView(
      store: store,
      globalHotKey: globalHotKey,
      focusedInputPaster: focusedInputPaster,
      panelCommandRouter: panelCommandRouter,
      historyCommandsChanged: { [weak self] isEnabled in
        self?.setHistoryCommandsEnabled(isEnabled)
      },
      dismiss: { [weak self] in
        self?.closePanel()
      }
    )
    panel.delegate = self
    panel.contentViewController = NSHostingController(rootView: rootView)

    shortcutObserver = globalHotKey.$shortcut.sink { [weak self] shortcut in
      self?.statusItem.button?.toolTip = "Mac Clipboard (\(shortcut.displayString))"
    }

    globalHotKey.activate { [weak self] in
      self?.togglePanel()
    }
  }

  deinit {
    if let outsideClickMonitor {
      NSEvent.removeMonitor(outsideClickMonitor)
    }
    NSStatusBar.system.removeStatusItem(statusItem)
  }

  @objc private func togglePanel() {
    if panel.isVisible {
      closePanel()
    } else {
      showPanel()
    }
  }

  private func showPanel() {
    guard let button = statusItem.button,
      let statusWindow = button.window
    else {
      return
    }

    focusedInputPaster.rememberFrontmostApplication()
    panelCommandRouter.send(.panelWillOpen)
    let buttonFrame = statusWindow.convertToScreen(
      button.convert(button.bounds, to: nil)
    )
    let screen = statusWindow.screen ?? NSScreen.main
    resizePanelToFillHeight(on: screen)
    let origin: NSPoint
    if isVisibleStatusButtonFrame(buttonFrame, on: screen) {
      origin = panelOrigin(below: buttonFrame, on: screen)
    } else {
      origin = panelOriginAtTopTrailing(on: screen)
    }
    panel.setFrameOrigin(origin)
    panel.makeFirstResponder(nil)
    panel.orderFrontRegardless()
    updatePanelCommandHotKeys()
    startOutsideClickMonitor()
  }

  private func closePanel() {
    panelCommandRouter.send(.panelWillClose)
    globalHotKey.deactivatePanelCommands()
    stopOutsideClickMonitor()
    panel.makeFirstResponder(nil)
    panel.orderOut(nil)
  }

  private func setHistoryCommandsEnabled(_ isEnabled: Bool) {
    historyCommandsEnabled = isEnabled
    guard panel.isVisible else { return }
    updatePanelCommandHotKeys()
  }

  private func updatePanelCommandHotKeys() {
    globalHotKey.deactivatePanelCommands()
    guard panel.isVisible, historyCommandsEnabled else { return }
    let status = globalHotKey.activatePanelCommands { [weak self] command in
      guard let self else { return }
      if command == .dismiss {
        closePanel()
      } else {
        panelCommandRouter.send(command)
      }
    }
    if status != noErr {
      NSLog("MacClipboard could not register panel navigation keys: %d", status)
    }
  }

  private func startOutsideClickMonitor() {
    stopOutsideClickMonitor()
    outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
      matching: [.leftMouseDown, .rightMouseDown]
    ) { [weak self] _ in
      Task { @MainActor in
        self?.closePanel()
      }
    }
  }

  private func stopOutsideClickMonitor() {
    guard let outsideClickMonitor else { return }
    NSEvent.removeMonitor(outsideClickMonitor)
    self.outsideClickMonitor = nil
  }

  private func panelOrigin(below buttonFrame: NSRect, on screen: NSScreen?) -> NSPoint {
    let visibleFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
    let margin: CGFloat = 8
    let minimumX = visibleFrame.minX + margin
    let maximumX = visibleFrame.maxX - panel.frame.width - margin
    let desiredX = buttonFrame.midX - panel.frame.width / 2
    let x = min(max(desiredX, minimumX), maximumX)
    let y = buttonFrame.minY - panel.frame.height - 6
    return NSPoint(x: x, y: max(y, visibleFrame.minY + margin))
  }

  private func resizePanelToFillHeight(on screen: NSScreen?) {
    let visibleFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
    let margin: CGFloat = 8
    panel.setContentSize(
      NSSize(
        width: panel.frame.width,
        height: max(320, visibleFrame.height - margin * 2)
      )
    )
  }

  private func isVisibleStatusButtonFrame(_ buttonFrame: NSRect, on screen: NSScreen?) -> Bool {
    guard let screen, buttonFrame.width > 0, buttonFrame.height > 0 else { return false }
    let screenFrame = screen.frame
    let isHorizontallyVisible = buttonFrame.midX >= screenFrame.minX
      && buttonFrame.midX <= screenFrame.maxX
    let isInMenuBar = buttonFrame.maxY >= screenFrame.maxY - 64
      && buttonFrame.minY <= screenFrame.maxY
    return isHorizontallyVisible && isInMenuBar
  }

  private func panelOriginAtTopTrailing(on screen: NSScreen?) -> NSPoint {
    let visibleFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
    let margin: CGFloat = 8
    return NSPoint(
      x: visibleFrame.maxX - panel.frame.width - margin,
      y: visibleFrame.maxY - panel.frame.height - margin
    )
  }

  func windowDidResignKey(_ notification: Notification) {
    if panel.isVisible {
      closePanel()
    }
  }
}

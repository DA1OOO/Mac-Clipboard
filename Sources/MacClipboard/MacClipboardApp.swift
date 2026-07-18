import AppKit
import SwiftUI

@main
struct MacClipboardApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    Settings {
      SettingsView(
        store: appDelegate.store,
        globalHotKey: appDelegate.globalHotKey,
        focusedInputPaster: appDelegate.focusedInputPaster
      )
    }
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let store = ClipboardStore()
  let globalHotKey = GlobalHotKey()
  let focusedInputPaster = FocusedInputPaster()
  private var statusBarController: StatusBarController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    store.startMonitoring()
    statusBarController = StatusBarController(
      store: store,
      globalHotKey: globalHotKey,
      focusedInputPaster: focusedInputPaster
    )
  }

  func applicationWillTerminate(_ notification: Notification) {
    store.stopMonitoring()
  }
}

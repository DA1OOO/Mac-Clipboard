import AppKit
import SwiftUI

@main
struct MacClipboardApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    Settings {
      SettingsView(store: appDelegate.store)
    }
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let store = ClipboardStore()
  private var statusBarController: StatusBarController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    store.startMonitoring()
    statusBarController = StatusBarController(store: store)
  }

  func applicationWillTerminate(_ notification: Notification) {
    store.stopMonitoring()
  }
}

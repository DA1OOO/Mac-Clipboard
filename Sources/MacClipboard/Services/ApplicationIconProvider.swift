import AppKit
import MacClipboardCore

@MainActor
final class ApplicationIconProvider {
  static let shared = ApplicationIconProvider()

  private var cache: [String: NSImage] = [:]

  func icon(for sourceApplication: ClipboardSourceApplication) -> NSImage? {
    let cacheKey = sourceApplication.bundleIdentifier ?? sourceApplication.displayName
    if let cachedIcon = cache[cacheKey] {
      return cachedIcon
    }

    let applicationURL: URL?
    if let bundleIdentifier = sourceApplication.bundleIdentifier {
      applicationURL = NSWorkspace.shared.urlForApplication(
        withBundleIdentifier: bundleIdentifier
      )
    } else {
      applicationURL = NSWorkspace.shared.runningApplications.first {
        $0.localizedName == sourceApplication.displayName
      }?.bundleURL
    }

    guard let applicationURL else { return nil }
    let icon = NSWorkspace.shared.icon(forFile: applicationURL.path)
    cache[cacheKey] = icon
    return icon
  }
}

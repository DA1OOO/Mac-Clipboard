import AppKit
import Combine
import Foundation
import MacClipboardCore

@MainActor
final class ClipboardStore: ObservableObject {
  @Published private(set) var items: [ClipboardItem]
  @Published private(set) var favoriteItems: [ClipboardItem]
  @Published private(set) var isMonitoring = false

  private let pasteboard: NSPasteboard
  private let persistence: HistoryPersistence
  private var timer: Timer?
  private var lastChangeCount: Int

  private static let defaultHistoryLimit = 100
  private static let maximumTextLength = 100_000

  init(
    pasteboard: NSPasteboard = .general,
    persistence: HistoryPersistence = HistoryPersistence()
  ) {
    UserDefaults.standard.register(defaults: [
      "historyLimit": Self.defaultHistoryLimit
    ])
    self.pasteboard = pasteboard
    self.persistence = persistence
    self.items = persistence.load()
    self.favoriteItems = persistence.loadFavorites()
    self.lastChangeCount = pasteboard.changeCount
    enforceCurrentLimit()
  }

  var historyLimit: Int {
    let configured = UserDefaults.standard.integer(forKey: "historyLimit")
    return configured > 0 ? configured : Self.defaultHistoryLimit
  }

  var storageURL: URL {
    persistence.historyURL
  }

  func startMonitoring() {
    guard timer == nil else { return }
    isMonitoring = true
    lastChangeCount = pasteboard.changeCount
    captureCurrentClipboard()

    timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.pollPasteboard()
      }
    }
  }

  func stopMonitoring() {
    timer?.invalidate()
    timer = nil
    isMonitoring = false
  }

  func toggleMonitoring() {
    isMonitoring ? stopMonitoring() : startMonitoring()
  }

  func copy(_ item: ClipboardItem) {
    pasteboard.clearContents()
    pasteboard.setString(item.text, forType: .string)
    lastChangeCount = pasteboard.changeCount
    record(item.text, sourceApplication: item.sourceApplication)
  }

  func delete(_ item: ClipboardItem) {
    items.removeAll { $0.id == item.id }
    persistence.save(items)
  }

  func isFavorite(_ item: ClipboardItem) -> Bool {
    ClipboardFavoritesRules.contains(item, in: favoriteItems)
  }

  func toggleFavorite(_ item: ClipboardItem) {
    favoriteItems = ClipboardFavoritesRules.toggling(item, in: favoriteItems)
    persistence.saveFavorites(favoriteItems)
  }

  func removeFavorite(_ item: ClipboardItem) {
    favoriteItems = ClipboardFavoritesRules.removing(item, from: favoriteItems)
    persistence.saveFavorites(favoriteItems)
  }

  func clearHistory() {
    items.removeAll()
    persistence.clear()
  }

  func updateHistoryLimit(_ limit: Int) {
    UserDefaults.standard.set(max(1, limit), forKey: "historyLimit")
    enforceCurrentLimit()
    persistence.save(items)
  }

  private func pollPasteboard() {
    guard isMonitoring, pasteboard.changeCount != lastChangeCount else { return }
    captureCurrentClipboard(sourceApplication: frontmostSourceApplication())
  }

  private func captureCurrentClipboard(
    sourceApplication: ClipboardSourceApplication? = nil
  ) {
    lastChangeCount = pasteboard.changeCount
    guard let text = pasteboard.string(forType: .string) else { return }
    record(
      String(text.prefix(Self.maximumTextLength)),
      sourceApplication: sourceApplication
    )
  }

  private func record(
    _ text: String,
    sourceApplication: ClipboardSourceApplication?
  ) {
    items = ClipboardHistoryRules.inserting(
      text: text,
      sourceApplication: sourceApplication,
      into: items,
      limit: historyLimit
    )
    persistence.save(items)
  }

  private func frontmostSourceApplication() -> ClipboardSourceApplication? {
    guard let application = NSWorkspace.shared.frontmostApplication else { return nil }
    let bundleIdentifier = application.bundleIdentifier
    guard bundleIdentifier != Bundle.main.bundleIdentifier else { return nil }

    let displayName = application.localizedName ?? bundleIdentifier
    guard let displayName, !displayName.isEmpty else { return nil }
    return ClipboardSourceApplication(
      bundleIdentifier: bundleIdentifier,
      displayName: displayName
    )
  }

  private func enforceCurrentLimit() {
    items = Array(items.prefix(max(1, historyLimit)))
  }
}

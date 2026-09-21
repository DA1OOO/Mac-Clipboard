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
  private let imageCache = NSCache<NSString, NSImage>()
  private var timer: Timer?
  private var lastChangeCount: Int

  private static let defaultHistoryLimit = 100
  private static let maximumTextLength = 100_000
  private static let maximumImageByteCount = 20_000_000

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
    if let imageFileName = item.imageFileName,
      let imageData = persistence.loadImageData(fileName: imageFileName)
    {
      pasteboard.setData(imageData, forType: .png)
    }
    if item.hasTextualContent {
      pasteboard.setString(item.text, forType: .string)
    }
    lastChangeCount = pasteboard.changeCount
    record(item)
  }

  func image(for item: ClipboardItem) -> NSImage? {
    guard let imageFileName = item.imageFileName else { return nil }
    if let cached = imageCache.object(forKey: imageFileName as NSString) {
      return cached
    }
    guard let imageData = persistence.loadImageData(fileName: imageFileName),
      let image = NSImage(data: imageData)
    else { return nil }
    imageCache.setObject(image, forKey: imageFileName as NSString)
    return image
  }

  func delete(_ item: ClipboardItem) {
    items.removeAll { $0.id == item.id }
    persistAndPrune()
  }

  func isFavorite(_ item: ClipboardItem) -> Bool {
    ClipboardFavoritesRules.contains(item, in: favoriteItems)
  }

  func toggleFavorite(_ item: ClipboardItem) {
    favoriteItems = ClipboardFavoritesRules.toggling(item, in: favoriteItems)
    persistence.saveFavorites(favoriteItems)
    pruneImageFiles()
  }

  func removeFavorite(_ item: ClipboardItem) {
    favoriteItems = ClipboardFavoritesRules.removing(item, from: favoriteItems)
    persistence.saveFavorites(favoriteItems)
    pruneImageFiles()
  }

  func clearHistory() {
    items.removeAll()
    persistence.clear()
    pruneImageFiles()
  }

  func updateHistoryLimit(_ limit: Int) {
    UserDefaults.standard.set(max(1, limit), forKey: "historyLimit")
    enforceCurrentLimit()
    persistAndPrune()
  }

  private func pollPasteboard() {
    guard isMonitoring, pasteboard.changeCount != lastChangeCount else { return }
    captureCurrentClipboard(sourceApplication: frontmostSourceApplication())
  }

  private func captureCurrentClipboard(
    sourceApplication: ClipboardSourceApplication? = nil
  ) {
    lastChangeCount = pasteboard.changeCount
    if let imageItem = captureImageItem(sourceApplication: sourceApplication) {
      record(imageItem)
      return
    }
    guard let text = pasteboard.string(forType: .string) else { return }
    record(
      ClipboardItem(
        text: String(text.prefix(Self.maximumTextLength)),
        sourceApplication: sourceApplication
      )
    )
  }

  private func captureImageItem(
    sourceApplication: ClipboardSourceApplication?
  ) -> ClipboardItem? {
    guard let imageData = pngDataFromPasteboard(),
      imageData.count <= Self.maximumImageByteCount,
      let fileName = persistence.saveImageData(imageData)
    else { return nil }
    return ClipboardItem(
      text: "",
      sourceApplication: sourceApplication,
      imageFileName: fileName,
      imageByteCount: imageData.count,
      imageFingerprint: ClipboardImageFingerprint.fingerprint(of: imageData)
    )
  }

  private func pngDataFromPasteboard() -> Data? {
    if let pngData = pasteboard.data(forType: .png) {
      return pngData
    }
    guard let tiffData = pasteboard.data(forType: .tiff),
      let representation = NSBitmapImageRep(data: tiffData),
      let pngData = representation.representation(using: .png, properties: [:])
    else { return nil }
    return pngData
  }

  private func record(_ item: ClipboardItem) {
    items = ClipboardHistoryRules.inserting(
      item: item,
      into: items,
      limit: historyLimit
    )
    persistAndPrune()
  }

  private func persistAndPrune() {
    persistence.save(items)
    pruneImageFiles()
  }

  private func pruneImageFiles() {
    let removedFiles = persistence.pruneUnreferencedImageFiles(
      history: items,
      favorites: favoriteItems
    )
    for fileName in removedFiles {
      imageCache.removeObject(forKey: fileName as NSString)
    }
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

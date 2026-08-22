import Foundation
import MacClipboardCore

struct HistoryPersistence {
  private let fileManager: FileManager
  private let customHistoryURL: URL?

  init(
    fileManager: FileManager = .default,
    historyURL: URL? = nil
  ) {
    self.fileManager = fileManager
    self.customHistoryURL = historyURL
  }

  func load() -> [ClipboardItem] {
    load(from: historyURL)
  }

  func loadFavorites() -> [ClipboardItem] {
    load(from: favoritesURL)
  }

  func save(_ items: [ClipboardItem]) {
    save(items, to: historyURL, label: "history")
  }

  func saveFavorites(_ items: [ClipboardItem]) {
    save(items, to: favoritesURL, label: "favorites")
  }

  private func load(from url: URL) -> [ClipboardItem] {
    guard let data = try? Data(contentsOf: url) else { return [] }
    return (try? JSONDecoder().decode([ClipboardItem].self, from: data)) ?? []
  }

  private func save(_ items: [ClipboardItem], to url: URL, label: String) {
    do {
      try fileManager.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      let data = try JSONEncoder().encode(items)
      try data.write(to: url, options: .atomic)
    } catch {
      NSLog("MacClipboard could not save %@: %@", label, error.localizedDescription)
    }
  }

  func clear() {
    guard fileManager.fileExists(atPath: historyURL.path) else { return }
    do {
      try fileManager.removeItem(at: historyURL)
    } catch {
      NSLog("MacClipboard could not clear history: %@", error.localizedDescription)
    }
  }

  var historyURL: URL {
    if let customHistoryURL {
      return customHistoryURL
    }

    let applicationSupport =
      fileManager.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
      ).first ?? fileManager.homeDirectoryForCurrentUser

    return
      applicationSupport
      .appendingPathComponent("MacClipboard", isDirectory: true)
      .appendingPathComponent("history.json", isDirectory: false)
  }

  var favoritesURL: URL {
    historyURL
      .deletingLastPathComponent()
      .appendingPathComponent("favorites.json", isDirectory: false)
  }
}

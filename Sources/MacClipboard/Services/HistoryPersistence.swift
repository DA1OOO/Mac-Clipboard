import Foundation
import MacClipboardCore

struct HistoryPersistence {
  private let fileManager: FileManager

  init(fileManager: FileManager = .default) {
    self.fileManager = fileManager
  }

  func load() -> [ClipboardItem] {
    guard let data = try? Data(contentsOf: historyURL) else { return [] }
    return (try? JSONDecoder().decode([ClipboardItem].self, from: data)) ?? []
  }

  func save(_ items: [ClipboardItem]) {
    do {
      try fileManager.createDirectory(
        at: historyURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      let data = try JSONEncoder().encode(items)
      try data.write(to: historyURL, options: .atomic)
    } catch {
      NSLog("MacClipboard could not save history: %@", error.localizedDescription)
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
}

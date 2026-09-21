import Foundation

public struct ClipboardSourceApplication: Codable, Equatable {
  public let bundleIdentifier: String?
  public let displayName: String

  public init(bundleIdentifier: String?, displayName: String) {
    self.bundleIdentifier = bundleIdentifier
    self.displayName = displayName
  }
}

public struct ClipboardItem: Codable, Identifiable, Equatable {
  public let id: UUID
  public let text: String
  public var capturedAt: Date
  public var sourceApplication: ClipboardSourceApplication?
  public let imageFileName: String?
  public let imageByteCount: Int?
  public let imageFingerprint: String?

  public init(
    id: UUID = UUID(),
    text: String,
    capturedAt: Date = Date(),
    sourceApplication: ClipboardSourceApplication? = nil,
    imageFileName: String? = nil,
    imageByteCount: Int? = nil,
    imageFingerprint: String? = nil
  ) {
    self.id = id
    self.text = text
    self.capturedAt = capturedAt
    self.sourceApplication = sourceApplication
    self.imageFileName = imageFileName
    self.imageByteCount = imageByteCount
    self.imageFingerprint = imageFingerprint
  }

  public var hasImage: Bool {
    imageFileName != nil
  }

  public var hasTextualContent: Bool {
    !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  public func hasSameContent(as other: ClipboardItem) -> Bool {
    if let fingerprint = imageFingerprint, let otherFingerprint = other.imageFingerprint {
      return fingerprint == otherFingerprint
    }
    return !hasImage && !other.hasImage && text == other.text
  }

  public var singleLinePreview: String {
    text
      .replacingOccurrences(of: "\r\n", with: " ")
      .replacingOccurrences(of: "\n", with: " ")
      .replacingOccurrences(of: "\r", with: " ")
  }
}

public enum ClipboardImageFingerprint {
  public static func fingerprint(of data: Data) -> String {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    for byte in data {
      hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01b3
    }
    return String(format: "%016llx", hash)
  }
}

public enum ClipboardHistoryRules {
  public static func inserting(
    item: ClipboardItem,
    into items: [ClipboardItem],
    limit: Int
  ) -> [ClipboardItem] {
    guard item.hasImage || item.hasTextualContent else {
      return items
    }

    var updated = items
    if let existingIndex = updated.firstIndex(where: { $0.hasSameContent(as: item) }) {
      var existing = updated.remove(at: existingIndex)
      existing.capturedAt = item.capturedAt
      existing.sourceApplication = item.sourceApplication
      updated.insert(existing, at: 0)
    } else {
      updated.insert(item, at: 0)
    }

    return Array(updated.prefix(max(1, limit)))
  }

  public static func inserting(
    text: String,
    capturedAt: Date = Date(),
    sourceApplication: ClipboardSourceApplication? = nil,
    into items: [ClipboardItem],
    limit: Int
  ) -> [ClipboardItem] {
    inserting(
      item: ClipboardItem(
        text: text,
        capturedAt: capturedAt,
        sourceApplication: sourceApplication
      ),
      into: items,
      limit: limit
    )
  }
}

public enum ClipboardFavoritesRules {
  public static func contains(_ item: ClipboardItem, in favorites: [ClipboardItem]) -> Bool {
    favorites.contains { $0.hasSameContent(as: item) }
  }

  public static func toggling(
    _ item: ClipboardItem,
    favoritedAt: Date = Date(),
    in favorites: [ClipboardItem]
  ) -> [ClipboardItem] {
    if contains(item, in: favorites) {
      return removing(item, from: favorites)
    }

    var favorite = item
    favorite.capturedAt = favoritedAt
    return [favorite] + favorites
  }

  public static func removing(
    _ item: ClipboardItem,
    from favorites: [ClipboardItem]
  ) -> [ClipboardItem] {
    favorites.filter { !$0.hasSameContent(as: item) }
  }
}

public enum ClipboardSelectionDirection {
  case previous
  case next
}

public enum ClipboardSelectionRules {
  public static func movingSelection(
    from selectedID: UUID?,
    direction: ClipboardSelectionDirection,
    in items: [ClipboardItem]
  ) -> UUID? {
    guard !items.isEmpty else { return nil }

    guard let selectedID,
      let selectedIndex = items.firstIndex(where: { $0.id == selectedID })
    else {
      return direction == .next ? items.first?.id : items.last?.id
    }

    switch direction {
    case .previous:
      return items[max(0, selectedIndex - 1)].id
    case .next:
      return items[min(items.count - 1, selectedIndex + 1)].id
    }
  }
}

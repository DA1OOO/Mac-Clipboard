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

  public init(
    id: UUID = UUID(),
    text: String,
    capturedAt: Date = Date(),
    sourceApplication: ClipboardSourceApplication? = nil
  ) {
    self.id = id
    self.text = text
    self.capturedAt = capturedAt
    self.sourceApplication = sourceApplication
  }

  public var singleLinePreview: String {
    text
      .replacingOccurrences(of: "\r\n", with: " ")
      .replacingOccurrences(of: "\n", with: " ")
      .replacingOccurrences(of: "\r", with: " ")
  }
}

public enum ClipboardHistoryRules {
  public static func inserting(
    text: String,
    capturedAt: Date = Date(),
    sourceApplication: ClipboardSourceApplication? = nil,
    into items: [ClipboardItem],
    limit: Int
  ) -> [ClipboardItem] {
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return items
    }

    var updated = items
    if let existingIndex = updated.firstIndex(where: { $0.text == text }) {
      var existing = updated.remove(at: existingIndex)
      existing.capturedAt = capturedAt
      existing.sourceApplication = sourceApplication
      updated.insert(existing, at: 0)
    } else {
      updated.insert(
        ClipboardItem(
          text: text,
          capturedAt: capturedAt,
          sourceApplication: sourceApplication
        ),
        at: 0
      )
    }

    return Array(updated.prefix(max(1, limit)))
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

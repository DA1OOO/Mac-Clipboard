import Foundation

public struct ClipboardItem: Codable, Identifiable, Equatable {
  public let id: UUID
  public let text: String
  public var capturedAt: Date

  public init(id: UUID = UUID(), text: String, capturedAt: Date = Date()) {
    self.id = id
    self.text = text
    self.capturedAt = capturedAt
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
      updated.insert(existing, at: 0)
    } else {
      updated.insert(ClipboardItem(text: text, capturedAt: capturedAt), at: 0)
    }

    return Array(updated.prefix(max(1, limit)))
  }
}

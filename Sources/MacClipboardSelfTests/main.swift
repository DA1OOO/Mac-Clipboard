import Foundation
import MacClipboardCore

@main
enum MacClipboardSelfTests {
  static func main() {
    var failures: [String] = []

    let limited = ClipboardHistoryRules.inserting(
      text: "three",
      into: [ClipboardItem(text: "two"), ClipboardItem(text: "one")],
      limit: 2
    )
    expect(
      limited.map(\.text) == ["three", "two"],
      "new entries should be first and respect the history limit",
      failures: &failures
    )

    let duplicate = ClipboardItem(text: "same")
    let deduplicated = ClipboardHistoryRules.inserting(
      text: "same",
      into: [ClipboardItem(text: "newer"), duplicate],
      limit: 10
    )
    expect(
      deduplicated.count == 2 && deduplicated.first?.id == duplicate.id,
      "duplicates should move to the front without changing identity",
      failures: &failures
    )

    let original = [ClipboardItem(text: "kept")]
    let blankResult = ClipboardHistoryRules.inserting(
      text: "  \n ",
      into: original,
      limit: 10
    )
    expect(
      blankResult == original,
      "blank clipboard values should be ignored",
      failures: &failures
    )

    let candidates = [
      ClipboardItem(text: "first"),
      ClipboardItem(text: "second"),
      ClipboardItem(text: "third"),
    ]
    let selectedFirst = ClipboardSelectionRules.movingSelection(
      from: nil,
      direction: .next,
      in: candidates
    )
    expect(
      selectedFirst == candidates.first?.id,
      "moving down without a selection should select the first candidate",
      failures: &failures
    )

    let selectedSecond = ClipboardSelectionRules.movingSelection(
      from: selectedFirst,
      direction: .next,
      in: candidates
    )
    expect(
      selectedSecond == candidates[1].id,
      "moving down should select the next candidate",
      failures: &failures
    )

    let selectedPrevious = ClipboardSelectionRules.movingSelection(
      from: selectedSecond,
      direction: .previous,
      in: candidates
    )
    expect(
      selectedPrevious == candidates[0].id,
      "moving up should select the previous candidate",
      failures: &failures
    )

    let selectedLast = ClipboardSelectionRules.movingSelection(
      from: nil,
      direction: .previous,
      in: candidates
    )
    expect(
      selectedLast == candidates.last?.id,
      "moving up without a selection should select the last candidate",
      failures: &failures
    )

    let clampedSelection = ClipboardSelectionRules.movingSelection(
      from: candidates.last?.id,
      direction: .next,
      in: candidates
    )
    expect(
      clampedSelection == candidates.last?.id,
      "moving beyond the candidate list should keep the edge selection",
      failures: &failures
    )

    let sourceApplication = ClipboardSourceApplication(
      bundleIdentifier: "com.example.source",
      displayName: "Source App"
    )
    let attributed = ClipboardHistoryRules.inserting(
      text: "attributed",
      sourceApplication: sourceApplication,
      into: [],
      limit: 10
    )
    expect(
      attributed.first?.sourceApplication == sourceApplication,
      "new entries should retain their source application",
      failures: &failures
    )

    let updatedSourceApplication = ClipboardSourceApplication(
      bundleIdentifier: "com.example.updated-source",
      displayName: "Updated Source App"
    )
    let updatedAttribution = ClipboardHistoryRules.inserting(
      text: "attributed",
      sourceApplication: updatedSourceApplication,
      into: attributed,
      limit: 10
    )
    expect(
      updatedAttribution.first?.sourceApplication == updatedSourceApplication,
      "duplicates should use the latest source application",
      failures: &failures
    )

    let legacyJSON = """
      [{"id":"00000000-0000-0000-0000-000000000001","text":"legacy","capturedAt":0}]
      """
    let legacyItems = try? JSONDecoder().decode(
      [ClipboardItem].self,
      from: Data(legacyJSON.utf8)
    )
    expect(
      legacyItems?.first?.sourceApplication == nil,
      "history saved before source attribution should remain readable",
      failures: &failures
    )

    let favoriteDate = Date(timeIntervalSince1970: 123)
    let favoriteCandidate = ClipboardItem(text: "favorite")
    let favorites = ClipboardFavoritesRules.toggling(
      favoriteCandidate,
      favoritedAt: favoriteDate,
      in: []
    )
    expect(
      favorites.first?.id == favoriteCandidate.id
        && favorites.first?.capturedAt == favoriteDate,
      "favoriting should preserve identity and record when it was favorited",
      failures: &failures
    )

    let sameFavoriteText = ClipboardItem(text: "favorite")
    expect(
      ClipboardFavoritesRules.contains(sameFavoriteText, in: favorites),
      "favorites should match equivalent clipboard text",
      failures: &failures
    )

    let toggledOff = ClipboardFavoritesRules.toggling(
      sameFavoriteText,
      in: favorites
    )
    expect(
      toggledOff.isEmpty,
      "favoriting an existing value again should remove it",
      failures: &failures
    )

    let retainedFavorite = ClipboardItem(text: "retained favorite")
    let removalResult = ClipboardFavoritesRules.removing(
      favoriteCandidate,
      from: [favoriteCandidate, retainedFavorite]
    )
    expect(
      removalResult == [retainedFavorite],
      "removing a favorite should retain unrelated favorites",
      failures: &failures
    )

    if failures.isEmpty {
      print("MacClipboard self-tests passed (15 checks).")
    } else {
      for failure in failures {
        fputs("FAILED: \(failure)\n", stderr)
      }
      exit(1)
    }
  }

  private static func expect(
    _ condition: @autoclosure () -> Bool,
    _ message: String,
    failures: inout [String]
  ) {
    if !condition() {
      failures.append(message)
    }
  }
}

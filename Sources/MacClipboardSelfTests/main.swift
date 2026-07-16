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

    if failures.isEmpty {
      print("MacClipboard self-tests passed (3 checks).")
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

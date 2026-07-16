import AppKit
import MacClipboardCore
import SwiftUI

struct ClipboardHistoryView: View {
  @ObservedObject var store: ClipboardStore
  let dismiss: () -> Void

  @State private var searchText = ""
  @State private var page: Page = .history
  @FocusState private var searchIsFocused: Bool

  private enum Page {
    case history
    case settings
  }

  private var filteredItems: [ClipboardItem] {
    guard !searchText.isEmpty else { return store.items }
    return store.items.filter {
      $0.text.localizedCaseInsensitiveContains(searchText)
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()

      switch page {
      case .history:
        historyContent
      case .settings:
        SettingsView(store: store)
      }

      Divider()
      footer
    }
    .frame(width: 440, height: 520)
    .background(.regularMaterial)
    .onAppear {
      if page == .history {
        searchIsFocused = true
      }
    }
  }

  private var header: some View {
    HStack(spacing: 10) {
      if page == .settings {
        Button {
          page = .history
          searchIsFocused = true
        } label: {
          Image(systemName: "chevron.left")
        }
        .buttonStyle(.plain)
        .help("Back to clipboard history")
      }

      Image(systemName: "doc.on.clipboard.fill")
        .foregroundStyle(.tint)

      Text(page == .history ? "Clipboard History" : "Settings")
        .font(.headline)

      Spacer()

      Text("\(store.items.count)")
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)

      Button {
        page = page == .history ? .settings : .history
      } label: {
        Image(systemName: page == .history ? "gearshape" : "xmark")
      }
      .buttonStyle(.plain)
      .help(page == .history ? "Settings" : "Back")
    }
    .padding(.horizontal, 14)
    .frame(height: 44)
  }

  private var historyContent: some View {
    VStack(spacing: 0) {
      HStack(spacing: 8) {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(.secondary)
        TextField("Search clipboard history", text: $searchText)
          .textFieldStyle(.plain)
          .focused($searchIsFocused)
          .onSubmit {
            if let first = filteredItems.first {
              copyAndDismiss(first)
            }
          }
        if !searchText.isEmpty {
          Button {
            searchText = ""
          } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundStyle(.secondary)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 12)
      .frame(height: 38)
      .background(Color(nsColor: .controlBackgroundColor))

      Divider()

      if filteredItems.isEmpty {
        emptyState
      } else {
        List {
          ForEach(filteredItems) { item in
            ClipboardRow(item: item) {
              copyAndDismiss(item)
            }
            .contextMenu {
              Button("Copy") {
                copyAndDismiss(item)
              }
              Divider()
              Button("Delete", role: .destructive) {
                store.delete(item)
              }
            }
          }
        }
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 48)
      }
    }
  }

  private var emptyState: some View {
    VStack(spacing: 10) {
      Spacer()
      Image(systemName: searchText.isEmpty ? "clipboard" : "magnifyingglass")
        .font(.system(size: 34))
        .foregroundStyle(.tertiary)
      Text(searchText.isEmpty ? "Copy some text to get started" : "No matching clips")
        .font(.headline)
      Text(
        searchText.isEmpty
          ? "Text you copy will appear here automatically." : "Try a different search term."
      )
      .font(.caption)
      .foregroundStyle(.secondary)
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var footer: some View {
    HStack {
      Circle()
        .fill(store.isMonitoring ? Color.green : Color.orange)
        .frame(width: 7, height: 7)
      Text(store.isMonitoring ? "Monitoring locally" : "Monitoring paused")
        .font(.caption)
        .foregroundStyle(.secondary)

      Spacer()

      Text("⌘⇧V")
        .font(.caption.monospaced())
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))

      Button("Quit") {
        NSApp.terminate(nil)
      }
      .buttonStyle(.plain)
      .font(.caption)
    }
    .padding(.horizontal, 14)
    .frame(height: 38)
  }

  private func copyAndDismiss(_ item: ClipboardItem) {
    store.copy(item)
    dismiss()
  }
}

private struct ClipboardRow: View {
  let item: ClipboardItem
  let copy: () -> Void

  var body: some View {
    Button(action: copy) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "text.alignleft")
          .foregroundStyle(.secondary)
          .frame(width: 18)

        VStack(alignment: .leading, spacing: 4) {
          Text(item.singleLinePreview)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
          Text(item.capturedAt, style: .relative)
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
      }
      .contentShape(Rectangle())
      .padding(.vertical, 4)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Copy \(item.singleLinePreview)")
  }
}

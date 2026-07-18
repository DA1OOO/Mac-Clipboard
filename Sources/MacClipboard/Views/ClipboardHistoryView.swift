import AppKit
import Carbon.HIToolbox
import MacClipboardCore
import SwiftUI

struct ClipboardHistoryView: View {
  @ObservedObject var store: ClipboardStore
  @ObservedObject var globalHotKey: GlobalHotKey
  @ObservedObject var focusedInputPaster: FocusedInputPaster
  let panelCommandRouter: PanelCommandRouter
  let historyCommandsChanged: (Bool) -> Void
  let dismiss: () -> Void

  @State private var searchText = ""
  @State private var page: Page = .history
  @State private var selectedItemID: UUID?
  @FocusState private var searchIsFocused: Bool

  init(
    store: ClipboardStore,
    globalHotKey: GlobalHotKey,
    focusedInputPaster: FocusedInputPaster,
    panelCommandRouter: PanelCommandRouter,
    historyCommandsChanged: @escaping (Bool) -> Void = { _ in },
    dismiss: @escaping () -> Void
  ) {
    self.store = store
    self.globalHotKey = globalHotKey
    self.focusedInputPaster = focusedInputPaster
    self.panelCommandRouter = panelCommandRouter
    self.historyCommandsChanged = historyCommandsChanged
    self.dismiss = dismiss
    _selectedItemID = State(initialValue: store.items.first?.id)
  }

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
        SettingsView(
          store: store,
          globalHotKey: globalHotKey,
          focusedInputPaster: focusedInputPaster
        )
      }

      Divider()
      footer
    }
    .frame(width: 440, height: 520)
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .onAppear {
      historyCommandsChanged(page == .history)
      if page == .history {
        selectedItemID = filteredItems.first?.id
      }
    }
    .onChange(of: page) { newPage in
      let historyIsVisible = newPage == .history
      historyCommandsChanged(historyIsVisible)
      guard historyIsVisible else { return }
      selectedItemID = filteredItems.first?.id
    }
    .onChange(of: searchText) { _ in
      selectedItemID = filteredItems.first?.id
    }
    .onChange(of: filteredItems.map(\.id)) { itemIDs in
      if let selectedItemID, itemIDs.contains(selectedItemID) {
        return
      }
      selectedItemID = itemIDs.first
    }
    .background(
      LocalKeyEventMonitor(isEnabled: page == .history) { event in
        handleHistoryKeyEvent(event)
      }
    )
    .onReceive(panelCommandRouter.commands) { command in
      handlePanelCommand(command)
    }
  }

  private var header: some View {
    HStack(spacing: 10) {
      if page == .settings {
        Button {
          page = .history
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
            submitSelectedCandidate()
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
        ScrollViewReader { proxy in
          List {
            ForEach(filteredItems) { item in
              ClipboardRow(
                item: item,
                isSelected: selectedItemID == item.id
              ) {
                copyAndDismiss(item)
              }
              .id(item.id)
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
          .onChange(of: selectedItemID) { selectedItemID in
            if let selectedItemID {
              withAnimation(.easeOut(duration: 0.1)) {
                proxy.scrollTo(selectedItemID, anchor: .center)
              }
            }
          }
        }
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

      Text(globalHotKey.shortcut.displayString)
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

  private func moveSelection(_ direction: ClipboardSelectionDirection) {
    selectedItemID = ClipboardSelectionRules.movingSelection(
      from: selectedItemID,
      direction: direction,
      in: filteredItems
    )
  }

  private func submitSelectedCandidate() {
    let item =
      selectedItemID.flatMap { selectedItemID in
        filteredItems.first { $0.id == selectedItemID }
      } ?? filteredItems.first

    if let item {
      store.copy(item)
      dismiss()
      focusedInputPaster.pasteIntoRememberedInput()
    }
  }

  private func handleHistoryKeyEvent(_ event: NSEvent) -> Bool {
    let navigationModifiers: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
    guard event.modifierFlags.intersection(navigationModifiers).isEmpty else {
      return false
    }

    switch Int(event.keyCode) {
    case kVK_UpArrow:
      moveSelection(.previous)
      return !filteredItems.isEmpty
    case kVK_DownArrow:
      moveSelection(.next)
      return !filteredItems.isEmpty
    case kVK_Return, kVK_ANSI_KeypadEnter:
      guard !filteredItems.isEmpty else { return false }
      submitSelectedCandidate()
      return true
    default:
      return false
    }
  }

  private func handlePanelCommand(_ command: PanelCommand) {
    switch command {
    case .previous:
      guard page == .history else { return }
      moveSelection(.previous)
    case .next:
      guard page == .history else { return }
      moveSelection(.next)
    case .submit:
      guard page == .history, !filteredItems.isEmpty else { return }
      submitSelectedCandidate()
    case .dismiss:
      dismiss()
    case .panelWillOpen:
      searchIsFocused = false
    case .panelWillClose:
      searchIsFocused = false
    }
  }
}

private struct ClipboardRow: View {
  let item: ClipboardItem
  let isSelected: Bool
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
      .padding(.horizontal, 6)
      .padding(.vertical, 4)
      .background(
        isSelected ? Color.accentColor.opacity(0.16) : Color.clear,
        in: RoundedRectangle(cornerRadius: 6)
      )
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Copy \(item.singleLinePreview)")
  }
}

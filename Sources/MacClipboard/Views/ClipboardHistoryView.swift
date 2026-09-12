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
  @State private var activeTab: ClipboardTab = .history
  @State private var selectedItemID: UUID?
  @State private var showingClearConfirmation = false
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

  private enum ClipboardTab: String, CaseIterable, Identifiable {
    case history
    case favorites

    var id: Self { self }

    var title: String {
      switch self {
      case .history:
        "History"
      case .favorites:
        "Favorites"
      }
    }

    var systemImage: String {
      switch self {
      case .history:
        "clock.arrow.circlepath"
      case .favorites:
        "star.fill"
      }
    }
  }

  private var visibleItems: [ClipboardItem] {
    switch activeTab {
    case .history:
      store.items
    case .favorites:
      store.favoriteItems
    }
  }

  private var filteredItems: [ClipboardItem] {
    guard !searchText.isEmpty else { return visibleItems }
    return visibleItems.filter {
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
    .frame(width: 440)
    .frame(maxHeight: .infinity)
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
    .onChange(of: activeTab) { _ in
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
    .confirmationDialog(
      "Clear all clipboard history?",
      isPresented: $showingClearConfirmation
    ) {
      Button("Clear History", role: .destructive) {
        store.clearHistory()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Favorites will be kept. This cannot be undone.")
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

      Text("\(page == .history ? visibleItems.count : store.items.count)")
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)

      if page == .history, activeTab == .history {
        Button {
          showingClearConfirmation = true
        } label: {
          Image(systemName: "trash")
        }
        .buttonStyle(.plain)
        .disabled(store.items.isEmpty)
        .help("Clear clipboard history")
        .accessibilityLabel("Clear clipboard history")
      }

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
      Picker("Clipboard section", selection: $activeTab) {
        ForEach(ClipboardTab.allCases) { tab in
          Label(tab.title, systemImage: tab.systemImage)
            .tag(tab)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .padding(.horizontal, 12)
      .padding(.vertical, 8)

      Divider()

      HStack(spacing: 8) {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(.secondary)
        TextField(
          activeTab == .history ? "Search clipboard history" : "Search favorites",
          text: $searchText
        )
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
            ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
              ClipboardRow(
                item: item,
                isSelected: selectedItemID == item.id,
                isFavorite: store.isFavorite(item),
                shortcutKey: candidateShortcutKey(at: index)
              ) {
                copyAndDismiss(item)
              }
              .id(item.id)
              .contextMenu {
                Button("Copy") {
                  copyAndDismiss(item)
                }
                if activeTab == .favorites {
                  Button("Remove from Favorites") {
                    store.removeFavorite(item)
                  }
                } else {
                  Button(store.isFavorite(item) ? "Remove from Favorites" : "Add to Favorites") {
                    store.toggleFavorite(item)
                  }
                }
                if activeTab == .history {
                  Divider()
                  Button("Delete", role: .destructive) {
                    store.delete(item)
                  }
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
      Image(systemName: emptyStateSystemImage)
        .font(.system(size: 34))
        .foregroundStyle(.tertiary)
      Text(emptyStateTitle)
        .font(.headline)
      Text(emptyStateMessage)
        .font(.caption)
        .foregroundStyle(.secondary)
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var emptyStateSystemImage: String {
    if !searchText.isEmpty { return "magnifyingglass" }
    return activeTab == .history ? "clipboard" : "star"
  }

  private var emptyStateTitle: String {
    if !searchText.isEmpty { return "No matching clips" }
    return activeTab == .history ? "Copy some text to get started" : "No favorites yet"
  }

  private var emptyStateMessage: String {
    if !searchText.isEmpty { return "Try a different search term." }
    return activeTab == .history
      ? "Text you copy will appear here automatically."
      : "Right-click a clipboard item and add it to Favorites."
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

  private func submitCandidate(at index: Int) {
    guard filteredItems.indices.contains(index) else { return }
    let item = filteredItems[index]
    selectedItemID = item.id
    store.copy(item)
    dismiss()
    focusedInputPaster.pasteIntoRememberedInput()
  }

  private func handleHistoryKeyEvent(_ event: NSEvent) -> Bool {
    let navigationModifiers: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
    let modifiers = event.modifierFlags.intersection(navigationModifiers)
    if modifiers == globalHotKey.candidateShortcutModifier.eventModifierFlag,
      let index = candidateIndex(for: Int(event.keyCode))
    {
      guard filteredItems.indices.contains(index) else { return false }
      submitCandidate(at: index)
      return true
    }

    guard modifiers.isEmpty else {
      return false
    }

    switch Int(event.keyCode) {
    case kVK_UpArrow:
      moveSelection(.previous)
      return !filteredItems.isEmpty
    case kVK_DownArrow:
      moveSelection(.next)
      return !filteredItems.isEmpty
    case kVK_LeftArrow:
      activeTab = .history
      return true
    case kVK_RightArrow:
      activeTab = .favorites
      return true
    case kVK_Return, kVK_ANSI_KeypadEnter:
      guard !filteredItems.isEmpty else { return false }
      submitSelectedCandidate()
      return true
    default:
      return false
    }
  }

  private func candidateIndex(for keyCode: Int) -> Int? {
    switch keyCode {
    case kVK_ANSI_0: 9
    case kVK_ANSI_1: 0
    case kVK_ANSI_2: 1
    case kVK_ANSI_3: 2
    case kVK_ANSI_4: 3
    case kVK_ANSI_5: 4
    case kVK_ANSI_6: 5
    case kVK_ANSI_7: 6
    case kVK_ANSI_8: 7
    case kVK_ANSI_9: 8
    default: nil
    }
  }

  private func candidateShortcutKey(at index: Int) -> String? {
    guard (0..<10).contains(index) else { return nil }
    let numberKey = index == 9 ? "0" : String(index + 1)
    return globalHotKey.candidateShortcutModifier.symbol + numberKey
  }

  private func handlePanelCommand(_ command: PanelCommand) {
    switch command {
    case .previous:
      guard page == .history else { return }
      moveSelection(.previous)
    case .next:
      guard page == .history else { return }
      moveSelection(.next)
    case .previousTab:
      guard page == .history else { return }
      activeTab = .history
    case .nextTab:
      guard page == .history else { return }
      activeTab = .favorites
    case .selectCandidate(let index):
      guard page == .history else { return }
      submitCandidate(at: index)
    case .submit:
      guard page == .history, !filteredItems.isEmpty else { return }
      submitSelectedCandidate()
    case .dismiss:
      dismiss()
    case .panelWillOpen:
      page = .history
      activeTab = .history
      searchText = ""
      selectedItemID = store.items.first?.id
      searchIsFocused = false
    case .panelWillClose:
      searchIsFocused = false
    }
  }
}

private struct ClipboardRow: View {
  let item: ClipboardItem
  let isSelected: Bool
  let isFavorite: Bool
  let shortcutKey: String?
  let copy: () -> Void

  var body: some View {
    Button(action: copy) {
      HStack(alignment: .top, spacing: 10) {
        sourceApplicationIcon

        VStack(alignment: .leading, spacing: 4) {
          Text(isSelected ? item.text : item.singleLinePreview)
            .lineLimit(isSelected ? 8 : 2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
          HStack(spacing: 4) {
            if let sourceApplication = item.sourceApplication {
              Text(sourceApplication.displayName)
              Text("·")
            }
            Text(item.capturedAt, style: .relative)
          }
          .font(.caption2)
          .foregroundStyle(.tertiary)
        }

        if isFavorite {
          Image(systemName: "star.fill")
            .font(.caption)
            .foregroundStyle(.yellow)
            .help("Favorite")
        }

        if let shortcutKey {
          Text(shortcutKey)
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
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

  @ViewBuilder
  private var sourceApplicationIcon: some View {
    if let sourceApplication = item.sourceApplication,
      let icon = ApplicationIconProvider.shared.icon(for: sourceApplication)
    {
      Image(nsImage: icon)
        .resizable()
        .scaledToFit()
        .frame(width: 22, height: 22)
        .help("Copied from \(sourceApplication.displayName)")
    } else {
      Image(systemName: "app.dashed")
        .foregroundStyle(.secondary)
        .frame(width: 22, height: 22)
        .help("Source application unavailable")
    }
  }
}

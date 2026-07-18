import AppKit
import Carbon.HIToolbox
import SwiftUI

struct SettingsView: View {
  @ObservedObject var store: ClipboardStore
  @ObservedObject var globalHotKey: GlobalHotKey
  @ObservedObject var focusedInputPaster: FocusedInputPaster
  @AppStorage("historyLimit") private var historyLimit = 100
  @State private var showingClearConfirmation = false

  private let availableLimits = [25, 50, 100, 200, 500]

  var body: some View {
    Form {
      Section("History") {
        Picker("Maximum clips", selection: $historyLimit) {
          ForEach(availableLimits, id: \.self) { limit in
            Text("\(limit)").tag(limit)
          }
        }
        .onChange(of: historyLimit) { newValue in
          store.updateHistoryLimit(newValue)
        }

        Toggle(
          "Monitor clipboard",
          isOn: Binding(
            get: { store.isMonitoring },
            set: { enabled in
              if enabled != store.isMonitoring {
                store.toggleMonitoring()
              }
            }
          )
        )

        Button("Clear Clipboard History", role: .destructive) {
          showingClearConfirmation = true
        }
      }

      Section("Privacy") {
        Label("History stays on this Mac", systemImage: "lock.shield")
        Text(store.storageURL.path)
          .font(.caption)
          .foregroundStyle(.secondary)
          .textSelection(.enabled)

        LabeledContent("Paste on Return") {
          Label(
            focusedInputPaster.isAccessibilityTrusted ? "Allowed" : "Permission Required",
            systemImage: focusedInputPaster.isAccessibilityTrusted
              ? "checkmark.circle.fill" : "exclamationmark.triangle"
          )
          .foregroundStyle(
            focusedInputPaster.isAccessibilityTrusted ? Color.green : Color.orange
          )
        }

        Text("Return pastes into the text cursor that was active before the panel opened.")
          .font(.caption)
          .foregroundStyle(.secondary)

        if !focusedInputPaster.isAccessibilityTrusted {
          Button("Allow Accessibility Access") {
            focusedInputPaster.requestPermission()
          }
        }
      }

      Section("Shortcut") {
        ShortcutRecorderRow(globalHotKey: globalHotKey)
      }
    }
    .formStyle(.grouped)
    .padding(.horizontal, 8)
    .onAppear {
      focusedInputPaster.refreshPermission()
    }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))
    {
      _ in
      focusedInputPaster.refreshPermission()
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
      Text("This cannot be undone.")
    }
  }
}

private struct ShortcutRecorderRow: View {
  @ObservedObject var globalHotKey: GlobalHotKey

  @State private var isRecording = false
  @State private var validationMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      LabeledContent("Show clipboard history") {
        Button {
          validationMessage = nil
          isRecording.toggle()
        } label: {
          Text(isRecording ? "Press shortcut…" : globalHotKey.shortcut.displayString)
            .font(.body.monospaced())
            .frame(minWidth: 86)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(
          isRecording
            ? "Waiting for a new keyboard shortcut"
            : "Current shortcut \(globalHotKey.shortcut.displayString)"
        )
      }

      if isRecording {
        Text("Press the new shortcut, or Esc to cancel.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      if let message = validationMessage ?? globalHotKey.registrationError {
        Text(message)
          .font(.caption)
          .foregroundStyle(.red)
      }

      Button("Restore Default") {
        validationMessage = nil
        isRecording = false
        globalHotKey.restoreDefault()
      }
      .disabled(globalHotKey.shortcut == .standard)
    }
    .background(
      LocalKeyEventMonitor(isEnabled: isRecording) { event in
        capture(event)
      }
    )
    .onDisappear {
      isRecording = false
    }
  }

  private func capture(_ event: NSEvent) -> Bool {
    let shortcutModifiers: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
    let pressedModifiers = event.modifierFlags.intersection(shortcutModifiers)

    if Int(event.keyCode) == kVK_Escape, pressedModifiers.isEmpty {
      isRecording = false
      validationMessage = nil
      return true
    }

    guard let shortcut = GlobalHotKey.Shortcut(event: event) else {
      validationMessage = "Use ⌘, ⌥, or ⌃ with a key, or choose a function key."
      return true
    }

    isRecording = false
    validationMessage = nil
    globalHotKey.updateShortcut(shortcut)
    return true
  }
}

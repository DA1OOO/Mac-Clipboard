import SwiftUI

struct SettingsView: View {
  @ObservedObject var store: ClipboardStore
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
      }

      Section("Shortcut") {
        LabeledContent("Show clipboard history", value: "⌘⇧V")
      }
    }
    .formStyle(.grouped)
    .padding(.horizontal, 8)
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

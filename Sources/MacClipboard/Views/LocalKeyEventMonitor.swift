import AppKit
import SwiftUI

struct LocalKeyEventMonitor: NSViewRepresentable {
  let isEnabled: Bool
  let handler: (NSEvent) -> Bool

  func makeCoordinator() -> Coordinator {
    Coordinator(handler: handler)
  }

  func makeNSView(context: Context) -> NSView {
    let view = NSView(frame: .zero)
    context.coordinator.view = view
    context.coordinator.update(isEnabled: isEnabled, handler: handler)
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    context.coordinator.view = nsView
    context.coordinator.update(isEnabled: isEnabled, handler: handler)
  }

  static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
    coordinator.stopMonitoring()
  }

  final class Coordinator {
    weak var view: NSView?

    private var handler: (NSEvent) -> Bool
    private var monitor: Any?

    init(handler: @escaping (NSEvent) -> Bool) {
      self.handler = handler
    }

    deinit {
      stopMonitoring()
    }

    func update(isEnabled: Bool, handler: @escaping (NSEvent) -> Bool) {
      self.handler = handler
      isEnabled ? startMonitoring() : stopMonitoring()
    }

    func stopMonitoring() {
      guard let monitor else { return }
      NSEvent.removeMonitor(monitor)
      self.monitor = nil
    }

    private func startMonitoring() {
      guard monitor == nil else { return }
      monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
        guard let self,
          self.view?.window?.isKeyWindow == true
        else {
          return event
        }

        return self.handler(event) ? nil : event
      }
    }
  }
}

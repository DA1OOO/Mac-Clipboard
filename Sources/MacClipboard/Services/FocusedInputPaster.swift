import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Combine
import CoreGraphics
import Foundation

@MainActor
final class FocusedInputPaster: ObservableObject {
  struct TargetApplication {
    let processIdentifier: pid_t
    let activate: @MainActor () -> Bool
  }

  struct Dependencies {
    let currentProcessIdentifier: @MainActor () -> pid_t
    let frontmostApplication: @MainActor () -> TargetApplication?
    let frontmostProcessIdentifier: @MainActor () -> pid_t?
    let isAccessibilityTrusted: @MainActor () -> Bool
    let requestAccessibilityAccess: @MainActor () -> Void
    let postPasteShortcut: @MainActor (pid_t) -> Void
    let scheduleRetry: (@escaping @MainActor @Sendable () -> Void) -> Void

    static let system = Dependencies(
      currentProcessIdentifier: {
        ProcessInfo.processInfo.processIdentifier
      },
      frontmostApplication: {
        guard let application = NSWorkspace.shared.frontmostApplication else {
          return nil
        }

        return TargetApplication(
          processIdentifier: application.processIdentifier,
          activate: {
            if #available(macOS 14.0, *) {
              NSApplication.shared.yieldActivation(to: application)
              return application.activate(
                from: .current,
                options: [.activateAllWindows]
              )
            }

            return application.activate(
              options: [.activateAllWindows]
            )
          }
        )
      },
      frontmostProcessIdentifier: {
        NSWorkspace.shared.frontmostApplication?.processIdentifier
      },
      isAccessibilityTrusted: {
        AXIsProcessTrustedWithOptions(nil)
      },
      requestAccessibilityAccess: {
        let options =
          [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
          ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
      },
      postPasteShortcut: { processIdentifier in
        FocusedInputPaster.postPasteShortcut(to: processIdentifier)
      },
      scheduleRetry: { action in
        Task { @MainActor in
          try? await Task.sleep(nanoseconds: 60_000_000)
          action()
        }
      }
    )
  }

  @Published private(set) var isAccessibilityTrusted: Bool

  private let dependencies: Dependencies
  private var rememberedApplication: TargetApplication?

  init(dependencies: Dependencies = .system) {
    self.dependencies = dependencies
    self.isAccessibilityTrusted = dependencies.isAccessibilityTrusted()
  }

  func rememberFrontmostApplication() {
    guard let application = dependencies.frontmostApplication(),
      application.processIdentifier != dependencies.currentProcessIdentifier()
    else {
      rememberedApplication = nil
      return
    }

    rememberedApplication = application
  }

  func pasteIntoRememberedInput() {
    guard let application = rememberedApplication else { return }
    rememberedApplication = nil
    refreshPermission()

    guard isAccessibilityTrusted else {
      requestPermission()
      return
    }

    if dependencies.frontmostProcessIdentifier() != application.processIdentifier {
      guard application.activate() else { return }
    }
    dependencies.scheduleRetry { [weak self] in
      self?.pasteWhenTargetIsReady(
        application: application,
        attemptsRemaining: 20
      )
    }
  }

  func requestPermission() {
    dependencies.requestAccessibilityAccess()
    refreshPermission()
  }

  func refreshPermission() {
    isAccessibilityTrusted = dependencies.isAccessibilityTrusted()
  }

  private func pasteWhenTargetIsReady(
    application: TargetApplication,
    attemptsRemaining: Int
  ) {
    refreshPermission()
    guard isAccessibilityTrusted else { return }

    let targetIsReady =
      dependencies.frontmostProcessIdentifier() == application.processIdentifier
    if targetIsReady {
      dependencies.postPasteShortcut(application.processIdentifier)
      return
    }

    guard attemptsRemaining > 0 else { return }
    dependencies.scheduleRetry { [weak self] in
      self?.pasteWhenTargetIsReady(
        application: application,
        attemptsRemaining: attemptsRemaining - 1
      )
    }
  }

  private static func postPasteShortcut(to _: pid_t) {
    guard let source = CGEventSource(stateID: .hidSystemState),
      let keyDown = CGEvent(
        keyboardEventSource: source,
        virtualKey: CGKeyCode(kVK_ANSI_V),
        keyDown: true
      ),
      let keyUp = CGEvent(
        keyboardEventSource: source,
        virtualKey: CGKeyCode(kVK_ANSI_V),
        keyDown: false
      )
    else {
      return
    }

    keyDown.flags = .maskCommand
    keyUp.flags = .maskCommand
    keyDown.post(tap: .cghidEventTap)
    keyUp.post(tap: .cghidEventTap)
  }
}

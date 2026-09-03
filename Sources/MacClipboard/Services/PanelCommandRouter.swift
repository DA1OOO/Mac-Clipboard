import Combine
import Foundation

enum PanelCommand: Equatable {
  case previous
  case next
  case previousTab
  case nextTab
  case selectCandidate(Int)
  case submit
  case dismiss
  case panelWillOpen
  case panelWillClose
}

@MainActor
final class PanelCommandRouter {
  let commands = PassthroughSubject<PanelCommand, Never>()

  func send(_ command: PanelCommand) {
    commands.send(command)
  }
}

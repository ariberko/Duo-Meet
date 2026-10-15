import Foundation
import Observation

/// What the capture bar can add.
enum CaptureKind: String, CaseIterable, Identifiable {
    case note
    case decision
    case task

    var id: String { rawValue }

    var title: String {
        switch self {
        case .note: "Note"
        case .decision: "Decision"
        case .task: "Task"
        }
    }

    var systemImage: String {
        switch self {
        case .note: "text.alignleft"
        case .decision: "checkmark.seal"
        case .task: "checklist"
        }
    }

    var placeholder: String {
        switch self {
        case .note: "Write a note…"
        case .decision: "What was decided?"
        case .task: "Add a task…"
        }
    }
}

enum LiveTab: Hashable {
    case notes
    case tasks
}

/// In-progress text for one live meeting.
@Observable
final class LiveDraft {
    var noteText = ""
    var noteKind: CaptureKind = .note
    var taskTitle = ""
    var taskOwner = ""
    var taskDueDate: Date?
    var compactTab: LiveTab = .notes
    var isAgendaExpanded = true
    var agendaText = ""

    var hasUnsentText: Bool {
        !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func clearTask() {
        taskTitle = ""
        taskOwner = ""
        taskDueDate = nil
    }
}

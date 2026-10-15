import SwiftUI

/// Right pane: outstanding and completed tasks, plus one-step task entry.
struct ActionItemsPane: View {
    @Environment(MeetingLibrary.self) private var library
    let meeting: Meeting
    @Bindable var draft: LiveDraft
    let showsHeader: Bool
    let onSubmit: (CaptureKind) -> Void

    @State private var editing: ActionItem?

    var body: some View {
        let open = meeting.outstandingActionItems
        let done = meeting.completedActionItems

        VStack(spacing: 0) {
            if showsHeader {
                PaneHeader(title: "Action Items", systemImage: "checklist",
                           trailing: open.isEmpty ? nil : "\(open.count) open")
            }
            List {
                Section("Outstanding") {
                    if open.isEmpty {
                        Text(done.isEmpty
                             ? "No tasks yet. Add one below. Owner and due date are optional."
                             : "Everything here is done.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(open) { row($0) }
                }
                if !done.isEmpty {
                    Section("Completed") {
                        ForEach(done) { row($0) }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CaptureBar(draft: draft, kinds: [.task], kind: .constant(.task),
                       ownerSuggestions: meeting.ownerSuggestions, onSubmit: onSubmit)
        }
        .sensoryFeedback(trigger: meeting.actionItems.count) { oldCount, newCount in
            newCount > oldCount ? .success : nil
        }
        .sheet(item: $editing) { item in
            ActionItemEditor(item: item, ownerSuggestions: meeting.ownerSuggestions) { updated in
                withAnimation { library.update(meeting.id) { $0.updateActionItem(updated) } }
            } onDelete: {
                withAnimation { library.update(meeting.id) { $0.deleteActionItem(item.id) } }
            }
        }
    }

    private func row(_ item: ActionItem) -> some View {
        ActionItemRow(item: item) {
            withAnimation(.snappy) { library.update(meeting.id) { $0.toggleActionItem(item.id) } }
        } onEdit: {
            editing = item
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                withAnimation { library.update(meeting.id) { $0.deleteActionItem(item.id) } }
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                editing = item
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                withAnimation(.snappy) { library.update(meeting.id) { $0.toggleActionItem(item.id) } }
            } label: {
                Label(item.isCompleted ? "Reopen" : "Done",
                      systemImage: item.isCompleted ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(.green)
        }
    }
}

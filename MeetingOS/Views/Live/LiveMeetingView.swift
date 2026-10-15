import SwiftUI
import UIKit
import MeetingCore

/// The live workspace. Shows notes and tasks side by side when there is room
/// (wide or unfolded displays, landscape, iPad) and a Notes / Tasks switch otherwise.
struct LiveMeetingView: View {
    @Environment(MeetingLibrary.self) private var library
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let meetingID: UUID
    let onEnd: () -> Void

    @State private var confirmEnd = false
    @State private var toast: String?

    /// Two panes need about 600 pt so each column fits a comfortable line of text.
    /// Accessibility text sizes need more room before splitting.
    static func usesTwoPanes(width: CGFloat, dynamicTypeSize: DynamicTypeSize) -> Bool {
        width >= (dynamicTypeSize.isAccessibilitySize ? 900 : 600)
    }

    var body: some View {
        if let meeting = library.meeting(meetingID) {
            switch meeting.status {
            case .live:
                workspace(meeting, draft: library.draft(for: meetingID))
            case .planned:
                ContentUnavailableView {
                    Label("Not started yet", systemImage: "clock")
                } description: {
                    Text("Start the meeting to begin the timer.")
                } actions: {
                    Button("Start Now") { library.start(meetingID) }
                        .buttonStyle(.borderedProminent)
                }
            case .ended:
                ContentUnavailableView {
                    Label("This meeting has ended", systemImage: "flag.checkered")
                } actions: {
                    Button("View Summary", action: onEnd)
                        .buttonStyle(.borderedProminent)
                }
            }
        } else {
            ContentUnavailableView("Meeting not found", systemImage: "questionmark.folder",
                                   description: Text("It may have been deleted."))
        }
    }

    private func workspace(_ meeting: Meeting, draft: LiveDraft) -> some View {
        GeometryReader { geo in
            if Self.usesTwoPanes(width: geo.size.width, dynamicTypeSize: dynamicTypeSize) {
                HStack(spacing: 0) {
                    AgendaNotesPane(meeting: meeting, draft: draft,
                                    captureKinds: [.note, .decision], showsHeader: true) { kind in
                        submit(kind, draft: draft)
                    }
                    .frame(width: geo.size.width * 0.56)

                    Divider().ignoresSafeArea(edges: .bottom)

                    ActionItemsPane(meeting: meeting, draft: draft, showsHeader: true) { kind in
                        submit(kind, draft: draft)
                    }
                }
            } else {
                VStack(spacing: 0) {
                    Picker("Show", selection: Binding(get: { draft.compactTab }, set: { draft.compactTab = $0 })) {
                        Text("Notes").tag(LiveTab.notes)
                        Text(meeting.outstandingActionItems.isEmpty
                             ? "Tasks"
                             : "Tasks (\(meeting.outstandingActionItems.count))").tag(LiveTab.tasks)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    switch draft.compactTab {
                    case .notes:
                        AgendaNotesPane(meeting: meeting, draft: draft,
                                        captureKinds: [.note, .decision, .task], showsHeader: false) { kind in
                            submit(kind, draft: draft)
                            if kind == .task { toast = "Task added" }
                        }
                    case .tasks:
                        ActionItemsPane(meeting: meeting, draft: draft, showsHeader: false) { kind in
                            submit(kind, draft: draft)
                        }
                    }
                }
            }
        }
        .navigationTitle(meeting.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                TimerBadge(start: meeting.startTime)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("End") { confirmEnd = true }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .accessibilityLabel("End meeting")
            }
        }
        .confirmationDialog("End this meeting?", isPresented: $confirmEnd, titleVisibility: .visible) {
            if draft.hasUnsentText {
                Button("Add Unsent Text and End") {
                    commitUnsentText(draft)
                    endMeeting()
                }
                Button("Discard Unsent Text and End", role: .destructive) { endMeeting() }
            } else {
                Button("End Meeting", role: .destructive) { endMeeting() }
            }
        } message: {
            Text(draft.hasUnsentText
                 ? "You typed something that hasn't been added yet."
                 : "The timer stops and the meeting is saved.")
        }
        .toast($toast)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private func submit(_ kind: CaptureKind, draft: LiveDraft) {
        switch kind {
        case .note, .decision:
            let text = draft.noteText
            withAnimation(.snappy) {
                library.update(meetingID) { $0.addNote(text, category: kind == .decision ? .decision : .note) }
            }
            draft.noteText = ""
        case .task:
            let title = draft.taskTitle
            let owner = draft.taskOwner
            let due = draft.taskDueDate
            withAnimation(.snappy) {
                library.update(meetingID) { $0.addActionItem(title, owner: owner, dueDate: due) }
            }
            draft.clearTask()
        }
    }

    private func commitUnsentText(_ draft: LiveDraft) {
        let noteText = draft.noteText
        let category: NoteCategory = draft.noteKind == .decision ? .decision : .note
        let title = draft.taskTitle
        let owner = draft.taskOwner
        let due = draft.taskDueDate
        library.update(meetingID) {
            $0.addNote(noteText, category: category)
            $0.addActionItem(title, owner: owner, dueDate: due)
        }
    }

    private func endMeeting() {
        library.end(meetingID)
        onEnd()
    }
}

#Preview("Live") {
    let library = MeetingLibrary.preview
    return NavigationStack {
        LiveMeetingView(meetingID: library.liveMeetings[0].id) {}
    }
    .environment(library)
}

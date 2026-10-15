import SwiftUI
import UIKit
import MeetingCore

/// After-meeting summary. Everything is editable in place. On wide displays the
/// plain text that will be shared is shown next to the editable sections.
struct MeetingSummaryView: View {
    @Environment(MeetingLibrary.self) private var library
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dismiss) private var dismiss

    let meetingID: UUID
    /// True right after "End". Shows a Done button that returns home.
    let justEnded: Bool
    let onDone: () -> Void

    @State private var editingTask: ActionItem?
    @State private var newDecision = ""
    @State private var showTextEditor = false
    @State private var confirmDelete = false
    @State private var toast: String?

    private let formatter = MeetingSummaryFormatter()

    var body: some View {
        if let meeting = library.meeting(meetingID) {
            content(meeting)
        } else {
            ContentUnavailableView("Meeting not found", systemImage: "questionmark.folder",
                                   description: Text("It may have been deleted."))
        }
    }

    private func content(_ meeting: Meeting) -> some View {
        let summaryText = formatter.text(for: meeting)
        return GeometryReader { geo in
            if LiveMeetingView.usesTwoPanes(width: geo.size.width, dynamicTypeSize: dynamicTypeSize) {
                HStack(spacing: 0) {
                    sections(meeting)
                        .frame(width: geo.size.width * 0.56)
                    Divider().ignoresSafeArea(edges: .bottom)
                    VStack(spacing: 0) {
                        PaneHeader(title: "Shared as", systemImage: "doc.plaintext")
                        ScrollView {
                            Text(summaryText)
                                .font(.callout.monospaced())
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                        .background(Color(.secondarySystemBackground))
                    }
                }
            } else {
                sections(meeting)
            }
        }
        .navigationTitle("Summary")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(justEnded)
        .toolbar {
            if justEnded {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit Summary Text", systemImage: "pencil") { showTextEditor = true }
                    Button("Delete Meeting", systemImage: "trash", role: .destructive) { confirmDelete = true }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button {
                    UIPasteboard.general.string = summaryText
                    toast = "Summary copied"
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.bordered)

                ShareLink(item: summaryText, subject: Text(meeting.displayTitle)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
            .padding()
            .background(.bar)
        }
        .toast($toast)
        .sheet(item: $editingTask) { item in
            ActionItemEditor(item: item, ownerSuggestions: meeting.ownerSuggestions) { updated in
                library.update(meetingID) { $0.updateActionItem(updated) }
            } onDelete: {
                library.update(meetingID) { $0.deleteActionItem(item.id) }
            }
        }
        .sheet(isPresented: $showTextEditor) {
            SummaryTextEditor(
                initialText: summaryText,
                generatedText: formatter.plainText(for: meeting)
            ) { newText in
                library.update(meetingID) { $0.customSummary = newText }
            }
        }
        .confirmationDialog("Delete this meeting?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Meeting", role: .destructive) {
                library.delete(meetingID)
                if justEnded { onDone() } else { dismiss() }
            }
        } message: {
            Text("Its notes and action items will be removed from this device.")
        }
    }

    // MARK: Sections

    private func sections(_ meeting: Meeting) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    if justEnded {
                        Label("Meeting saved", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.green)
                    }
                    TextField(Meeting.untitledTitle, text: library.binding(meetingID, \.title, default: ""))
                        .font(.title2.weight(.semibold))
                        .submitLabel(.done)
                        .accessibilityLabel("Meeting title")
                    Label(meeting.startTime.formatted(date: .complete, time: .shortened), systemImage: "calendar")
                    Label(MeetingTimeFormat.duration(meeting.duration()), systemImage: "clock")
                    if !meeting.participants.isEmpty {
                        Label(meeting.participants.joined(separator: ", "), systemImage: "person.2")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
            }

            if meeting.customSummary != nil {
                Section {
                    Label("Sharing your edited text. Changes below won't appear in it.", systemImage: "pencil.line")
                        .font(.footnote)
                    Button("Use generated summary again") {
                        library.update(meetingID) { $0.customSummary = nil }
                    }
                }
            }

            Section("Decisions") {
                // Keeps empty rows so a decision does not vanish while its text is being cleared.
                ForEach(meeting.notes.filter(\.isDecision)) { note in
                    NoteRow(note: note, text: library.noteTextBinding(meeting: meetingID, note: note.id))
                        .swipeActions {
                            Button(role: .destructive) {
                                library.update(meetingID) { $0.deleteNote(note.id) }
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                }
                HStack(spacing: 10) {
                    Image(systemName: "plus")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                        .accessibilityHidden(true)
                    TextField("Add a decision", text: $newDecision)
                        .submitLabel(.done)
                        .onSubmit {
                            let text = newDecision
                            library.update(meetingID) { $0.addNote(text, category: .decision) }
                            newDecision = ""
                        }
                }
            }

            Section("Outstanding action items") {
                let open = meeting.outstandingActionItems
                if open.isEmpty {
                    Text("Nothing outstanding.")
                        .foregroundStyle(.secondary)
                }
                ForEach(open) { taskRow($0) }
            }

            if !meeting.completedActionItems.isEmpty {
                Section("Completed") {
                    ForEach(meeting.completedActionItems) { taskRow($0) }
                }
            }

            let notes = meeting.notes.filter { !$0.isDecision }
            if !notes.isEmpty {
                Section("Notes") {
                    ForEach(notes) { note in
                        NoteRow(note: note, text: library.noteTextBinding(meeting: meetingID, note: note.id))
                            .swipeActions {
                                Button(role: .destructive) {
                                    library.update(meetingID) { $0.deleteNote(note.id) }
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                }
            }

            if !meeting.agenda.isEmpty {
                Section("Agenda") {
                    ForEach(meeting.agenda) { item in
                        Label(item.title, systemImage: item.isCovered ? "checkmark.square.fill" : "square")
                            .foregroundStyle(item.isCovered ? Color.primary : Color.secondary)
                            .accessibilityLabel("\(item.title), \(item.isCovered ? "covered" : "not covered")")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.interactively)
    }

    private func taskRow(_ item: ActionItem) -> some View {
        ActionItemRow(item: item) {
            withAnimation(.snappy) { library.update(meetingID) { $0.toggleActionItem(item.id) } }
        } onEdit: {
            editingTask = item
        }
        .swipeActions {
            Button(role: .destructive) {
                library.update(meetingID) { $0.deleteActionItem(item.id) }
            } label: { Label("Delete", systemImage: "trash") }
        }
    }
}

/// Lets the user rewrite the shared text by hand.
private struct SummaryTextEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    let generatedText: String
    let onSave: (String?) -> Void

    init(initialText: String, generatedText: String, onSave: @escaping (String?) -> Void) {
        _text = State(initialValue: initialText)
        self.generatedText = generatedText
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .font(.body.monospaced())
                .padding(.horizontal)
                .navigationTitle("Summary Text")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                            // Saving the untouched generated text keeps the summary live.
                            onSave(trimmed.isEmpty || trimmed == generatedText ? nil : text)
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .bottomBar) {
                        Button("Reset to Generated") { text = generatedText }
                            .disabled(text == generatedText)
                    }
                }
        }
    }
}

#Preview {
    let library = MeetingLibrary.preview
    return NavigationStack {
        MeetingSummaryView(meetingID: library.pastMeetings[0].id, justEnded: true) {}
    }
    .environment(library)
}

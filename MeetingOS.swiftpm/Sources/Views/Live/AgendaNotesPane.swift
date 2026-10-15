import SwiftUI

/// Left pane: title, participants, agenda and the running list of notes and decisions.
struct AgendaNotesPane: View {
    @Environment(MeetingLibrary.self) private var library
    let meeting: Meeting
    @Bindable var draft: LiveDraft
    let captureKinds: [CaptureKind]
    let showsHeader: Bool
    let onSubmit: (CaptureKind) -> Void

    @State private var showAddParticipant = false
    @State private var newParticipants = ""

    var body: some View {
        VStack(spacing: 0) {
            if showsHeader {
                PaneHeader(title: "Agenda & Notes", systemImage: "note.text",
                           trailing: meeting.decisions.isEmpty ? nil : "\(meeting.decisions.count) decided")
            }
            ScrollViewReader { proxy in
                List {
                    headerSection
                    agendaSection
                    notesSection
                }
                .listStyle(.insetGrouped)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: meeting.notes.count) { oldCount, newCount in
                    guard newCount > oldCount, let last = meeting.notes.last else { return }
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CaptureBar(draft: draft, kinds: captureKinds, kind: $draft.noteKind,
                       ownerSuggestions: meeting.ownerSuggestions, onSubmit: onSubmit)
        }
        .alert("Add participants", isPresented: $showAddParticipant) {
            TextField("Names, separated by commas", text: $newParticipants)
                .textContentType(.name)
            Button("Cancel", role: .cancel) {}
            Button("Add") {
                let names = newParticipants
                library.update(meeting.id) { $0.addParticipants(from: names) }
            }
        }
    }

    // MARK: Sections

    private var headerSection: some View {
        Section {
            TextField(Meeting.untitledTitle, text: library.binding(meeting.id, \.title, default: ""))
                .submitLabel(.done)
                .font(.title2.weight(.semibold))
                .accessibilityLabel("Meeting title")

            Button {
                newParticipants = ""
                showAddParticipant = true
            } label: {
                Label {
                    Text(meeting.participants.isEmpty ? "Add participants" : meeting.participants.joined(separator: ", "))
                        .foregroundStyle(meeting.participants.isEmpty ? Color.accentColor : Color.secondary)
                        .multilineTextAlignment(.leading)
                } icon: {
                    Image(systemName: "person.2")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
            .buttonStyle(.borderless)
            .accessibilityHint("Add people to this meeting")
        }
    }

    private var agendaSection: some View {
        Section {
            if draft.isAgendaExpanded {
                ForEach(meeting.agenda) { item in
                    HStack(spacing: 10) {
                        Button {
                            withAnimation(.snappy) { library.update(meeting.id) { $0.toggleAgendaItem(item.id) } }
                        } label: {
                            Image(systemName: item.isCovered ? "checkmark.square.fill" : "square")
                                .font(.title3)
                                .foregroundStyle(item.isCovered ? Color.secondary : Color.accentColor)
                                .frame(minWidth: 32, minHeight: 32)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(item.isCovered ? "Mark \(item.title) as not covered" : "Mark \(item.title) as covered")

                        TextField("Agenda item", text: library.agendaTitleBinding(meeting: meeting.id, item: item.id), axis: .vertical)
                            .foregroundStyle(item.isCovered ? Color.secondary : Color.primary)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            library.update(meeting.id) { $0.deleteAgendaItem(item.id) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }

                HStack(spacing: 10) {
                    Image(systemName: "plus")
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 32)
                        .accessibilityHidden(true)
                    TextField("Add agenda item", text: $draft.agendaText)
                        .submitLabel(.done)
                        .onSubmit(addAgendaItem)
                }
            }
        } header: {
            Button {
                withAnimation(.snappy) { draft.isAgendaExpanded.toggle() }
            } label: {
                HStack {
                    Text("Agenda")
                    if !meeting.agenda.isEmpty {
                        Text("\(meeting.agenda.filter(\.isCovered).count)/\(meeting.agenda.count)")
                            .monospacedDigit()
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(draft.isAgendaExpanded ? 0 : -90))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(draft.isAgendaExpanded ? "Collapse agenda" : "Expand agenda")
        }
    }

    private var notesSection: some View {
        Section {
            if meeting.notes.isEmpty {
                Text("No notes yet. Type below to capture the first one. Choose Decision to record what was agreed.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(meeting.notes) { note in
                NoteRow(note: note, text: library.noteTextBinding(meeting: meeting.id, note: note.id))
                    .id(note.id)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            library.update(meeting.id) { $0.deleteNote(note.id) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            toggleCategory(note)
                        } label: {
                            Label(note.isDecision ? "Note" : "Decision",
                                  systemImage: note.isDecision ? "text.alignleft" : "checkmark.seal")
                        }
                        .tint(.accentColor)
                    }
                    .contextMenu {
                        Button(note.isDecision ? "Mark as Note" : "Mark as Decision",
                               systemImage: note.isDecision ? "text.alignleft" : "checkmark.seal") {
                            toggleCategory(note)
                        }
                        Button("Turn into Task", systemImage: "checklist") {
                            withAnimation { library.update(meeting.id) { $0.convertNoteToActionItem(note.id) } }
                        }
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            library.update(meeting.id) { $0.deleteNote(note.id) }
                        }
                    }
            }
        } header: {
            Text("Notes & decisions")
        }
    }

    // MARK: Actions

    private func addAgendaItem() {
        let text = draft.agendaText
        library.update(meeting.id) { $0.addAgendaItem(text) }
        draft.agendaText = ""
    }

    private func toggleCategory(_ note: Note) {
        withAnimation(.snappy) {
            library.update(meeting.id) { $0.setCategory(note.isDecision ? .note : .decision, for: note.id) }
        }
    }
}

struct NoteRow: View {
    let note: Note
    let text: Binding<String>

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: note.isDecision ? "checkmark.seal.fill" : "circle.fill")
                .font(note.isDecision ? .body : .system(size: 6))
                .foregroundStyle(note.isDecision ? Color.accentColor : Color.secondary)
                .frame(width: 20)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                if note.isDecision {
                    Text("Decision")
                        .font(.caption2.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(Color.accentColor)
                }
                TextField(note.isDecision ? "Decision" : "Note", text: text, axis: .vertical)
                Text(note.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(note.isDecision ? "Decision" : "Note")
    }
}

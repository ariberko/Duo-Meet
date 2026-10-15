import SwiftUI
import MeetingCore

/// Sets up a new meeting, or edits a planned one. Every field is optional.
struct MeetingSetupView: View {
    @Environment(MeetingLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss

    /// A planned meeting to edit, or `nil` for a new one.
    let existing: Meeting?
    /// Called with the meeting id when the meeting starts now.
    let onStart: (UUID) -> Void

    @State private var title: String
    @State private var participants: [String]
    @State private var agenda: [AgendaItem]
    @State private var scheduleLater: Bool
    @State private var scheduledDate: Date
    @State private var newParticipants = ""
    @State private var newAgendaItem = ""
    @State private var confirmDelete = false
    @FocusState private var focus: Field?

    private enum Field { case title, agenda, participants }

    init(existing: Meeting?, onStart: @escaping (UUID) -> Void) {
        self.existing = existing
        self.onStart = onStart
        _title = State(initialValue: existing?.title ?? "")
        _participants = State(initialValue: existing?.participants ?? [])
        _agenda = State(initialValue: existing?.agenda ?? [])
        _scheduleLater = State(initialValue: existing != nil)
        _scheduledDate = State(initialValue: existing?.startTime
                               ?? Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Meeting title", text: $title)
                        .font(.title3)
                        .focused($focus, equals: .title)
                        .submitLabel(.next)
                        .onSubmit { focus = .agenda }
                } footer: {
                    Text("Optional. You can change it during the meeting.")
                }

                Section("Agenda") {
                    ForEach($agenda) { $item in
                        TextField("Agenda item", text: $item.title)
                    }
                    .onDelete { agenda.remove(atOffsets: $0) }
                    HStack {
                        TextField("Add agenda item", text: $newAgendaItem)
                            .focused($focus, equals: .agenda)
                            .submitLabel(.next)
                            .onSubmit(addAgendaItem)
                        Button("Add", systemImage: "plus.circle.fill", action: addAgendaItem)
                            .labelStyle(.iconOnly)
                            .font(.title3)
                            .disabled(newAgendaItem.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section {
                    ForEach(participants, id: \.self) { name in
                        Label(name, systemImage: "person")
                    }
                    .onDelete { participants.remove(atOffsets: $0) }
                    HStack {
                        TextField("Add people", text: $newParticipants)
                            .textContentType(.name)
                            .focused($focus, equals: .participants)
                            .submitLabel(.done)
                            .onSubmit(addParticipants)
                        Button("Add", systemImage: "plus.circle.fill", action: addParticipants)
                            .labelStyle(.iconOnly)
                            .font(.title3)
                            .disabled(newParticipants.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("Participants")
                } footer: {
                    Text("Separate several names with commas. Names you add here are suggested as task owners.")
                }

                Section {
                    if existing == nil {
                        Toggle("Schedule for later", isOn: $scheduleLater.animation())
                    }
                    if scheduleLater {
                        DatePicker("Starts", selection: $scheduledDate)
                    }
                }

                if existing != nil {
                    Section {
                        Button("Delete Meeting", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(existing == nil ? "New Meeting" : "Upcoming Meeting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if existing != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { save(startNow: false) }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    save(startNow: existing != nil || !scheduleLater)
                } label: {
                    Label(primaryTitle, systemImage: primaryIcon)
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
                .background(.bar)
            }
            .confirmationDialog("Delete this meeting?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete Meeting", role: .destructive) {
                    if let existing { library.delete(existing.id) }
                    dismiss()
                }
            }
        }
    }

    private var primaryTitle: String {
        if existing != nil { return "Start Now" }
        return scheduleLater ? "Save to Upcoming" : "Start Meeting"
    }

    private var primaryIcon: String {
        (existing == nil && scheduleLater) ? "calendar.badge.plus" : "play.fill"
    }

    // MARK: Actions

    private func addAgendaItem() {
        let text = newAgendaItem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        agenda.append(AgendaItem(title: text))
        newAgendaItem = ""
        focus = .agenda
    }

    private func addParticipants() {
        var scratch = Meeting(participants: participants)
        scratch.addParticipants(from: newParticipants)
        participants = scratch.participants
        newParticipants = ""
        focus = .participants
    }

    private func save(startNow: Bool) {
        // Keep text the user typed but didn't press Add for.
        addAgendaItem()
        addParticipants()

        if let existing {
            library.update(existing.id) { meeting in
                meeting.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                meeting.participants = participants
                meeting.agenda = agenda.filter { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
                if !startNow { meeting.startTime = scheduledDate }
            }
            if startNow {
                library.start(existing.id)
                onStart(existing.id)
            } else {
                library.saveNow()
            }
        } else {
            let meeting = library.createMeeting(
                title: title,
                participants: participants,
                agenda: agenda,
                scheduledFor: scheduleLater ? scheduledDate : nil
            )
            if !scheduleLater { onStart(meeting.id) }
        }
        dismiss()
    }
}

#Preview {
    MeetingSetupView(existing: nil) { _ in }
        .environment(MeetingLibrary.preview)
}

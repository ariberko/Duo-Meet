import Foundation

/// All changes to a meeting go through these methods so the rules
/// (trimming, timestamps, lifecycle) live in one testable place.
extension Meeting {

    // MARK: Lifecycle

    /// Moves a planned meeting to live and stamps the real start time.
    public mutating func start(at date: Date = Date()) {
        guard status == .planned else { return }
        startTime = date
        endTime = nil
        status = .live
        touch(date)
    }

    /// Stops the timer. Has no effect unless the meeting is live.
    public mutating func end(at date: Date = Date()) {
        guard status == .live else { return }
        endTime = max(date, startTime)
        status = .ended
        touch(date)
    }

    public mutating func touch(_ date: Date = Date()) {
        updatedAt = date
    }

    // MARK: Participants

    public mutating func addParticipants(from text: String) {
        let names = text
            .split(whereSeparator: { $0 == "," || $0 == "\n" })
            .map { String($0).trimmed }
            .filter { !$0.isEmpty }
        for name in names where !participants.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            participants.append(name)
        }
        touch()
    }

    public mutating func removeParticipant(_ name: String) {
        participants.removeAll { $0 == name }
        touch()
    }

    // MARK: Agenda

    @discardableResult
    public mutating func addAgendaItem(_ title: String) -> AgendaItem? {
        guard let title = title.nonEmptyTrimmed else { return nil }
        let item = AgendaItem(title: title)
        agenda.append(item)
        touch()
        return item
    }

    public mutating func setAgendaTitle(_ title: String, for id: UUID) {
        guard let index = agenda.firstIndex(where: { $0.id == id }) else { return }
        agenda[index].title = title
        touch()
    }

    public mutating func toggleAgendaItem(_ id: UUID) {
        guard let index = agenda.firstIndex(where: { $0.id == id }) else { return }
        agenda[index].isCovered.toggle()
        touch()
    }

    public mutating func deleteAgendaItem(_ id: UUID) {
        agenda.removeAll { $0.id == id }
        touch()
    }

    // MARK: Notes and decisions

    @discardableResult
    public mutating func addNote(_ text: String, category: NoteCategory = .note, at date: Date = Date()) -> Note? {
        guard let text = text.nonEmptyTrimmed else { return nil }
        let note = Note(text: text, createdAt: date, category: category)
        notes.append(note)
        touch(date)
        return note
    }

    public mutating func setNoteText(_ text: String, for id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].text = text
        touch()
    }

    public mutating func setCategory(_ category: NoteCategory, for id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].category = category
        touch()
    }

    public mutating func deleteNote(_ id: UUID) {
        notes.removeAll { $0.id == id }
        touch()
    }

    /// Turns a note into a task with the same text and removes the note.
    @discardableResult
    public mutating func convertNoteToActionItem(_ id: UUID, at date: Date = Date()) -> ActionItem? {
        guard let note = notes.first(where: { $0.id == id }),
              let item = addActionItem(note.text, at: date) else { return nil }
        deleteNote(id)
        return item
    }

    // MARK: Action items

    @discardableResult
    public mutating func addActionItem(
        _ title: String,
        owner: String? = nil,
        dueDate: Date? = nil,
        at date: Date = Date()
    ) -> ActionItem? {
        guard let title = title.nonEmptyTrimmed else { return nil }
        let item = ActionItem(
            title: title,
            owner: owner?.nonEmptyTrimmed,
            dueDate: dueDate,
            createdAt: date
        )
        actionItems.append(item)
        touch(date)
        return item
    }

    /// Replaces the stored task with the same id. Empty titles are ignored.
    public mutating func updateActionItem(_ item: ActionItem, at date: Date = Date()) {
        guard let index = actionItems.firstIndex(where: { $0.id == item.id }),
              let title = item.title.nonEmptyTrimmed else { return }
        let previous = actionItems[index]
        var updated = item
        updated.title = title
        updated.owner = item.owner?.nonEmptyTrimmed
        if updated.isCompleted != previous.isCompleted {
            updated.completedAt = updated.isCompleted ? date : nil
        }
        actionItems[index] = updated
        touch(date)
    }

    public mutating func setActionItem(_ id: UUID, completed: Bool, at date: Date = Date()) {
        guard let index = actionItems.firstIndex(where: { $0.id == id }) else { return }
        actionItems[index].isCompleted = completed
        actionItems[index].completedAt = completed ? date : nil
        touch(date)
    }

    public mutating func toggleActionItem(_ id: UUID, at date: Date = Date()) {
        guard let item = actionItems.first(where: { $0.id == id }) else { return }
        setActionItem(id, completed: !item.isCompleted, at: date)
    }

    public mutating func deleteActionItem(_ id: UUID) {
        actionItems.removeAll { $0.id == id }
        touch()
    }
}

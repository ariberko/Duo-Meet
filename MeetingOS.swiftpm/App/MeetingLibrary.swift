import Foundation
import Observation
import SwiftUI

/// The single source of truth for meetings in the UI. Views read from it and
/// send every change through `update(_:_:)`, which also schedules a save.
@MainActor
@Observable
final class MeetingLibrary {
    enum LoadState: Equatable {
        case loading
        case loaded
        /// `canStartFresh` is false when the file is from a newer app version and must be kept.
        case failed(String, canStartFresh: Bool)
    }

    private(set) var meetings: [Meeting] = []
    private(set) var loadState: LoadState = .loading
    private(set) var lastSaveError: String?

    @ObservationIgnored private let store: MeetingPersisting
    @ObservationIgnored private var pendingSave: Task<Void, Never>?
    @ObservationIgnored private var drafts: [UUID: LiveDraft] = [:]

    init(store: MeetingPersisting) {
        self.store = store
    }

    /// File-backed library. Falls back to memory only if the sandbox folder is unavailable.
    static func makeDefault() -> MeetingLibrary {
        if ProcessInfo.processInfo.arguments.contains("-MeetingOSInMemoryStore") {
            return MeetingLibrary(store: InMemoryMeetingStore())
        }
        do {
            return MeetingLibrary(store: try FileMeetingStore.applicationSupport())
        } catch {
            let library = MeetingLibrary(store: InMemoryMeetingStore())
            library.lastSaveError = "Meetings can't be saved on this device right now."
            return library
        }
    }

    // MARK: Loading and saving

    func load() {
        do {
            meetings = try store.loadMeetings()
            loadState = .loaded
        } catch {
            meetings = []
            let isNewerVersion: Bool
            if case .unsupportedVersion? = error as? MeetingStoreError {
                isNewerVersion = true
            } else {
                isNewerVersion = false
            }
            loadState = .failed(error.localizedDescription, canStartFresh: !isNewerVersion)
        }
    }

    /// After a load failure the user can choose to continue with an empty library.
    /// Unreadable files were already moved aside by the store, so nothing is overwritten.
    func startFresh() {
        meetings = []
        loadState = .loaded
    }

    func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        pendingSave?.cancel()
        pendingSave = nil
        // Never write while a load failed, so a newer or unreadable file is not replaced.
        guard loadState == .loaded else { return }
        do {
            try store.saveMeetings(meetings)
            lastSaveError = nil
        } catch {
            lastSaveError = "Couldn't save: \(error.localizedDescription)"
        }
    }

    // MARK: Queries

    func meeting(_ id: UUID) -> Meeting? {
        meetings.first { $0.id == id }
    }

    var liveMeetings: [Meeting] {
        meetings.filter { $0.status == .live }.sorted { $0.startTime > $1.startTime }
    }

    var upcomingMeetings: [Meeting] {
        meetings.filter { $0.status == .planned }.sorted { $0.startTime < $1.startTime }
    }

    var pastMeetings: [Meeting] {
        meetings.filter { $0.status == .ended }.sorted { $0.startTime > $1.startTime }
    }

    var meetingsWithOpenTasks: [Meeting] {
        meetings
            .filter { !$0.outstandingActionItems.isEmpty }
            .sorted { $0.startTime > $1.startTime }
    }

    var outstandingTaskCount: Int {
        meetings.reduce(0) { $0 + $1.outstandingActionItems.count }
    }

    func search(_ query: String) -> [Meeting] {
        meetings.filter { $0.matches(query) }.sorted { $0.startTime > $1.startTime }
    }

    // MARK: Changes

    func update(_ id: UUID, _ change: (inout Meeting) -> Void) {
        guard let index = meetings.firstIndex(where: { $0.id == id }) else { return }
        var meeting = meetings[index]
        change(&meeting)
        guard meeting != meetings[index] else { return }
        meetings[index] = meeting
        scheduleSave()
    }

    /// Creates a meeting. With no `scheduledFor` date it starts right away.
    @discardableResult
    func createMeeting(
        title: String,
        participants: [String],
        agenda: [AgendaItem],
        scheduledFor: Date?
    ) -> Meeting {
        var meeting = Meeting(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            status: .planned,
            startTime: scheduledFor ?? Date(),
            participants: participants,
            agenda: agenda.filter { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
        )
        if scheduledFor == nil {
            meeting.start()
        }
        meetings.append(meeting)
        saveNow()
        return meeting
    }

    @discardableResult
    func quickStart() -> Meeting {
        createMeeting(title: "", participants: [], agenda: [], scheduledFor: nil)
    }

    func start(_ id: UUID) {
        update(id) { $0.start() }
        saveNow()
    }

    func end(_ id: UUID) {
        update(id) { $0.end() }
        drafts[id] = nil
        saveNow()
    }

    func delete(_ id: UUID) {
        meetings.removeAll { $0.id == id }
        drafts[id] = nil
        saveNow()
    }

    // MARK: Drafts

    /// Unsent text for a live meeting. Kept here (not in view state) so it
    /// survives layout changes, pane switches and leaving the screen.
    func draft(for id: UUID) -> LiveDraft {
        if let draft = drafts[id] { return draft }
        let draft = LiveDraft()
        drafts[id] = draft
        return draft
    }

    // MARK: Bindings

    func binding<Value>(_ id: UUID, _ keyPath: WritableKeyPath<Meeting, Value>, default defaultValue: Value) -> Binding<Value> {
        Binding(
            get: { self.meeting(id)?[keyPath: keyPath] ?? defaultValue },
            set: { newValue in self.update(id) { $0[keyPath: keyPath] = newValue } }
        )
    }

    func noteTextBinding(meeting id: UUID, note noteID: UUID) -> Binding<String> {
        Binding(
            get: { self.meeting(id)?.notes.first(where: { $0.id == noteID })?.text ?? "" },
            set: { text in self.update(id) { $0.setNoteText(text, for: noteID) } }
        )
    }

    func agendaTitleBinding(meeting id: UUID, item itemID: UUID) -> Binding<String> {
        Binding(
            get: { self.meeting(id)?.agenda.first(where: { $0.id == itemID })?.title ?? "" },
            set: { text in self.update(id) { $0.setAgendaTitle(text, for: itemID) } }
        )
    }
}

// MARK: - Previews

extension MeetingLibrary {
    static var preview: MeetingLibrary {
        var live = Meeting(title: "Product sync", participants: ["Ana", "Ben", "Chen"])
        live.start(at: Date().addingTimeInterval(-14 * 60))
        live.addAgendaItem("Last week's metrics")
        live.addAgendaItem("Launch checklist")
        live.addNote("Signups up after onboarding change")
        live.addNote("Launch on the 24th", category: .decision)
        live.addActionItem("Update release notes", owner: "Ana", dueDate: Date().addingTimeInterval(86_400))
        live.addActionItem("Check analytics events")

        var past = Meeting(title: "Design review", participants: ["Ana"])
        past.start(at: Date().addingTimeInterval(-86_400))
        past.addNote("Keep the blue accent", category: .decision)
        past.addActionItem("Export icons", owner: "Ben")
        past.end(at: Date().addingTimeInterval(-86_400 + 35 * 60))

        let library = MeetingLibrary(store: InMemoryMeetingStore(meetings: [live, past]))
        library.load()
        return library
    }
}

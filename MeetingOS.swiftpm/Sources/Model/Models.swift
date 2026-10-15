import Foundation

// MARK: - Agenda

public struct AgendaItem: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var isCovered: Bool

    public init(id: UUID = UUID(), title: String, isCovered: Bool = false) {
        self.id = id
        self.title = title
        self.isCovered = isCovered
    }
}

// MARK: - Notes

public enum NoteCategory: String, Codable, CaseIterable, Sendable {
    case note
    case decision
}

public struct Note: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var text: String
    public var createdAt: Date
    public var category: NoteCategory

    public init(id: UUID = UUID(), text: String, createdAt: Date = Date(), category: NoteCategory = .note) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.category = category
    }

    public var isDecision: Bool { category == .decision }
}

// MARK: - Action items

public struct ActionItem: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var owner: String?
    public var dueDate: Date?
    public var isCompleted: Bool
    public var createdAt: Date
    public var completedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        owner: String? = nil,
        dueDate: Date? = nil,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.owner = owner
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.completedAt = completedAt
    }

    /// True when the task is open and its due day is before the day of `now`.
    public func isOverdue(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard !isCompleted, let dueDate else { return false }
        return calendar.startOfDay(for: dueDate) < calendar.startOfDay(for: now)
    }
}

// MARK: - Meeting

public enum MeetingStatus: String, Codable, Sendable {
    /// Saved for later. `startTime` is the scheduled start.
    case planned
    /// In progress. `startTime` is the actual start.
    case live
    /// Finished. `endTime` is set.
    case ended
}

public struct Meeting: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var status: MeetingStatus
    public var startTime: Date
    public var endTime: Date?
    public var participants: [String]
    public var agenda: [AgendaItem]
    public var notes: [Note]
    public var actionItems: [ActionItem]
    /// Summary text the user edited by hand. `nil` means the generated summary is used.
    public var customSummary: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String = "",
        status: MeetingStatus = .planned,
        startTime: Date = Date(),
        endTime: Date? = nil,
        participants: [String] = [],
        agenda: [AgendaItem] = [],
        notes: [Note] = [],
        actionItems: [ActionItem] = [],
        customSummary: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.startTime = startTime
        self.endTime = endTime
        self.participants = participants
        self.agenda = agenda
        self.notes = notes
        self.actionItems = actionItems
        self.customSummary = customSummary
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }
}

// MARK: - Derived values

extension Meeting {
    public static let untitledTitle = "Untitled meeting"

    public var displayTitle: String {
        let trimmed = title.trimmed
        return trimmed.isEmpty ? Self.untitledTitle : trimmed
    }

    public var decisions: [Note] {
        notes.filter { $0.category == .decision && !$0.text.trimmed.isEmpty }
    }

    public var regularNotes: [Note] {
        notes.filter { $0.category == .note && !$0.text.trimmed.isEmpty }
    }

    /// Open tasks, earliest due date first, then in the order they were added.
    public var outstandingActionItems: [ActionItem] {
        actionItems
            .filter { !$0.isCompleted }
            .sorted { lhs, rhs in
                switch (lhs.dueDate, rhs.dueDate) {
                case let (l?, r?) where l != r: return l < r
                case (_?, nil): return true
                case (nil, _?): return false
                default: return lhs.createdAt < rhs.createdAt
                }
            }
    }

    public var completedActionItems: [ActionItem] {
        actionItems
            .filter(\.isCompleted)
            .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
    }

    /// Elapsed time for live meetings, total time for ended ones, zero for planned ones.
    public func duration(at now: Date = Date()) -> TimeInterval {
        switch status {
        case .planned: return 0
        case .live: return max(0, now.timeIntervalSince(startTime))
        case .ended: return max(0, (endTime ?? startTime).timeIntervalSince(startTime))
        }
    }

    /// Case- and diacritic-insensitive search across everything the user typed.
    public func matches(_ query: String) -> Bool {
        let needle = query.trimmed
        guard !needle.isEmpty else { return true }
        let haystack: [String] = [title]
            + participants
            + agenda.map(\.title)
            + notes.map(\.text)
            + actionItems.flatMap { [$0.title, $0.owner ?? ""] }
        return haystack.contains {
            $0.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    /// Owner names to suggest: participants first, then owners typed earlier.
    public var ownerSuggestions: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for name in participants + actionItems.compactMap(\.owner) {
            let key = name.lowercased()
            if !name.trimmed.isEmpty, !seen.contains(key) {
                seen.insert(key)
                result.append(name)
            }
        }
        return result
    }
}

// MARK: - Helpers

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }

    /// `nil` when the string is empty after trimming.
    var nonEmptyTrimmed: String? {
        let value = trimmed
        return value.isEmpty ? nil : value
    }
}

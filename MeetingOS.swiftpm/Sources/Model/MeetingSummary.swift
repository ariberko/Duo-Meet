import Foundation

// MARK: - Time formatting

public enum MeetingTimeFormat {
    /// Timer style: "04:09" or "1:02:03".
    public static func clock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Summary style: "Under 1 min", "42 min", "1 hr", "1 hr 5 min".
    public static func duration(_ interval: TimeInterval) -> String {
        let totalMinutes = max(0, Int(interval)) / 60
        if totalMinutes == 0 { return "Under 1 min" }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 { return "\(minutes) min" }
        return minutes == 0 ? "\(hours) hr" : "\(hours) hr \(minutes) min"
    }
}

// MARK: - Plain-text summary

/// Builds the shareable summary only from what the user entered.
/// Nothing is invented: empty sections say so instead of being filled in.
public struct MeetingSummaryFormatter: Sendable {
    public var locale: Locale
    public var timeZone: TimeZone

    public init(locale: Locale = .current, timeZone: TimeZone = .current) {
        self.locale = locale
        self.timeZone = timeZone
    }

    /// The user's edited text when present, otherwise the generated text.
    public func text(for meeting: Meeting, now: Date = Date()) -> String {
        if let custom = meeting.customSummary?.nonEmptyTrimmed { return custom }
        return plainText(for: meeting, now: now)
    }

    public func plainText(for meeting: Meeting, now: Date = Date()) -> String {
        var lines: [String] = []
        lines.append("Meeting: \(meeting.displayTitle)")
        lines.append("Date: \(dateTime(meeting.startTime))")
        lines.append("Duration: \(MeetingTimeFormat.duration(meeting.duration(at: now)))")
        if !meeting.participants.isEmpty {
            lines.append("Participants: \(meeting.participants.joined(separator: ", "))")
        }

        lines.append("")
        lines.append("Decisions:")
        let decisions = meeting.decisions
        if decisions.isEmpty {
            lines.append("- None recorded")
        } else {
            lines += decisions.map { bullet($0.text) }
        }

        lines.append("")
        lines.append("Action items:")
        let open = meeting.outstandingActionItems
        if open.isEmpty {
            lines.append("- None outstanding")
        } else {
            lines += open.map(actionLine)
        }

        let done = meeting.completedActionItems
        if !done.isEmpty {
            lines.append("")
            lines.append("Completed:")
            lines += done.map(actionLine)
        }

        let notes = meeting.regularNotes
        if !notes.isEmpty {
            lines.append("")
            lines.append("Notes:")
            lines += notes.map { bullet($0.text) }
        }

        return lines.joined(separator: "\n")
    }

    public func dueDate(_ date: Date) -> String {
        let formatter = makeFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    public func dateTime(_ date: Date) -> String {
        let formatter = makeFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func actionLine(_ item: ActionItem) -> String {
        var parts = [item.title.trimmed]
        if let owner = item.owner?.nonEmptyTrimmed { parts.append("Owner: \(owner)") }
        if let due = item.dueDate { parts.append("Due: \(dueDate(due))") }
        return bullet(parts.joined(separator: " | "))
    }

    /// Indents follow-on lines so multi-line notes stay readable.
    private func bullet(_ text: String) -> String {
        "- " + text.trimmed.replacingOccurrences(of: "\n", with: "\n  ")
    }

    private func makeFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        return formatter
    }
}

// MARK: - Future AI seam

/// Anything that can turn a meeting into summary text.
///
/// The MVP ships only `DeterministicSummarizer`. A future AI-backed
/// implementation should call your own server (never embed API keys in the
/// app) and throw `SummarizerError` so the UI can fall back to the
/// deterministic summary.
public protocol MeetingSummarizing: Sendable {
    func summarize(_ meeting: Meeting) async throws -> String
}

public enum SummarizerError: Error, Equatable, Sendable {
    case missingCredentials
    case networkUnavailable
    case invalidResponse
}

public struct DeterministicSummarizer: MeetingSummarizing {
    public var formatter: MeetingSummaryFormatter

    public init(formatter: MeetingSummaryFormatter = MeetingSummaryFormatter()) {
        self.formatter = formatter
    }

    public func summarize(_ meeting: Meeting) async throws -> String {
        formatter.plainText(for: meeting)
    }
}

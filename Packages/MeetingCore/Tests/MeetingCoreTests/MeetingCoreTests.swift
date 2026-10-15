import XCTest
@testable import MeetingCore

final class MeetingLifecycleTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func testStartAndEndSetsDuration() {
        var meeting = Meeting(title: "Weekly sync", startTime: t0.addingTimeInterval(-999))
        meeting.start(at: t0)
        XCTAssertEqual(meeting.status, .live)
        XCTAssertEqual(meeting.startTime, t0)
        XCTAssertEqual(meeting.duration(at: t0.addingTimeInterval(90)), 90)

        meeting.end(at: t0.addingTimeInterval(45 * 60))
        XCTAssertEqual(meeting.status, .ended)
        XCTAssertEqual(meeting.duration(at: t0.addingTimeInterval(99_999)), 45 * 60, "Ended meetings stop the timer")
    }

    func testEndOnlyWorksWhenLive() {
        var meeting = Meeting()
        meeting.end(at: t0)
        XCTAssertEqual(meeting.status, .planned)
        XCTAssertNil(meeting.endTime)
        XCTAssertEqual(meeting.duration(at: t0), 0)
    }

    func testEndedMeetingCannotRestart() {
        var meeting = Meeting()
        meeting.start(at: t0)
        meeting.end(at: t0.addingTimeInterval(60))
        meeting.start(at: t0.addingTimeInterval(120))
        XCTAssertEqual(meeting.status, .ended)
        XCTAssertEqual(meeting.startTime, t0)
    }

    func testEndBeforeStartClampsToZero() {
        var meeting = Meeting()
        meeting.start(at: t0)
        meeting.end(at: t0.addingTimeInterval(-10))
        XCTAssertEqual(meeting.duration(), 0)
    }
}

final class MeetingEditingTests: XCTestCase {
    func testNotesAndDecisions() {
        var meeting = Meeting()
        XCTAssertNil(meeting.addNote("   "), "Blank notes are ignored")
        let note = meeting.addNote("  Budget looks fine ")
        let decision = meeting.addNote("Ship on Friday", category: .decision)
        XCTAssertEqual(note?.text, "Budget looks fine")
        XCTAssertEqual(meeting.regularNotes.map(\.text), ["Budget looks fine"])
        XCTAssertEqual(meeting.decisions.map(\.text), ["Ship on Friday"])

        meeting.setCategory(.decision, for: note!.id)
        XCTAssertEqual(meeting.decisions.count, 2)
        meeting.deleteNote(decision!.id)
        XCTAssertEqual(meeting.decisions.map(\.text), ["Budget looks fine"])
    }

    func testActionItemAddEditCompleteDelete() throws {
        var meeting = Meeting()
        XCTAssertNil(meeting.addActionItem(""))
        let item = try XCTUnwrap(meeting.addActionItem("Send deck", owner: "  "))
        XCTAssertNil(item.owner, "Blank owner becomes nil")
        XCTAssertEqual(meeting.outstandingActionItems.count, 1)

        var edited = item
        edited.title = "Send final deck"
        edited.owner = "Dana"
        meeting.updateActionItem(edited)
        XCTAssertEqual(meeting.actionItems.first?.title, "Send final deck")
        XCTAssertEqual(meeting.actionItems.first?.owner, "Dana")

        meeting.toggleActionItem(item.id)
        XCTAssertTrue(meeting.outstandingActionItems.isEmpty)
        XCTAssertEqual(meeting.completedActionItems.count, 1)
        XCTAssertNotNil(meeting.completedActionItems.first?.completedAt)

        meeting.toggleActionItem(item.id)
        XCTAssertNil(meeting.actionItems.first?.completedAt)

        meeting.deleteActionItem(item.id)
        XCTAssertTrue(meeting.actionItems.isEmpty)
    }

    func testUpdateIgnoresEmptyTitle() throws {
        var meeting = Meeting()
        var item = try XCTUnwrap(meeting.addActionItem("Keep me"))
        item.title = "  "
        meeting.updateActionItem(item)
        XCTAssertEqual(meeting.actionItems.first?.title, "Keep me")
    }

    func testOutstandingSortsByDueDate() {
        var meeting = Meeting()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        meeting.addActionItem("No date", at: base)
        meeting.addActionItem("Later", dueDate: base.addingTimeInterval(86_400 * 3), at: base.addingTimeInterval(1))
        meeting.addActionItem("Sooner", dueDate: base.addingTimeInterval(86_400), at: base.addingTimeInterval(2))
        XCTAssertEqual(meeting.outstandingActionItems.map(\.title), ["Sooner", "Later", "No date"])
    }

    func testConvertNoteToTask() throws {
        var meeting = Meeting()
        let note = try XCTUnwrap(meeting.addNote("Book the room"))
        meeting.convertNoteToActionItem(note.id)
        XCTAssertTrue(meeting.notes.isEmpty)
        XCTAssertEqual(meeting.actionItems.map(\.title), ["Book the room"])
    }

    func testParticipantsSplitAndDedupe() {
        var meeting = Meeting()
        meeting.addParticipants(from: "Ana, Ben,, ana")
        meeting.addParticipants(from: "Cy")
        XCTAssertEqual(meeting.participants, ["Ana", "Ben", "Cy"])
    }

    func testAgenda() throws {
        var meeting = Meeting()
        let item = try XCTUnwrap(meeting.addAgendaItem("Roadmap"))
        meeting.toggleAgendaItem(item.id)
        XCTAssertTrue(meeting.agenda[0].isCovered)
        meeting.deleteAgendaItem(item.id)
        XCTAssertTrue(meeting.agenda.isEmpty)
    }

    func testSearch() {
        var meeting = Meeting(title: "Design review", participants: ["Zoë"])
        meeting.addActionItem("Update mockups", owner: "Lee")
        XCTAssertTrue(meeting.matches("design"))
        XCTAssertTrue(meeting.matches("zoe"))
        XCTAssertTrue(meeting.matches("MOCKUP"))
        XCTAssertTrue(meeting.matches("lee"))
        XCTAssertFalse(meeting.matches("budget"))
        XCTAssertTrue(meeting.matches("  "))
    }

    func testOverdue() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let yesterday = ActionItem(title: "x", dueDate: now.addingTimeInterval(-86_400))
        let today = ActionItem(title: "x", dueDate: now)
        XCTAssertTrue(yesterday.isOverdue(now: now, calendar: calendar))
        XCTAssertFalse(today.isOverdue(now: now, calendar: calendar))
    }
}

final class SummaryTests: XCTestCase {
    private let formatter = MeetingSummaryFormatter(
        locale: Locale(identifier: "en_US_POSIX"),
        timeZone: TimeZone(identifier: "UTC")!
    )

    func testTimeFormats() {
        XCTAssertEqual(MeetingTimeFormat.clock(0), "00:00")
        XCTAssertEqual(MeetingTimeFormat.clock(249), "04:09")
        XCTAssertEqual(MeetingTimeFormat.clock(3723), "1:02:03")
        XCTAssertEqual(MeetingTimeFormat.duration(30), "Under 1 min")
        XCTAssertEqual(MeetingTimeFormat.duration(42 * 60), "42 min")
        XCTAssertEqual(MeetingTimeFormat.duration(3600), "1 hr")
        XCTAssertEqual(MeetingTimeFormat.duration(3900), "1 hr 5 min")
    }

    func testSummaryUsesOnlyUserContent() {
        let start = Date(timeIntervalSince1970: 1_800_000_000) // 2027-01-15 08:00 UTC
        var meeting = Meeting(title: "Launch plan", participants: ["Ana", "Ben"])
        meeting.start(at: start)
        meeting.addNote("Go with option B", category: .decision)
        meeting.addNote("Marketing needs copy\nby Tuesday")
        meeting.addActionItem("Draft email", owner: "Ana", dueDate: start.addingTimeInterval(86_400))
        meeting.addActionItem("Book venue")
        if let done = meeting.addActionItem("Old task") { meeting.setActionItem(done.id, completed: true) }
        meeting.end(at: start.addingTimeInterval(65 * 60))

        let text = formatter.plainText(for: meeting)
        // Locale-specific spacing differs between OS versions, so dates come from the same formatter.
        XCTAssertTrue(formatter.dueDate(start).contains("2027"))
        XCTAssertEqual(text, """
        Meeting: Launch plan
        Date: \(formatter.dateTime(start))
        Duration: 1 hr 5 min
        Participants: Ana, Ben

        Decisions:
        - Go with option B

        Action items:
        - Draft email | Owner: Ana | Due: \(formatter.dueDate(start.addingTimeInterval(86_400)))
        - Book venue

        Completed:
        - Old task

        Notes:
        - Marketing needs copy
          by Tuesday
        """)
    }

    func testEmptySummarySaysNoneInsteadOfInventing() {
        var meeting = Meeting()
        meeting.start(at: Date(timeIntervalSince1970: 0))
        meeting.end(at: Date(timeIntervalSince1970: 10))
        let text = formatter.plainText(for: meeting)
        XCTAssertTrue(text.contains("Meeting: Untitled meeting"))
        XCTAssertTrue(text.contains("- None recorded"))
        XCTAssertTrue(text.contains("- None outstanding"))
        XCTAssertFalse(text.contains("Participants:"))
        XCTAssertFalse(text.contains("Notes:"))
    }

    func testCustomSummaryWins() {
        var meeting = Meeting(title: "A")
        meeting.customSummary = "  My own text "
        XCTAssertEqual(formatter.text(for: meeting), "My own text")
        meeting.customSummary = "   "
        XCTAssertTrue(formatter.text(for: meeting).hasPrefix("Meeting: A"))
    }

    func testDeterministicSummarizer() async throws {
        let meeting = Meeting(title: "B")
        let text = try await DeterministicSummarizer(formatter: formatter).summarize(meeting)
        XCTAssertEqual(text, formatter.plainText(for: meeting))
    }
}

final class PersistenceTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeetingCoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testRoundTripAcrossStoreInstances() throws {
        let url = directory.appendingPathComponent("meetings.json")
        var meeting = Meeting(title: "Persist me", participants: ["Ana"])
        meeting.start()
        meeting.addAgendaItem("Intro")
        meeting.addNote("A decision", category: .decision)
        meeting.addActionItem("Follow up", owner: "Ana", dueDate: Date())
        meeting.end()

        try FileMeetingStore(fileURL: url).saveMeetings([meeting])
        // A fresh instance simulates an app relaunch.
        let loaded = try FileMeetingStore(fileURL: url).loadMeetings()
        XCTAssertEqual(loaded, [meeting])
    }

    func testMissingFileLoadsEmpty() throws {
        let store = FileMeetingStore(fileURL: directory.appendingPathComponent("none.json"))
        XCTAssertEqual(try store.loadMeetings(), [])
    }

    func testCorruptFileIsBackedUpNotLost() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("meetings.json")
        try Data("not json".utf8).write(to: url)

        XCTAssertThrowsError(try FileMeetingStore(fileURL: url).loadMeetings()) { error in
            guard case .unreadableArchive(let backup?)? = error as? MeetingStoreError else {
                return XCTFail("Unexpected error \(error)")
            }
            XCTAssertEqual(try? Data(contentsOf: backup), Data("not json".utf8))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testNewerVersionIsRejected() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("meetings.json")
        try Data(#"{"version":99,"meetings":[]}"#.utf8).write(to: url)
        XCTAssertThrowsError(try FileMeetingStore(fileURL: url).loadMeetings()) { error in
            XCTAssertEqual(error as? MeetingStoreError, .unsupportedVersion(99))
        }
    }
}

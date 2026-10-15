import SwiftUI
import MeetingCore

struct HomeView: View {
    @Environment(MeetingLibrary.self) private var library
    @Binding var path: [Route]

    @State private var query = ""
    @State private var showingSetup = false
    @State private var editingPlanned: Meeting?
    @State private var routeAfterSheet: Route?
    @State private var pendingDelete: Meeting?

    var body: some View {
        List {
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                dashboard
            } else {
                searchResults
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("MeetingOS")
        .searchable(text: $query, prompt: "Search meetings, notes, tasks")
        .safeAreaInset(edge: .bottom) {
            if let error = library.lastSaveError {
                Label(error, systemImage: "exclamationmark.icloud")
                    .font(.footnote)
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(.thinMaterial)
            }
        }
        .sheet(isPresented: $showingSetup, onDismiss: openPendingRoute) {
            MeetingSetupView(existing: nil) { routeAfterSheet = .live($0) }
        }
        .sheet(item: $editingPlanned, onDismiss: openPendingRoute) { meeting in
            MeetingSetupView(existing: meeting) { routeAfterSheet = .live($0) }
        }
        .confirmationDialog("Delete this meeting?", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        ), titleVisibility: .visible, presenting: pendingDelete) { meeting in
            Button("Delete \(meeting.displayTitle)", role: .destructive) {
                withAnimation { library.delete(meeting.id) }
            }
        } message: { _ in
            Text("Its notes and action items will be removed from this device.")
        }
    }

    // MARK: Dashboard

    @ViewBuilder
    private var dashboard: some View {
        Section {
            StartMeetingCard(isFirstRun: library.meetings.isEmpty) {
                showingSetup = true
            } onQuickStart: {
                let meeting = library.quickStart()
                path.append(.live(meeting.id))
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)

        if !library.liveMeetings.isEmpty {
            Section("In progress") {
                ForEach(library.liveMeetings) { meeting in
                    NavigationLink(value: Route.live(meeting.id)) {
                        LiveMeetingRow(meeting: meeting)
                    }
                }
            }
        }

        if library.outstandingTaskCount > 0 {
            Section {
                NavigationLink(value: Route.openTasks) {
                    OpenTasksSummaryRow(
                        taskCount: library.outstandingTaskCount,
                        meetingCount: library.meetingsWithOpenTasks.count
                    )
                }
            }
        }

        if !library.upcomingMeetings.isEmpty {
            Section("Upcoming") {
                ForEach(library.upcomingMeetings) { meeting in
                    Button {
                        editingPlanned = meeting
                    } label: {
                        MeetingRow(meeting: meeting)
                    }
                    .foregroundStyle(.primary)
                    .swipeActions { deleteButton(meeting) }
                }
            }
        }

        Section("Recent") {
            if library.pastMeetings.isEmpty {
                Text(library.meetings.isEmpty
                     ? "Finished meetings appear here with their decisions and action items."
                     : "No finished meetings yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }
            ForEach(library.pastMeetings) { meeting in
                NavigationLink(value: Route.summary(meeting.id, justEnded: false)) {
                    MeetingRow(meeting: meeting)
                }
                .swipeActions { deleteButton(meeting) }
            }
        }
    }

    // MARK: Search

    @ViewBuilder
    private var searchResults: some View {
        let results = library.search(query)
        if results.isEmpty {
            ContentUnavailableView.search(text: query)
                .listRowBackground(Color.clear)
        } else {
            Section("\(results.count) found") {
                ForEach(results) { meeting in
                    switch meeting.status {
                    case .live:
                        NavigationLink(value: Route.live(meeting.id)) { LiveMeetingRow(meeting: meeting) }
                    case .ended:
                        NavigationLink(value: Route.summary(meeting.id, justEnded: false)) { MeetingRow(meeting: meeting) }
                    case .planned:
                        Button { editingPlanned = meeting } label: { MeetingRow(meeting: meeting) }
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }

    // MARK: Helpers

    private func deleteButton(_ meeting: Meeting) -> some View {
        Button(role: .destructive) {
            pendingDelete = meeting
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func openPendingRoute() {
        if let route = routeAfterSheet {
            routeAfterSheet = nil
            path.append(route)
        }
    }
}

// MARK: - Rows and cards

private struct StartMeetingCard: View {
    let isFirstRun: Bool
    let onStart: () -> Void
    let onQuickStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if isFirstRun {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Less organizing. More clarity.")
                        .font(.title3.weight(.semibold))
                    Text("Start a meeting to keep notes, decisions and action items in one place. Everything stays on this device.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Button(action: onStart) {
                Label("Start Meeting", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 34)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button(action: onQuickStart) {
                Label("Quick start, no setup", systemImage: "bolt.fill")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: 28)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(.vertical, 8)
    }
}

private struct LiveMeetingRow: View {
    let meeting: Meeting

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.displayTitle)
                    .font(.headline)
                Text("Tap to return to the meeting")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            TimerBadge(start: meeting.startTime)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Resume meeting")
    }
}

struct MeetingRow: View {
    let meeting: Meeting

    var body: some View {
        let open = meeting.outstandingActionItems.count
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.displayTitle)
                    .font(.headline)
                    .lineLimit(2)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { details }
                    VStack(alignment: .leading, spacing: 2) { details }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if open > 0 {
                Text("\(open)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .foregroundStyle(Color.accentColor)
                    .background(Capsule().fill(Color.accentColor.opacity(0.14)))
                    .accessibilityLabel("\(open) open \(open == 1 ? "task" : "tasks")")
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var details: some View {
        Label(meeting.startTime.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
        if meeting.status == .ended {
            Label(MeetingTimeFormat.duration(meeting.duration()), systemImage: "clock")
        } else if meeting.status == .planned {
            Label("Scheduled", systemImage: "clock.badge")
        }
    }
}

private struct OpenTasksSummaryRow: View {
    let taskCount: Int
    let meetingCount: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checklist")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(taskCount) open action \(taskCount == 1 ? "item" : "items")")
                    .font(.headline)
                Text("Across \(meetingCount) \(meetingCount == 1 ? "meeting" : "meetings")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        HomeView(path: .constant([]))
    }
    .environment(MeetingLibrary.preview)
}

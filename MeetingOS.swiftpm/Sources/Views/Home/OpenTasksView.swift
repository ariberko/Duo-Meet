import SwiftUI

/// Every open action item across all meetings, grouped by meeting.
struct OpenTasksView: View {
    @Environment(MeetingLibrary.self) private var library
    @State private var editing: (meetingID: UUID, item: ActionItem)?

    var body: some View {
        let meetings = library.meetingsWithOpenTasks
        Group {
            if meetings.isEmpty {
                ContentUnavailableView("All caught up", systemImage: "checkmark.circle",
                                       description: Text("Open action items from your meetings show up here."))
            } else {
                List {
                    ForEach(meetings) { meeting in
                        Section {
                            ForEach(meeting.outstandingActionItems) { item in
                                ActionItemRow(item: item) {
                                    withAnimation(.snappy) {
                                        library.update(meeting.id) { $0.toggleActionItem(item.id) }
                                    }
                                } onEdit: {
                                    editing = (meeting.id, item)
                                }
                            }
                        } header: {
                            NavigationLink(value: meeting.status == .live
                                           ? Route.live(meeting.id)
                                           : Route.summary(meeting.id, justEnded: false)) {
                                HStack {
                                    Text(meeting.displayTitle)
                                    Spacer()
                                    Text(meeting.startTime.formatted(date: .abbreviated, time: .omitted))
                                }
                            }
                            .accessibilityHint("Open meeting")
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Open Action Items")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
            if let editing, let meeting = library.meeting(editing.meetingID) {
                ActionItemEditor(item: editing.item, ownerSuggestions: meeting.ownerSuggestions) { updated in
                    library.update(editing.meetingID) { $0.updateActionItem(updated) }
                } onDelete: {
                    library.update(editing.meetingID) { $0.deleteActionItem(editing.item.id) }
                }
            }
        }
    }
}

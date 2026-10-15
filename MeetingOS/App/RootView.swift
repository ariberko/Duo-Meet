import SwiftUI

enum Route: Hashable {
    case live(UUID)
    case summary(UUID, justEnded: Bool)
    case openTasks
}

struct RootView: View {
    @Environment(MeetingLibrary.self) private var library
    @Environment(\.scenePhase) private var scenePhase
    @State private var path: [Route] = []

    var body: some View {
        Group {
            switch library.loadState {
            case .loading:
                ProgressView("Opening your meetings…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message, let canStartFresh):
                LoadFailedView(message: message, canStartFresh: canStartFresh)
            case .loaded:
                NavigationStack(path: $path) {
                    HomeView(path: $path)
                        .navigationDestination(for: Route.self, destination: destination)
                }
            }
        }
        .task {
            if library.loadState == .loading { library.load() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { library.saveNow() }
        }
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .live(let id):
            LiveMeetingView(meetingID: id) {
                path = [.summary(id, justEnded: true)]
            }
        case .summary(let id, let justEnded):
            MeetingSummaryView(meetingID: id, justEnded: justEnded) {
                path.removeAll()
            }
        case .openTasks:
            OpenTasksView()
        }
    }
}

private struct LoadFailedView: View {
    @Environment(MeetingLibrary.self) private var library
    let message: String
    let canStartFresh: Bool

    var body: some View {
        ContentUnavailableView {
            Label("Couldn't open meetings", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") { library.load() }
                .buttonStyle(.borderedProminent)
            if canStartFresh {
                Button("Start with an empty library") { library.startFresh() }
            }
        }
    }
}

#Preview {
    RootView().environment(MeetingLibrary.preview)
}

import SwiftUI

@main
struct MeetingOSApp: App {
    @State private var library = MeetingLibrary.makeDefault()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(library)
        }
    }
}

import SwiftUI

@main
struct GhisaApp: App {
    @State private var app = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView(app: app)
        }
    }
}

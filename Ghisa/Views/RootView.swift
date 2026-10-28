import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @Bindable var app: AppModel

    private static let excel = UTType("org.openxmlformats.spreadsheetml.sheet") ?? .data

    var body: some View {
        ZStack(alignment: .top) {
            Theme.bg.ignoresSafeArea()

            switch app.page {
            case .home: HomeView(app: app)
            case .workout(let workout): WorkoutView(workout: workout)
            case .done(let summary): DoneView(summary: summary, app: app)
            case .timer: TimerView(app: app)
            }

            if let toast = app.toast {
                Text(toast)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Theme.surface3, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.4), radius: 12, y: 8)
                    .padding(.horizontal, 16).padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: app.toast)
        .foregroundStyle(Theme.ink)
        .preferredColorScheme(.dark)
        .fileImporter(isPresented: $app.isImporting, allowedContentTypes: [Self.excel]) { result in
            if case .success(let url) = result { app.importFile(url) }
        }
    }
}

// The whole app with the sample sheet: in the Canvas you can tap a split,
// tick sets and finish the workout, moving between pages as on the iPhone.
#Preview("App") {
    RootView(app: PreviewData.app())
}

#Preview("App senza scheda") {
    RootView(app: PreviewData.emptyApp())
}

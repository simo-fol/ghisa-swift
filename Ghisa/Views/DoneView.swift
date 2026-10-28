import SwiftUI

struct DoneView: View {
    let summary: DoneSummary
    let app: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 14) {
                Text("✓")
                    .font(.system(size: 48, weight: .black))
                    .foregroundStyle(Theme.onAccent)
                    .frame(width: 96, height: 96)
                    .background(Theme.accent, in: Circle())
                Text(summary.title).font(.system(size: 32, weight: .bold))
                Text(summary.slotLabel).font(.system(size: 15)).foregroundStyle(Theme.muted)
                Text(summary.summary).font(.system(size: 17, weight: .semibold))
                Text(summary.saveInfo)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(padding: 14)
            }
            Spacer()
            VStack(spacing: 10) {
                Button("Torna agli split", action: app.showHome).buttonStyle(PrimaryButtonStyle())
                if let url = app.shareURL {
                    ShareLink(item: url) {
                        Text("Condividi Excel")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }
        }
        .padding(24)
    }
}

#Preview("Completato") {
    DoneView(summary: PreviewData.done, app: PreviewData.app())
        .background(Theme.bg)
        .foregroundStyle(Theme.ink)
        .preferredColorScheme(.dark)
}

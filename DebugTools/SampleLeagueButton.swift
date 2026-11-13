#if DEBUG
import SwiftUI

/// TEST TOOL, Debug builds only: the orange "Load Sample League" button on Edit Player
/// Accounts. See SampleLeague and DebugTools/README.md.
struct SampleLeagueButton: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var alert: CSVImportAlert?

    var body: some View {
        VStack(spacing: 4) {
            Button {
                let result = SampleLeague.load(in: viewContext)
                alert = CSVImportAlert(title: result.title, message: result.message)
            } label: {
                Label("Load Sample League", systemImage: "hammer.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            Button {
                let result = TestGameNights.add(in: viewContext)
                alert = CSVImportAlert(title: result.title, message: result.message)
            } label: {
                Label("Add Test Game Nights", systemImage: "calendar.badge.plus")
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .accessibilityIdentifier("addTestGameNights")
            Text("Testing only (Debug builds): Load Sample League adds 18 test players, 41 games, and sample game nights. Add Test Game Nights adds 8 nights in January 2030 that never expire.")
                .font(.caption2)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .alert(item: $alert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
    }
}
#endif

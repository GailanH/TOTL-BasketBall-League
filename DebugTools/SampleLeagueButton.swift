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
            Text("Testing only (Debug builds): adds 18 test players and 41 games.")
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

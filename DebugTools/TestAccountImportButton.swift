#if DEBUG
import SwiftUI
import UniformTypeIdentifiers

/// TEST TOOL, Debug builds only: "Import Test Accounts (CSV)" on Edit Player Accounts.
/// See TestMemberImporter and DebugTools/README.md.
struct TestAccountImportButton: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showImporter = false
    @State private var alert: CSVImportAlert?

    var body: some View {
        VStack(spacing: 4) {
            Button {
                showImporter = true
            } label: {
                Label("Import Test Accounts (CSV)", systemImage: "hammer")
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            Text("Testing only (Debug builds). Columns: username, email, membership, password. Optional: rank_points, joined.")
                .font(.caption2)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            switch result {
            case .failure(let error):
                alert = CSVImportAlert(title: "Import Failed", message: "Couldn't open file: \(error.localizedDescription)")
            case .success(let url):
                let didStart = url.startAccessingSecurityScopedResource()
                defer { if didStart { url.stopAccessingSecurityScopedResource() } }
                guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                    alert = CSVImportAlert(title: "Import Failed", message: "Couldn't read that file as text.")
                    return
                }
                let outcome = TestMemberImporter.importCSV(text, in: viewContext)
                alert = CSVImportAlert(title: outcome.imported.isEmpty ? "Nothing Imported" : "Import Complete",
                                       message: outcome.summary)
            }
        }
        .alert(item: $alert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
    }
}
#endif

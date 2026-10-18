import SwiftUI

struct AddSessionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    /// nil = creating a new session. Non-nil = editing this existing session.
    var sessionToEdit: CoachingSession?

    @State private var title = ""
    @State private var coachName = ""
    @State private var date = Date()
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Session Title", text: $title)
                TextField("Coach Name", text: $coachName)
                DatePicker("Date & Time", selection: $date, displayedComponents: [.date, .hourAndMinute])

                if let errorMessage {
                    Label(errorMessage, systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                }

                Button(sessionToEdit == nil ? "Add Session" : "Save Changes") {
                    save()
                }
                .disabled(title.isEmpty || coachName.isEmpty)
            }
            .scrollContentBackground(.hidden)
            .background(Color("AppBackground").ignoresSafeArea())
            .navigationTitle(sessionToEdit == nil ? "New Coaching Session" : "Edit Session")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                guard let sessionToEdit else { return }
                title = sessionToEdit.title ?? ""
                coachName = sessionToEdit.coachName ?? ""
                date = sessionToEdit.date ?? Date()
            }
        }
    }

    private func save() {
        let session = sessionToEdit ?? CoachingSession(context: viewContext)
        session.title = title
        session.coachName = coachName
        session.date = date
        if sessionToEdit == nil {
            session.isBooked = false
        }

        do {
            try viewContext.save()
            dismiss()
        } catch {
            viewContext.rollback()
            errorMessage = "Couldn't save: \(error.localizedDescription)"
        }
    }
}

import SwiftUI

struct AddSessionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var coachName = ""
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            Form {
                TextField("Session Title", text: $title)
                TextField("Coach Name", text: $coachName)
                DatePicker("Date & Time", selection: $date, displayedComponents: [.date, .hourAndMinute])

                Button("Add Session") {
                    let session = CoachingSession(context: viewContext)
                    session.title = title
                    session.coachName = coachName
                    session.date = date
                    session.isBooked = false
                    try? viewContext.save()
                    dismiss()
                }
                .disabled(title.isEmpty || coachName.isEmpty)
            }
            .navigationTitle("New Coaching Session")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

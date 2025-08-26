import SwiftUI
import CoreData

struct EditPlayerDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @ObservedObject var player: Player

    @State private var selectedMembership: String = ""
    @State private var selectedRole: String = ""
    @State private var allowRoleEdit: Bool = false
    @State private var message = ""

    private let memberships = ["Casual", "Competitive", "Deactivated"]
    private let roles = ["player", "employee"]

    var body: some View {
        Form {
            Section(header: Text("Membership")) {
                Picker("Membership", selection: $selectedMembership) {
                    ForEach(memberships, id: \.self) { level in
                        Text(level)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(header: Text("Role")) {
                Toggle("Edit Role", isOn: $allowRoleEdit)

                if allowRoleEdit {
                    Picker("Role", selection: $selectedRole) {
                        ForEach(roles, id: \.self) { role in
                            Text(role.capitalized)
                        }
                    }
                    .pickerStyle(.segmented)
                } else {
                    Text("Role: \((player.role ?? "player").capitalized)")
                        .foregroundColor(.gray)
                }
            }
            
            Section(header: Text("Profile Image")) {
                if let data = player.profileImage, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 120)
                        .clipShape(Circle())
                        .padding(.bottom)

                    Button("❌ Remove Image") {
                        player.profileImage = nil
                        try? viewContext.save()
                    }
                    .foregroundColor(.red)
                } else {
                    Text("No profile image.")
                        .foregroundColor(.gray)
                }
            }

            Button("Save Changes") {
                saveChanges()
            }
            .buttonStyle(.borderedProminent)

            if !message.isEmpty {
                Text(message)
                    .foregroundColor(.green)
            }
        }
        .onAppear {
            selectedMembership = player.membership ?? "None"
            selectedRole = player.role ?? "player"
        }
        .navigationTitle(player.username ?? "Edit Player")
    }

    private func saveChanges() {
        player.membership = selectedMembership

        if allowRoleEdit {
            player.role = selectedRole
        }

        do {
            try viewContext.save()
            message = "Changes saved!"
        } catch {
            message = "❌ Error saving: \(error.localizedDescription)"
        }
    }
}


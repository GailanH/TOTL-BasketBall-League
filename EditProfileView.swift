import SwiftUI
import CoreData
import PhotosUI

struct EditProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let playerID: NSManagedObjectID

    @State private var username: String = ""
    @State private var email: String = ""
    @State private var membership: String = ""
    @State private var role: String = ""
    @State private var profileImageData: Data? = nil
    @State private var saveMessage: String?

    @State private var showImagePicker = false
    @State private var errorLoadingPlayer = false

    var body: some View {
        Form {
            Section(header: Text("Profile Picture")) {
                if let imageData = profileImageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                        .padding(.bottom, 4)
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.gray)
                        .padding(.bottom, 4)
                }

                Button("Change Profile Picture") {
                    showImagePicker = true
                }
            }

            Section(header: Text("Edit Info")) {
                TextField("Username", text: $username)
                TextField("Email", text: $email)

                if role.lowercased() == "employee" {
                    TextField("Membership", text: $membership)
                }
            }

            if let saveMessage = saveMessage {
                Text(saveMessage)
                    .foregroundColor(.green)
            }

            Button("Save Changes") {
                saveChanges()
            }
            .disabled(username.isEmpty || email.isEmpty)
        }
        .navigationTitle("Edit Profile")
        .onAppear {
            loadPlayerData()
        }
        .onDisappear {
            saveMessage = nil
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(imageData: $profileImageData)
        }
    }

    private func loadPlayerData() {
        do {
            let object = try viewContext.existingObject(with: playerID)
            guard let player = object as? Player else {
                errorLoadingPlayer = true
                return
            }

            self.username = player.username ?? ""
            self.email = player.email ?? ""
            self.membership = player.membership ?? ""
            self.role = player.role ?? ""
            self.profileImageData = player.profileImage

        } catch {
            print("❌ Failed to load Player for editing: \(error)")
            errorLoadingPlayer = true
        }
    }

    private func saveChanges() {
        do {
            let object = try viewContext.existingObject(with: playerID)
            guard let player = object as? Player else { return }

            player.username = username
            player.email = email
            player.profileImage = profileImageData

            if role.lowercased() == "employee" {
                player.membership = membership
            }

            try viewContext.save()
            saveMessage = "✅ Saved successfully"
        } catch {
            print("❌ Failed to save player: \(error)")
            saveMessage = "❌ Failed to save changes"
        }
    }
}

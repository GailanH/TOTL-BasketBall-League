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
    @State private var saveMessageIsError = false

    @State private var showImagePicker = false
    @State private var errorLoadingPlayer = false

    private static let membershipOptions = ["Casual", "Competitive"]

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

                if AppConstants.isStaff(role.lowercased()) {
                    Picker("Membership", selection: $membership) {
                        ForEach(Self.membershipOptions, id: \.self) { option in
                            Text(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            if let saveMessage = saveMessage {
                Label(saveMessage, systemImage: saveMessageIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundColor(saveMessageIsError ? .red : .green)
            }

            Button("Save Changes") {
                saveChanges()
            }
            .disabled(username.isEmpty || email.isEmpty)
        }
        .scrollContentBackground(.hidden)
        .background(Color("AppBackground").ignoresSafeArea())
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
            self.membership = Self.membershipOptions.contains(player.membership ?? "")
                ? (player.membership ?? Self.membershipOptions[0])
                : Self.membershipOptions[0]
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

            if AppConstants.isStaff(role.lowercased()) {
                player.membership = membership
            }

            try viewContext.save()
            saveMessageIsError = false
            saveMessage = "Saved successfully"
        } catch {
            print("❌ Failed to save player: \(error)")
            saveMessageIsError = true
            saveMessage = "Failed to save changes"
        }
    }
}

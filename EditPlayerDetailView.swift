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
    @State private var messageIsError = false

    @State private var gameToEdit: Game?
    @State private var gameToDelete: Game?
    @State private var showRemoveImageConfirmation = false

    @State private var newPassword = ""
    @State private var confirmNewPassword = ""
    @State private var passwordMessage = ""
    @State private var passwordMessageIsError = false

    enum Field: Hashable {
        case newPassword, confirmPassword
    }
    @FocusState private var focusedField: Field?

    private let memberships = ["Casual", "Competitive", "Deactivated"]
    private let roles = [AppConstants.playerRole, AppConstants.employeeRole]

    private func displayName(forRole role: String) -> String {
        role == AppConstants.employeePendingRole ? "Pending" : role.capitalized
    }

    private var recentGames: [Game] {
        ((player.games as? Set<Game>) ?? [])
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
            .prefix(10)
            .map { $0 }
    }

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
                            Text(displayName(forRole: role))
                        }
                    }
                    .pickerStyle(.segmented)
                } else {
                    Text("Role: \(displayName(forRole: player.role ?? AppConstants.playerRole))")
                        .foregroundColor(player.role == AppConstants.employeePendingRole ? .orange : .gray)
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

                    Button {
                        showRemoveImageConfirmation = true
                    } label: {
                        Label("Remove Image", systemImage: "xmark.circle.fill")
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
                Label(message, systemImage: messageIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundColor(messageIsError ? .red : .green)
            }

            Section(header: Text("Recent Games")) {
                if recentGames.isEmpty {
                    Text("No games logged.")
                        .foregroundColor(.gray)
                } else {
                    ForEach(recentGames, id: \.self) { game in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(game.date?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown date")
                                    .font(.subheadline).bold()
                                Spacer()
                                Text("\(game.rpDelta >= 0 ? "+" : "")\(game.rpDelta) RP")
                                    .font(.caption)
                                    .foregroundColor(game.rpDelta >= 0 ? .green : .red)
                            }
                            Text("PTS: \(game.points)  REB: \(game.rebounds)  AST: \(game.assists)  BLK: \(game.blocks)  STL: \(game.steals)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack(spacing: 16) {
                                Button("Edit") {
                                    gameToEdit = game
                                }
                                .font(.caption)

                                Button("Delete", role: .destructive) {
                                    gameToDelete = game
                                }
                                .font(.caption)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section(header: Text("Reset Password"), footer: Text("For when a player forgets their password — set a new one for them in person.")) {
                PasswordField(
                    title: "New Password", text: $newPassword,
                    focusedField: $focusedField, fieldID: .newPassword,
                    submitLabel: .next, onSubmit: { focusedField = .confirmPassword }
                )
                PasswordField(
                    title: "Confirm New Password", text: $confirmNewPassword,
                    focusedField: $focusedField, fieldID: .confirmPassword,
                    submitLabel: .done, onSubmit: { focusedField = nil; resetPassword() }
                )

                if !passwordMessage.isEmpty {
                    Label(passwordMessage, systemImage: passwordMessageIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundColor(passwordMessageIsError ? .red : .green)
                }

                Button("Reset Password") {
                    resetPassword()
                }
                .disabled(newPassword.isEmpty)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollContentBackground(.hidden)
        .background(Color("AppBackground").ignoresSafeArea())
        .onAppear {
            selectedMembership = player.membership ?? "None"
            // Pending isn't a pickable option — default the editor to Player so approving
            // requires deliberately selecting Employee, rather than pending silently mapping to it.
            selectedRole = player.role == AppConstants.employeeRole ? AppConstants.employeeRole : AppConstants.playerRole
        }
        .navigationTitle(player.username ?? "Edit Player")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(item: $gameToEdit) { game in
            EditGameView(game: game, player: player)
        }
        .confirmationDialog(
            "Remove this profile image?",
            isPresented: $showRemoveImageConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove Image", role: .destructive) { removeImage() }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Delete this game? This will also undo its effect on rank points.",
            isPresented: Binding(get: { gameToDelete != nil }, set: { if !$0 { gameToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete Game", role: .destructive) {
                if let gameToDelete {
                    deleteGame(gameToDelete)
                }
                gameToDelete = nil
            }
            Button("Cancel", role: .cancel) { gameToDelete = nil }
        }
    }

    private func saveChanges() {
        player.membership = selectedMembership

        if allowRoleEdit {
            player.role = selectedRole
        }

        do {
            try viewContext.save()
            messageIsError = false
            message = "Changes saved!"
        } catch {
            viewContext.rollback()
            messageIsError = true
            message = "Error saving: \(error.localizedDescription)"
        }
    }

    private func removeImage() {
        player.profileImage = nil
        do {
            try viewContext.save()
            messageIsError = false
            message = "Image removed."
        } catch {
            viewContext.rollback()
            messageIsError = true
            message = "Couldn't remove image: \(error.localizedDescription)"
        }
    }

    private func deleteGame(_ game: Game) {
        let oldRank = RankSystem.rankName(for: player.rankPoints)
        player.rankPoints = max(0, player.rankPoints - game.rpDelta)
        viewContext.delete(game)

        let newRank = RankSystem.rankName(for: player.rankPoints)
        if newRank != oldRank {
            let change = RankChange(context: viewContext)
            change.id = UUID()
            change.date = Date()
            change.newRank = newRank
            change.player = player
            player.lastRank = newRank
        }

        do {
            try viewContext.save()
            messageIsError = false
            message = "Game deleted."
        } catch {
            viewContext.rollback()
            messageIsError = true
            message = "Couldn't delete game: \(error.localizedDescription)"
        }
    }

    private func resetPassword() {
        guard newPassword.count >= 8 else {
            passwordMessageIsError = true
            passwordMessage = "Password must be at least 8 characters."
            return
        }
        guard newPassword == confirmNewPassword else {
            passwordMessageIsError = true
            passwordMessage = "Passwords do not match."
            return
        }

        let salt = PasswordHasher.generateSalt()
        player.passwordSalt = salt
        player.password = PasswordHasher.hash(password: newPassword, salt: salt)

        do {
            try viewContext.save()
            passwordMessageIsError = false
            passwordMessage = "Password reset."
            newPassword = ""
            confirmNewPassword = ""
        } catch {
            viewContext.rollback()
            passwordMessageIsError = true
            passwordMessage = "Couldn't reset password: \(error.localizedDescription)"
        }
    }
}

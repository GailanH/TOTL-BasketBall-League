import SwiftUI
import CoreData

struct LoginView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var username = ""
    @State private var password = ""
    @State private var showRegistration = false
    @State private var registrationUsername = ""
    @State private var registrationEmail = ""
    @State private var registrationPassword = ""
    @State private var registrationConfirmPassword = ""
    @State private var isEmployee = false
    @State private var registrationMembership = LoginView.noMembershipOption
    @Binding var loggedInPlayer: Player?

    @State private var loginError: String?
    @State private var registrationError: String?

    private static let noMembershipOption = "No membership at this time"
    private let membershipOptions = ["Casual", "Competitive", LoginView.noMembershipOption]

    enum Field: Hashable {
        case loginUsername, loginPassword
        case regUsername, regEmail, regPassword, regConfirmPassword
    }
    @FocusState private var focusedField: Field?

    var body: some View {
        NavigationStack {
            ZStack {
                Color("AppBackground").ignoresSafeArea()
                    .onTapGesture { focusedField = nil }

                VStack(spacing: 20) {
                    Spacer()

                    if showRegistration {
                        Text("Create Account")
                            .font(.title2).bold()

                        TextField("Username", text: $registrationUsername)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .regUsername)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .regEmail }

                        TextField("Email", text: $registrationEmail)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .focused($focusedField, equals: .regEmail)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .regPassword }

                        PasswordField(
                            title: "Password", text: $registrationPassword,
                            focusedField: $focusedField, fieldID: .regPassword,
                            submitLabel: .next, onSubmit: { focusedField = .regConfirmPassword }
                        )
                        .textFieldStyle(.roundedBorder)

                        PasswordField(
                            title: "Confirm Password", text: $registrationConfirmPassword,
                            focusedField: $focusedField, fieldID: .regConfirmPassword,
                            submitLabel: .done, onSubmit: { focusedField = nil }
                        )
                        .textFieldStyle(.roundedBorder)

                        VStack(spacing: 4) {
                            Text("Membership")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Picker("Membership", selection: $registrationMembership) {
                                ForEach(membershipOptions, id: \.self) { option in
                                    Text(option)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Text("Payment isn't collected yet — membership billing is coming later. \"No membership\" still gets you an account with minimal access.")
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)

                        Toggle("Register as Employee", isOn: $isEmployee)

                        if isEmployee {
                            Text("Employee accounts require approval from an existing staff member before staff features unlock.")
                                .font(.footnote)
                                .foregroundColor(.gray)
                        }

                        if let error = registrationError {
                            Text(error)
                                .foregroundColor(.red)
                        }

                        HStack(spacing: 16) {
                            Button("Back") {
                                showRegistration = false
                                clearRegistrationFields()
                            }
                            .foregroundColor(.gray)

                            Button("Register") {
                                register()
                            }
                            .buttonStyle(.borderedProminent)
                        }

                    } else {
                        Text("Login")
                            .font(.title).bold()

                        TextField("Username", text: $username)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .loginUsername)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .loginPassword }

                        PasswordField(
                            title: "Password", text: $password,
                            focusedField: $focusedField, fieldID: .loginPassword,
                            submitLabel: .done, onSubmit: { focusedField = nil; login() }
                        )
                        .textFieldStyle(.roundedBorder)

                        if let error = loginError {
                            Text(error)
                                .foregroundColor(.red)
                        }

                        Button("Login") {
                            login()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Create Account") {
                            showRegistration = true
                            clearLoginFields()
                        }
                    }

                    Spacer()
                }
                .padding()
            }
        }
    }

    private func login() {
        loginError = nil
        let fetchRequest: NSFetchRequest<Player> = Player.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "username ==[c] %@", username)
        fetchRequest.fetchLimit = 1

        do {
            let result = try viewContext.fetch(fetchRequest)
            guard let player = result.first,
                  let storedHash = player.password,
                  let salt = player.passwordSalt,
                  PasswordHasher.verify(password: password, salt: salt, hash: storedHash)
            else {
                loginError = "Invalid username or password."
                return
            }
            loggedInPlayer = player
        } catch {
            loginError = "Login failed: \(error.localizedDescription)"
        }
    }

    private func register() {
        registrationError = nil

        let trimmedUsername = registrationUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = registrationEmail.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedUsername.isEmpty, !trimmedEmail.isEmpty,
              !registrationPassword.isEmpty, !registrationConfirmPassword.isEmpty else {
            registrationError = "All fields are required."
            return
        }

        guard AccountValidation.isValidUsername(trimmedUsername) else {
            registrationError = AccountValidation.usernameRule
            return
        }

        guard AccountValidation.isValidEmail(trimmedEmail) else {
            registrationError = "Enter a valid email address."
            return
        }

        guard AccountValidation.isValidPassword(registrationPassword) else {
            registrationError = AccountValidation.passwordRule
            return
        }

        guard registrationPassword == registrationConfirmPassword else {
            registrationError = "Passwords do not match."
            return
        }

        // Check if username or email already exists
        let checkRequest: NSFetchRequest<Player> = Player.fetchRequest()
        checkRequest.predicate = NSPredicate(
            format: "username ==[c] %@ OR email ==[c] %@", trimmedUsername, trimmedEmail
        )

        do {
            let existing = try viewContext.fetch(checkRequest)
            guard existing.isEmpty else {
                registrationError = "Username or email already taken."
                return
            }

            let salt = PasswordHasher.generateSalt()
            let newPlayer = Player(context: viewContext)
            newPlayer.username = trimmedUsername
            newPlayer.email = trimmedEmail
            newPlayer.password = PasswordHasher.hash(password: registrationPassword, salt: salt)
            newPlayer.passwordSalt = salt
            if trimmedUsername.caseInsensitiveCompare(AppConstants.ownerUsername) == .orderedSame {
                newPlayer.role = AppConstants.administratorRole
            } else {
                newPlayer.role = isEmployee ? employeeRegistrationRole() : AppConstants.playerRole
            }
            newPlayer.rankPoints = 0
            newPlayer.membership = registrationMembership == Self.noMembershipOption ? nil : registrationMembership

            let startingRank = RankSystem.rankName(for: 0)
            newPlayer.lastRank = startingRank

            let initialRankChange = RankChange(context: viewContext)
            initialRankChange.id = UUID()
            initialRankChange.date = Date()
            initialRankChange.newRank = startingRank
            initialRankChange.player = newPlayer

            try viewContext.save()
            loggedInPlayer = newPlayer
        } catch {
            registrationError = "Registration failed: \(error.localizedDescription)"
        }
    }

    /// The very first staff account on a fresh install is auto-approved so there's always
    /// someone able to approve the rest. Every employee signup after that starts pending.
    private func employeeRegistrationRole() -> String {
        let employeeCheck: NSFetchRequest<Player> = Player.fetchRequest()
        employeeCheck.predicate = NSPredicate(format: "role IN %@", AppConstants.staffRoles)
        employeeCheck.fetchLimit = 1

        let alreadyHasApprovedEmployee = ((try? viewContext.count(for: employeeCheck)) ?? 0) > 0
        return alreadyHasApprovedEmployee ? AppConstants.employeePendingRole : AppConstants.employeeRole
    }

    private func clearLoginFields() {
        username = ""
        password = ""
        loginError = nil
    }

    private func clearRegistrationFields() {
        registrationUsername = ""
        registrationEmail = ""
        registrationPassword = ""
        registrationConfirmPassword = ""
        isEmployee = false
        registrationMembership = Self.noMembershipOption
        registrationError = nil
    }
}

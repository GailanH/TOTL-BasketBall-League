import SwiftUI
import CoreData

struct LoginView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var username = ""
    @State private var password = ""
    @State private var showRegistration = false
    @State private var registrationUsername = ""
    @State private var registrationPassword = ""
    @State private var isEmployee = false
    @State private var secretKey = ""
    @Binding var loggedInPlayer: Player?

    @State private var loginError: String?
    @State private var registrationError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 20) {
                    Spacer()

                    if showRegistration {
                        Text("Create Account")
                            .font(.title2).bold()

                        TextField("Username", text: $registrationUsername)
                            .textFieldStyle(.roundedBorder)

                        SecureField("Password", text: $registrationPassword)
                            .textFieldStyle(.roundedBorder)

                        Toggle("Register as Employee", isOn: $isEmployee)

                        if isEmployee {
                            SecureField("Secret Key", text: $secretKey)
                                .textFieldStyle(.roundedBorder)
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

                        SecureField("Password", text: $password)
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
        fetchRequest.predicate = NSPredicate(format: "username == %@ AND password == %@", username, password)
        fetchRequest.fetchLimit = 1

        do {
            let result = try viewContext.fetch(fetchRequest)
            if let player = result.first {
                loggedInPlayer = player
            } else {
                loginError = "Invalid username or password."
            }
        } catch {
            loginError = "Login failed: \(error.localizedDescription)"
        }
    }

    private func register() {
        registrationError = nil

        guard !registrationUsername.isEmpty, !registrationPassword.isEmpty else {
            registrationError = "All fields are required."
            return
        }

        if isEmployee && secretKey != AppConstants.employeeSecretKey {
            registrationError = "Incorrect secret key."
            return
        }

        // Check if username already exists
        let checkRequest: NSFetchRequest<Player> = Player.fetchRequest()
        checkRequest.predicate = NSPredicate(format: "username == %@", registrationUsername)

        do {
            let existing = try viewContext.fetch(checkRequest)
            if !existing.isEmpty {
                registrationError = "Username already taken."
                return
            }

            let newPlayer = Player(context: viewContext)
            newPlayer.username = registrationUsername
            newPlayer.password = registrationPassword
            newPlayer.role = isEmployee ? "employee" : "player"
            newPlayer.rankPoints = 0
            newPlayer.membership = nil  // Default membership for all
            newPlayer.lastRank = nil

            try viewContext.save()
            loggedInPlayer = newPlayer
        } catch {
            registrationError = "Registration failed: \(error.localizedDescription)"
        }
    }

    private func clearLoginFields() {
        username = ""
        password = ""
        loginError = nil
    }

    private func clearRegistrationFields() {
        registrationUsername = ""
        registrationPassword = ""
        isEmployee = false
        secretKey = ""
        registrationError = nil
    }
}

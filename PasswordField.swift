import SwiftUI

/// A SecureField with a show/hide toggle, plus optional focus-chaining support so it can
/// participate in a form's "Return moves to next field" flow like any other TextField.
struct PasswordField<Field: Hashable>: View {
    let title: String
    @Binding var text: String
    var focusedField: FocusState<Field?>.Binding
    let fieldID: Field
    var submitLabel: SubmitLabel = .next
    var onSubmit: () -> Void = {}

    @State private var isRevealed = false

    var body: some View {
        HStack {
            Group {
                if isRevealed {
                    TextField(title, text: $text)
                } else {
                    SecureField(title, text: $text)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused(focusedField, equals: fieldID)
            .submitLabel(submitLabel)
            .onSubmit(onSubmit)

            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRevealed ? "Hide password" : "Show password")
        }
    }
}

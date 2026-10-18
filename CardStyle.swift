import SwiftUI

extension View {
    /// The app's shared "card" look: background matches the cream theme (not a flat system
    /// gray, which reads as a mismatched blob against it), a soft border to define the edge,
    /// and generous rounding so it doesn't look like a stark table row.
    func cardStyle(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(Color("AppBackground"))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.primary.opacity(0.35), lineWidth: 1.5)
            )
            .cornerRadius(cornerRadius)
    }
}

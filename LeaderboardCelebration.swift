import SwiftUI

/// Gold / silver / bronze styling for leaderboard places 1–3.
enum Podium {
    static func color(for place: Int) -> Color? {
        switch place {
        case 1: return Color(red: 0.85, green: 0.65, blue: 0.13)   // gold
        case 2: return Color(red: 0.62, green: 0.65, blue: 0.70)   // silver
        case 3: return Color(red: 0.72, green: 0.45, blue: 0.20)   // bronze
        default: return nil
        }
    }

    static func ordinal(_ place: Int) -> String {
        switch place {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(place)th"
        }
    }
}

/// Shown at the top of the leaderboard when the viewer is in the top 3: a medal, their place,
/// and a one-time confetti burst (skipped when Reduce Motion is on).
struct PodiumCelebrationBanner: View {
    let place: Int
    let seasonName: String
    let rank: String
    let rankPoints: Int64

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private var color: Color { Podium.color(for: place) ?? .accentColor }

    private var headline: String {
        switch place {
        case 1: return "You're #1!"
        case 2: return "You're #2!"
        default: return "You're #3!"
        }
    }

    private var subline: String {
        switch place {
        case 1: return "Top of the ladder in \(seasonName). Everyone's chasing you."
        case 2: return "Runner-up in \(seasonName). One spot from the top."
        default: return "On the podium in \(seasonName). Keep climbing."
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                Image(systemName: "medal.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(color.gradient)
                    .shadow(color: color.opacity(0.6), radius: 10)
                    .scaleEffect(appeared || reduceMotion ? 1 : 0.4)
                    .rotationEffect(.degrees(appeared || reduceMotion ? 0 : -25))

                Text(headline)
                    .font(.title).bold()
                Text(subline)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Text("\(rank) · \(rankPoints) RP")
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.18))
                    .clipShape(Capsule())
            }
            .padding(.vertical, 20)
            .padding(.horizontal)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(colors: [color.opacity(0.28), color.opacity(0.08)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(color.opacity(0.7), lineWidth: 2))

            if !reduceMotion {
                ConfettiBurst(accent: color)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(headline) \(Podium.ordinal(place)) place in \(seasonName). \(rank), \(rankPoints) RP.")
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { appeared = true }
        }
    }
}

/// A short burst of falling confetti that plays once when it appears.
struct ConfettiBurst: View {
    let accent: Color
    var duration: Double = 2.8

    private struct Piece {
        let x: Double, delay: Double, speed: Double, drift: Double, spin: Double, size: Double
        let color: Color
    }

    @State private var start = Date()
    @State private var pieces: [Piece] = []

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: Date().timeIntervalSince(start) > duration + 1)) { context in
            Canvas { canvas, size in
                let elapsed = context.date.timeIntervalSince(start)
                for piece in pieces {
                    let t = elapsed - piece.delay
                    guard t > 0 else { continue }
                    let y = -20 + t * piece.speed * size.height
                    guard y < size.height + 20 else { continue }
                    let x = piece.x * size.width + sin(t * 3 + piece.drift) * 18
                    let opacity = max(0, 1 - max(0, elapsed - duration + 0.6) / 0.6)
                    var rect = canvas
                    rect.opacity = opacity
                    rect.translateBy(x: x, y: y)
                    rect.rotate(by: .radians(t * piece.spin))
                    rect.fill(Path(CGRect(x: -piece.size / 2, y: -piece.size / 4, width: piece.size, height: piece.size / 2)),
                              with: .color(piece.color))
                }
            }
        }
        .onAppear {
            start = Date()
            let palette: [Color] = [accent, .red, .blue, .green, .orange, .purple, .yellow]
            pieces = (0..<70).map { _ in
                Piece(x: .random(in: 0...1), delay: .random(in: 0...0.8), speed: .random(in: 0.35...0.7),
                      drift: .random(in: 0...6), spin: .random(in: -8...8), size: .random(in: 6...11),
                      color: palette.randomElement()!)
            }
        }
    }
}

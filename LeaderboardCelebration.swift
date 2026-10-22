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
    let standing: LeaderboardStanding
    let seasonName: String

    private var place: Int { standing.place }
    private var rank: String { standing.rank }
    private var rankPoints: Int64 { standing.rankPoints }

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
                StandingGaps(standing: standing)
                    .padding(.top, 2)
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


/// "N RP behind #3 name · N RP ahead of #5 name"
struct StandingGaps: View {
    let standing: LeaderboardStanding

    var body: some View {
        VStack(spacing: 2) {
            if let above = standing.above {
                Label("\(above.gap) RP behind #\(above.place) \(above.username)", systemImage: "arrow.up")
            }
            if let below = standing.below {
                Label("\(below.gap) RP ahead of #\(below.place) \(below.username)", systemImage: "arrow.down")
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .labelStyle(.titleAndIcon)
    }
}

/// The "Your Standing" card at the top of the leaderboard for players outside the top 3.
struct StandingCard: View {
    let standing: LeaderboardStanding
    let seasonName: String

    var body: some View {
        VStack(spacing: 10) {
            Text("Your Standing · \(seasonName)")
                .font(.caption).bold()
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("#\(standing.place)")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                Text("of \(standing.totalPlayers)")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            Text("\(standing.rank) · \(standing.rankPoints) RP")
                .font(.headline)

            TierProgressBar(standing: standing)
            StandingGaps(standing: standing)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.accentColor.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.accentColor.opacity(0.5), lineWidth: 1.5))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("standingCard")
    }
}

/// Progress through the current tier toward the next.
struct TierProgressBar: View {
    let standing: LeaderboardStanding

    var body: some View {
        VStack(spacing: 4) {
            ProgressView(value: standing.tierProgress)
                .tint(Podium.color(for: standing.place) ?? .accentColor)
            if let next = standing.nextTier {
                Text("\(next.rpToGo) RP to \(next.name)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Top tier")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 24)
    }
}

/// The slim bar the standing card collapses into once it scrolls off screen. Tapping it
/// scrolls back to the player's row.
struct CompactStandingBar: View {
    let standing: LeaderboardStanding
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                if let medal = Podium.color(for: standing.place) {
                    Image(systemName: "medal.fill").foregroundStyle(medal)
                }
                Text("#\(standing.place)")
                    .font(.headline.monospacedDigit())
                Text("You · \(standing.rank)")
                    .font(.subheadline)
                Spacer()
                Text("\(standing.rankPoints) RP")
                    .font(.subheadline.monospacedDigit()).bold()
                Image(systemName: "arrow.down.circle")
                    .foregroundColor(.secondary)
            }
            .foregroundColor(.primary)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .overlay(alignment: .bottom) {
                ProgressView(value: standing.tierProgress)
                    .tint(Podium.color(for: standing.place) ?? .accentColor)
                    .scaleEffect(x: 1, y: 0.6, anchor: .bottom)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("You're number \(standing.place) of \(standing.totalPlayers), \(standing.rank), \(standing.rankPoints) RP. Show my row.")
        .accessibilityIdentifier("compactStandingBar")
    }
}

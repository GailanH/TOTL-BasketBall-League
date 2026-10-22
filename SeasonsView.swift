import SwiftUI
import CoreData

/// Staff screen: the current season, past seasons, and the "Start New Season" rollover.
struct SeasonsView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [SortDescriptor(\Season.number, order: .reverse)],
        animation: .default
    ) private var seasons: FetchedResults<Season>

    @State private var confirmNewSeason = false
    @State private var message = ""
    @State private var messageIsError = false

    private var active: Season? { seasons.first { $0.isActive } }

    var body: some View {
        Form {
            Section(header: Text("Current Season")) {
                if let active {
                    Text(active.name ?? "Season").font(.headline)
                    Text("Started \(Self.format(active.startDate))")
                    Text("Scheduled end \(Self.format(active.endDate))")
                    Text("\((active.matches as? Set<Match>)?.count ?? 0) games recorded")
                        .foregroundColor(.secondary)
                    if SeasonManager.isPastScheduledEnd(active) {
                        Label("The scheduled \(CompetitiveRules.seasonLengthMonths) months are up.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    }
                } else {
                    Text("No season yet. Season 1 starts automatically with the first recorded game, or start it now.")
                        .foregroundColor(.secondary)
                }

                Button(active == nil ? "Start Season 1" : "Start New Season", role: active == nil ? ButtonRole?.none : .destructive) {
                    confirmNewSeason = true
                }
                .accessibilityIdentifier("startSeasonButton")
            }

            Section(header: Text("How a new season works")) {
                Text("Every player drops \(CompetitiveRules.softResetTierDrop) tiers, to the bottom of that tier (e.g. Gold II → Silver II). Everyone then plays \(CompetitiveRules.placementGames) placement games worth \(CompetitiveRules.placementMultiplier)× RP and appears on the leaderboard once placed.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !message.isEmpty {
                Label(message, systemImage: messageIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundColor(messageIsError ? .red : .green)
            }

            let past = seasons.filter { !$0.isActive }
            if !past.isEmpty {
                Section(header: Text("Past Seasons")) {
                    ForEach(past, id: \.objectID) { season in
                        VStack(alignment: .leading) {
                            Text(season.name ?? "Season")
                            Text("\(Self.format(season.startDate)) – \(Self.format(season.endDate))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("AppBackground").ignoresSafeArea())
        .navigationTitle("Seasons")
        .confirmationDialog(
            active == nil
                ? "Start Season 1 now?"
                : "End \(active?.name ?? "this season") and start a new one? Every player's rank is soft-reset. This can't be undone.",
            isPresented: $confirmNewSeason,
            titleVisibility: .visible
        ) {
            Button(active == nil ? "Start Season 1" : "Start New Season", role: .destructive) { startSeason() }
                .accessibilityIdentifier("confirmStartSeason")
            Button("Cancel", role: .cancel) {}
        }
    }

    private func startSeason() {
        do {
            let season: Season
            if active == nil {
                season = SeasonManager.ensureActiveSeason(in: viewContext)
                try viewContext.save()
            } else {
                season = try SeasonManager.startNewSeason(in: viewContext)
            }
            messageIsError = false
            message = "\(season.name ?? "New season") started."
        } catch {
            viewContext.rollback()
            messageIsError = true
            message = "Couldn't start the season: \(error.localizedDescription)"
        }
    }

    private static func format(_ date: Date?) -> String {
        date?.formatted(date: .abbreviated, time: .omitted) ?? "—"
    }
}

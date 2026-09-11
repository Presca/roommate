import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: RoommateModel
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    characterCard
                    moodCard
                    scheduleCard
                    previewCard
                    if !model.history.isEmpty { historyCard }
                }
                .padding(20)
            }
            .background(Theme.cream.ignoresSafeArea())
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("roommate")
                        .font(.cute(22, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(Theme.soft)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(model)
            }
            .alert("hmm", isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )) {
                Button("okay") { model.errorMessage = nil }
            } message: {
                Text(model.errorMessage ?? "")
            }
        }
        .tint(Theme.skyDark)
    }

    // MARK: cards

    private var characterCard: some View {
        VStack(spacing: 12) {
            CharacterImage(name: model.sittingPose)
                .id(model.sittingPose)
                .transition(.opacity)
                .frame(height: 230)
                .animation(.easeInOut(duration: 0.4), value: model.sittingPose)
            Text(model.moodCaption)
                .font(.cute(18, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text(statusLine)
                .font(.cute(14))
                .foregroundStyle(Theme.soft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .cuteCard()
    }

    private var statusLine: String {
        if !model.isEnabled { return "she's not watching your bedtime yet. turn her on in settings ⚙️" }
        switch model.stage {
        case .none:      return "she'll come check on you at \(model.bedtimeString)"
        case .sleepy:    return model.isDemo
            ? "she's up. (demo: nothing is blocked, but she's counting.)"
            : "she's up and waiting for you to turn the phone off"
        case .frustrated: return "she's back, and less patient this time"
        case .fuming:    return "she's really fed up. lights off."
        case .asleep:    return "she's asleep. keep it down until \(model.wakeTimeString)"
        }
    }

    private var moodCard: some View {
        VStack(spacing: 16) {
            MoodBar(title: "happiness", emoji: "♡", value: model.happiness, color: Theme.blush)
            MoodBar(title: "frustration", emoji: "💢", value: model.frustration, color: Theme.grumpy)
            Text("she gets happier every night you let her sleep, and annoyed every time you keep the screen on past bedtime.")
                .font(.cute(13))
                .foregroundStyle(Theme.soft)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .cuteCard()
    }

    private var scheduleCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("lights off")
                    .font(.cute(13))
                    .foregroundStyle(Theme.soft)
                Text(model.bedtimeString)
                    .font(.cute(24, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 4) {
                Text("she wakes up")
                    .font(.cute(13))
                    .foregroundStyle(Theme.soft)
                Text(model.wakeTimeString)
                    .font(.cute(24, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            Circle()
                .fill(model.isEnabled ? Theme.mint : Theme.ink.opacity(0.08))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: model.isEnabled ? "moon.zzz.fill" : "moon")
                        .foregroundStyle(model.isEnabled ? Theme.skyDark : Theme.soft)
                )
        }
        .cuteCard()
        .onTapGesture { showSettings = true }
    }

    private var previewCard: some View {
        Menu {
            Button("first visit (sleepy)") { model.preview(stage: .sleepy) }
            Button("second visit (frustrated)") { model.preview(stage: .frustrated) }
            Button("third visit (fuming)") { model.preview(stage: .fuming) }
        } label: {
            HStack {
                Text("preview her visit")
                    .font(.cute(17, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Image(systemName: "play.fill")
                    .foregroundStyle(Theme.skyDark)
            }
            .cuteCard()
        }
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("recent nights")
                .font(.cute(17, weight: .semibold))
                .foregroundStyle(Theme.ink)
            ForEach(model.history.prefix(7)) { night in
                HStack {
                    Text(night.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                        .font(.cute(14))
                        .foregroundStyle(Theme.soft)
                        .frame(width: 92, alignment: .leading)
                    Text(night.summary)
                        .font(.cute(15))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cuteCard()
    }
}

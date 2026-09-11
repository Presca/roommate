import SwiftUI
import Combine
import FamilyControls

struct VisitRequest: Identifiable {
    let id = UUID()
    let stage: Stage
    let isPreview: Bool
}

/// Observable mirror of `MoodStore` for SwiftUI, plus the Screen Time plumbing.
@MainActor
final class RoommateModel: ObservableObject {
    let store = MoodStore.shared

    @Published var happiness = 70
    @Published var frustration = 10
    @Published var stage: Stage = .none
    @Published var sittingPose = "sit-neutral"
    @Published var moodCaption = ""
    @Published var history: [NightRecord] = []

    @Published var bedtime = Date()
    @Published var wakeTime = Date()
    @Published var isEnabled = false
    @Published var shieldAllApps = false
    @Published var selection = FamilyActivitySelection()

    @Published var isAuthorized = false
    @Published var errorMessage: String?
    @Published var visit: VisitRequest?

    #if DEMO
    let isDemo = true
    #else
    let isDemo = false
    #endif

    init() {
        refresh()
    }

    // MARK: Reading

    func refresh() {
        ScreenTimeManager.handleForeground(mood: store)
        happiness = store.happiness
        frustration = store.frustration
        stage = store.stage
        sittingPose = store.sittingPose
        moodCaption = store.moodCaption
        history = store.history.reversed()
        bedtime = Self.date(from: store.bedtime)
        wakeTime = Self.date(from: store.wakeTime)
        isEnabled = store.isEnabled
        shieldAllApps = store.shieldAllApps
        selection = store.selection
        isAuthorized = ScreenTimeManager.isAuthorized

        // She was waiting for you (bedtime notification, or you opened the app at night).
        if let pending = store.pendingVisitStage, visit == nil {
            store.pendingVisitStage = nil
            visit = VisitRequest(stage: pending, isPreview: false)
        }
    }

    var bedtimeString: String { store.bedtimeString }
    var wakeTimeString: String { store.wakeTimeString }

    var selectionSummary: String {
        let apps = selection.applicationTokens.count
        let cats = selection.categoryTokens.count
        let sites = selection.webDomainTokens.count
        if apps + cats + sites == 0 { return "no apps picked yet" }
        var parts: [String] = []
        if apps > 0 { parts.append("\(apps) app\(apps == 1 ? "" : "s")") }
        if cats > 0 { parts.append("\(cats) categor\(cats == 1 ? "y" : "ies")") }
        if sites > 0 { parts.append("\(sites) site\(sites == 1 ? "" : "s")") }
        return parts.joined(separator: ", ")
    }

    var hasSelection: Bool {
        !(selection.applicationTokens.isEmpty
          && selection.categoryTokens.isEmpty
          && selection.webDomainTokens.isEmpty)
    }

    // MARK: Writing

    func updateBedtime(_ date: Date) {
        bedtime = date
        store.bedtime = Self.components(from: date)
        restartIfEnabled()
    }

    func updateWakeTime(_ date: Date) {
        wakeTime = date
        store.wakeTime = Self.components(from: date)
        restartIfEnabled()
    }

    func updateSelection(_ sel: FamilyActivitySelection) {
        selection = sel
        store.selection = sel
        restartIfEnabled()
    }

    func updateShieldAllApps(_ on: Bool) {
        shieldAllApps = on
        store.shieldAllApps = on
        if isEnabled && store.isBedtime() && stage != .none {
            Shielding.apply(using: store)
        }
    }

    /// The big switch. Asks for Screen Time + notification permission the first time.
    func setEnabled(_ on: Bool) async {
        errorMessage = nil
        if on {
            do {
                try await ScreenTimeManager.requestAuthorization()
                await ScreenTimeManager.requestNotificationPermission()
                isAuthorized = ScreenTimeManager.isAuthorized
                try ScreenTimeManager.startMonitoring(mood: store)
                store.isEnabled = true
            } catch {
                store.isEnabled = false
                errorMessage = "couldn't turn her on: \(error.localizedDescription)"
            }
        } else {
            ScreenTimeManager.stopMonitoring(mood: store)
            store.isEnabled = false
        }
        refresh()
    }

    private func restartIfEnabled() {
        guard isEnabled else { return }
        do {
            try ScreenTimeManager.startMonitoring(mood: store)
        } catch {
            errorMessage = "couldn't update her schedule: \(error.localizedDescription)"
        }
    }

    /// From the in-app visit: "okay, I'll turn it off".
    func comply() {
        store.complied()
        if isEnabled {
            Shielding.apply(using: store)
            ScreenTimeManager.didComply(mood: store)
        }
        refresh()
    }

    /// From the in-app visit: "not yet...".
    func snooze() {
        store.snoozed()
        if isEnabled {
            Shielding.clear()
            ScreenTimeManager.didSnooze(mood: store)
        }
        refresh()
    }

    func resetMood() {
        store.resetMood()
        refresh()
    }

    func preview(stage: Stage) {
        visit = VisitRequest(stage: stage, isPreview: true)
    }

    // MARK: Deep links: roommate://visit?stage=2

    func handle(url: URL) {
        guard url.scheme == RoommateConfig.urlScheme, url.host == "visit" else { return }
        let raw = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "stage" })?.value
        let stage = raw.flatMap(Int.init).flatMap(Stage.init(rawValue:)) ?? .sleepy
        visit = VisitRequest(stage: stage, isPreview: !isEnabled)
    }

    // MARK: Helpers

    static func date(from c: DateComponents) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = c.hour ?? 0
        comps.minute = c.minute ?? 0
        return Calendar.current.date(from: comps) ?? Date()
    }

    static func components(from date: Date) -> DateComponents {
        Calendar.current.dateComponents([.hour, .minute], from: date)
    }
}

import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

// MARK: - Constants shared by the app and its three Screen Time extensions

enum RoommateConfig {
    /// Must match the App Group in project.yml (and in every target's entitlements).
    static let appGroup = "group.com.presca.roommate"
    static let storeName = ManagedSettingsStore.Name("roommate")
    static let bedtimeActivity = DeviceActivityName("roommate.bedtime")
    static let urlScheme = "roommate"
    /// Minutes of phone use (after she asked you to stop) before she comes back.
    static let escalationMinutes = 15
    /// How many escalation events to register per night (8 × 15 min = 2 h).
    static let escalationSteps = 8
}

extension DeviceActivityEvent.Name {
    static func disturbed(_ step: Int) -> DeviceActivityEvent.Name {
        DeviceActivityEvent.Name("roommate.disturbed.\(step)")
    }
    var disturbedStep: Int? {
        guard rawValue.hasPrefix("roommate.disturbed.") else { return nil }
        return Int(rawValue.dropFirst("roommate.disturbed.".count))
    }
}

// MARK: - Where she is right now

enum Stage: Int, Codable, CaseIterable {
    case none = 0        // daytime, she's out living her life
    case sleepy = 1      // first visit: peeking through the door
    case frustrated = 2  // second visit: "please, I'm trying to sleep"
    case fuming = 3      // third+ visit: scribble cloud
    case asleep = 4      // you said goodnight; she's back in bed

    var standingPose: String {
        switch self {
        case .none, .sleepy: return "pose-peek"
        case .frustrated:    return "pose-frustrated"
        case .fuming:        return "pose-frustrated"
        case .asleep:        return "pose-walk"
        }
    }

    var emoji: String {
        switch self {
        case .none: return "☀️"
        case .sleepy: return "😴"
        case .frustrated: return "😒"
        case .fuming: return "💢"
        case .asleep: return "💤"
        }
    }
}

// MARK: - What she says

enum RoommateLines {
    /// Lines shown one bubble after another (typewriter) in the app,
    /// and joined into the shield subtitle on the lock screen.
    static func lines(for stage: Stage, bedtime: String) -> [String] {
        switch stage {
        case .none:
            return ["hi. it's not bedtime yet.", "go do something fun, I'll see you tonight."]
        case .sleepy:
            return ["it's \(bedtime)...",
                    "your phone screen is too bright, it's disturbing my sleep.",
                    "can you please turn it off? thanks..."]
        case .frustrated:
            return ["please, I'm trying to sleep.",
                    "you should too..."]
        case .fuming:
            return ["...you're still on it.",
                    "I'm not asking again. lights off. now."]
        case .asleep:
            return ["zzz...",
                    "(she finally fell asleep. don't wake her.)"]
        }
    }

    static func thankYou() -> [String] {
        ["thank you...", "goodnight."]
    }

    static func shieldTitle(for stage: Stage) -> String {
        switch stage {
        case .none: return "roommate"
        case .sleepy: return "roommate is awake 😴"
        case .frustrated: return "roommate, again 😒"
        case .fuming: return "roommate 💢"
        case .asleep: return "shh... she's asleep 💤"
        }
    }

    static func shieldSubtitle(for stage: Stage, bedtime: String) -> String {
        lines(for: stage, bedtime: bedtime).joined(separator: " ")
    }
}

// MARK: - One night in the log

struct NightRecord: Codable, Identifiable, Equatable {
    var date: Date               // the evening the night started
    var snoozes: Int             // times you hit "15 more minutes"
    var complied: Bool           // you tapped "okay, goodnight"
    var happinessAfter: Int
    var frustrationAfter: Int
    var id: Date { date }

    var summary: String {
        if snoozes == 0 && complied { return "you said goodnight right away ♡" }
        if snoozes == 0 { return "slept peacefully 🌙" }
        if snoozes == 1 { return "woke her up once 😒" }
        return "woke her up \(snoozes)× 💢"
    }
}

// MARK: - Shared state (App Group UserDefaults)

/// Everything the app and the extensions need to agree on lives here.
/// Values are plain integers/booleans so the extensions stay tiny.
final class MoodStore {
    static let shared = MoodStore()

    private let defaults: UserDefaults

    private enum Key {
        static let happiness = "happiness"
        static let frustration = "frustration"
        static let stage = "stage"
        static let snoozesTonight = "snoozesTonight"
        static let compliedTonight = "compliedTonight"
        static let nightStartedAt = "nightStartedAt"
        static let bedtimeHour = "bedtimeHour"
        static let bedtimeMinute = "bedtimeMinute"
        static let wakeHour = "wakeHour"
        static let wakeMinute = "wakeMinute"
        static let isEnabled = "isEnabled"
        static let shieldAllApps = "shieldAllApps"
        static let selection = "familyActivitySelection"
        static let history = "history"
        static let pendingVisitStage = "pendingVisitStage"
    }

    init(defaults: UserDefaults? = nil) {
        #if DEMO
        // No App Group on a free developer account – the demo has no extensions anyway.
        self.defaults = defaults ?? .standard
        #else
        self.defaults = defaults
            ?? UserDefaults(suiteName: RoommateConfig.appGroup)
            ?? .standard
        #endif
        self.defaults.register(defaults: [
            Key.happiness: 70,
            Key.frustration: 10,
            Key.bedtimeHour: 23,
            Key.bedtimeMinute: 0,
            Key.wakeHour: 7,
            Key.wakeMinute: 0,
        ])
    }

    // MARK: Mood

    var happiness: Int {
        get { defaults.integer(forKey: Key.happiness) }
        set { defaults.set(min(100, max(0, newValue)), forKey: Key.happiness) }
    }

    var frustration: Int {
        get { defaults.integer(forKey: Key.frustration) }
        set { defaults.set(min(100, max(0, newValue)), forKey: Key.frustration) }
    }

    var stage: Stage {
        get { Stage(rawValue: defaults.integer(forKey: Key.stage)) ?? .none }
        set { defaults.set(newValue.rawValue, forKey: Key.stage) }
    }

    var snoozesTonight: Int {
        get { defaults.integer(forKey: Key.snoozesTonight) }
        set { defaults.set(newValue, forKey: Key.snoozesTonight) }
    }

    var compliedTonight: Bool {
        get { defaults.bool(forKey: Key.compliedTonight) }
        set { defaults.set(newValue, forKey: Key.compliedTonight) }
    }

    var nightStartedAt: Date? {
        get { defaults.object(forKey: Key.nightStartedAt) as? Date }
        set { defaults.set(newValue, forKey: Key.nightStartedAt) }
    }

    /// The sitting pose for the home screen, chosen from her mood.
    var sittingPose: String {
        if frustration >= 50 { return "sit-annoyed" }
        if happiness >= 60 && frustration < 35 { return "sit-happy" }
        return "sit-neutral"
    }

    var moodCaption: String {
        if frustration >= 75 { return "she is really not talking to you right now 💢" }
        if frustration >= 50 { return "she's annoyed with you 💢" }
        if happiness >= 80 && frustration < 20 { return "she's very happy today ♡" }
        if happiness >= 60 && frustration < 35 { return "she's in a good mood ♡" }
        if happiness < 35 { return "she's a bit lonely..." }
        return "she's okay. a little tired."
    }

    // MARK: Schedule

    var bedtime: DateComponents {
        get { DateComponents(hour: defaults.integer(forKey: Key.bedtimeHour),
                             minute: defaults.integer(forKey: Key.bedtimeMinute)) }
        set {
            defaults.set(newValue.hour ?? 23, forKey: Key.bedtimeHour)
            defaults.set(newValue.minute ?? 0, forKey: Key.bedtimeMinute)
        }
    }

    var wakeTime: DateComponents {
        get { DateComponents(hour: defaults.integer(forKey: Key.wakeHour),
                             minute: defaults.integer(forKey: Key.wakeMinute)) }
        set {
            defaults.set(newValue.hour ?? 7, forKey: Key.wakeHour)
            defaults.set(newValue.minute ?? 0, forKey: Key.wakeMinute)
        }
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: Key.isEnabled) }
        set { defaults.set(newValue, forKey: Key.isEnabled) }
    }

    /// Shield every app at bedtime (instead of only the ones you picked).
    var shieldAllApps: Bool {
        get { defaults.bool(forKey: Key.shieldAllApps) }
        set { defaults.set(newValue, forKey: Key.shieldAllApps) }
    }

    var selection: FamilyActivitySelection {
        get {
            guard let data = defaults.data(forKey: Key.selection),
                  let sel = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
            else { return FamilyActivitySelection() }
            return sel
        }
        set {
            defaults.set(try? JSONEncoder().encode(newValue), forKey: Key.selection)
        }
    }

    var history: [NightRecord] {
        get {
            guard let data = defaults.data(forKey: Key.history),
                  let list = try? JSONDecoder().decode([NightRecord].self, from: data)
            else { return [] }
            return list
        }
        set {
            defaults.set(try? JSONEncoder().encode(Array(newValue.suffix(60))), forKey: Key.history)
        }
    }

    /// Set by a notification tap / deep link so the app opens straight into her visit.
    var pendingVisitStage: Stage? {
        get {
            let raw = defaults.integer(forKey: Key.pendingVisitStage)
            return raw == 0 ? nil : Stage(rawValue: raw)
        }
        set { defaults.set(newValue?.rawValue ?? 0, forKey: Key.pendingVisitStage) }
    }

    // MARK: Formatting

    var bedtimeString: String { Self.format(bedtime) }
    var wakeTimeString: String { Self.format(wakeTime) }

    static func format(_ c: DateComponents) -> String {
        var comps = DateComponents()
        comps.hour = c.hour ?? 0
        comps.minute = c.minute ?? 0
        let date = Calendar.current.date(from: comps) ?? Date()
        let f = DateFormatter()
        f.locale = .current
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: date).lowercased()
    }

    /// True if `date` falls inside tonight's bedtime → wake window.
    func isBedtime(at date: Date = Date()) -> Bool {
        let cal = Calendar.current
        let now = cal.dateComponents([.hour, .minute], from: date)
        let nowMin = (now.hour ?? 0) * 60 + (now.minute ?? 0)
        let startMin = (bedtime.hour ?? 23) * 60 + (bedtime.minute ?? 0)
        let endMin = (wakeTime.hour ?? 7) * 60 + (wakeTime.minute ?? 0)
        if startMin < endMin { return nowMin >= startMin && nowMin < endMin }
        return nowMin >= startMin || nowMin < endMin   // crosses midnight
    }

    // MARK: Night lifecycle (called from the extensions)

    /// Bedtime arrived. She wakes up and goes to find you.
    func nightStarted(at date: Date = Date()) {
        stage = .sleepy
        snoozesTonight = 0
        compliedTonight = false
        nightStartedAt = date
        pendingVisitStage = .sleepy
    }

    /// You tapped "okay, goodnight". She goes back to bed.
    func complied() {
        guard stage != .asleep else { return }
        compliedTonight = true
        if snoozesTonight == 0 { happiness += 10 }
        else { happiness += 3 }
        stage = .asleep
        pendingVisitStage = nil
    }

    /// You tapped "15 more minutes". She's not impressed.
    func snoozed() {
        snoozesTonight += 1
        frustration += 15
        happiness -= 5
        pendingVisitStage = nil
    }

    /// She came back after you kept using the phone.
    func escalate(to newStage: Stage) {
        stage = newStage
        frustration += newStage == .fuming ? 10 : 5
        pendingVisitStage = newStage
    }

    /// Morning. Tally the night.
    func nightEnded(at date: Date = Date()) {
        let started = nightStartedAt ?? date
        if snoozesTonight == 0 {
            happiness += compliedTonight ? 15 : 12
            frustration -= 25
        } else if snoozesTonight == 1 {
            frustration -= 5
        }
        var log = history
        if let last = log.last, Calendar.current.isDate(last.date, inSameDayAs: started) {
            log.removeLast()
        }
        log.append(NightRecord(date: started,
                               snoozes: snoozesTonight,
                               complied: compliedTonight,
                               happinessAfter: happiness,
                               frustrationAfter: frustration))
        history = log
        stage = .none
        snoozesTonight = 0
        compliedTonight = false
        nightStartedAt = nil
        pendingVisitStage = nil
    }

    func resetMood() {
        happiness = 70
        frustration = 10
        history = []
        stage = .none
        snoozesTonight = 0
        compliedTonight = false
        pendingVisitStage = nil
    }
}

// MARK: - Shielding (ManagedSettings)

enum Shielding {
    private static var store: ManagedSettingsStore {
        ManagedSettingsStore(named: RoommateConfig.storeName)
    }

    /// Put her in front of the apps. The Shield Configuration extension
    /// reads `MoodStore.shared.stage` to decide which pose and line to show.
    static func apply(using mood: MoodStore = .shared) {
        #if DEMO
        return   // demo build can't block apps
        #endif
        let s = store
        if mood.shieldAllApps {
            s.shield.applications = nil
            s.shield.webDomains = nil
            s.shield.applicationCategories = .all()
            s.shield.webDomainCategories = .all()
        } else {
            let sel = mood.selection
            s.shield.applications = sel.applicationTokens.isEmpty ? nil : sel.applicationTokens
            s.shield.webDomains = sel.webDomainTokens.isEmpty ? nil : sel.webDomainTokens
            s.shield.applicationCategories = sel.categoryTokens.isEmpty
                ? nil : .specific(sel.categoryTokens)
            s.shield.webDomainCategories = sel.categoryTokens.isEmpty
                ? nil : .specific(sel.categoryTokens)
        }
    }

    /// Let you back in.
    static func clear() {
        #if DEMO
        return
        #endif
        store.clearAllSettings()
    }
}

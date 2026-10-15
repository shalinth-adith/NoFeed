//
//  StartFocusIntent.swift
//  NoFeed (shared: app + NoFeedWidget)
//
//  Starts a focus session. Powers Siri/Spotlight/Shortcuts and the Control
//  Center button. Takes an optional profile; without one it uses whatever the
//  Focus tab has selected. Runs by opening the app, which consumes the handoff
//  and begins the session — starting needs the app's Screen Time context.
//

import AppIntents

struct StartFocusIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Focus Session"
    static var description = IntentDescription("Starts a NoFeed focus session with your active profile, or the one you choose.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Profile")
    var profile: FocusProfileEntity?

    init() {}

    init(profile: FocusProfileEntity?) {
        self.profile = profile
    }

    func perform() async throws -> some IntentResult {
        FocusLaunchRequest.request(profileID: profile?.id)
        return .result()
    }
}

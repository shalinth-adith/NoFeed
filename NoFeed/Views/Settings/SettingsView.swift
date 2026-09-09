//
//  SettingsView.swift
//  NoFeed
//
//  Screen Time permission status and daily break reminders (scheduled with a
//  UNCalendarNotificationTrigger). Preferences persist in the App Group.
//
//  Redesign: grouped glass settings over the aurora with the glowing toggle and
//  brand tint (Claude Design spec, NoFeed.dc.html). Controls and logic unchanged.
//  (The mockup's account / "NoFeed Plus" / sign-out card is intentionally omitted
//  — NoFeed has no user accounts.)
//

import SwiftUI

struct SettingsView: View {
    @Environment(AuthorizationService.self) private var authorization
    @Environment(ProfileStore.self) private var profiles
    @Environment(AnalyticsService.self) private var analytics
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The name shown in the Focus greeting ("Good evening, <name>"). Empty by
    /// default → a plain greeting; the user types their own name here.
    @AppStorage("userDisplayName", store: AppGroup.defaults) private var userName = ""

    @AppStorage("dailyGoalMinutes", store: AppGroup.defaults) private var dailyGoalMinutes = 120
    @AppStorage("dailySessionsGoal", store: AppGroup.defaults) private var dailySessionsGoal = 3
    @AppStorage("streakGoal", store: AppGroup.defaults) private var streakGoal = 7
    @AppStorage(ShieldMessage.storageKey, store: AppGroup.defaults) private var shieldMessage = ""
    @AppStorage("breakReminderEnabled", store: AppGroup.defaults) private var reminderEnabled = false
    @AppStorage("breakReminderHour", store: AppGroup.defaults) private var reminderHour = 15
    @AppStorage("breakReminderMinute", store: AppGroup.defaults) private var reminderMinute = 0
    /// Defaults to **true**, unlike the break reminder above. The recap is a
    /// once-a-week summary rather than a nudge, and it is suppressed entirely on
    /// a week with nothing in it — so an unused install is never notified by it.
    /// The default here and the `?? true` in `NoFeedApp.rescheduleWeeklyRecap`
    /// must agree; a mismatch ships the feature silently off.
    @AppStorage("weeklyRecapEnabled", store: AppGroup.defaults) private var recapEnabled = true
    @AppStorage("weeklyRecapHour", store: AppGroup.defaults) private var recapHour = 18
    @AppStorage("weeklyRecapMinute", store: AppGroup.defaults) private var recapMinute = 0
    /// Minutes a block-screen pass lasts; 0 = off, which is the default. Keys
    /// must match `UnlockWindow` exactly — the shield extensions read this same
    /// App Group value and have no other way to learn the setting.
    @AppStorage("unlockWindowMinutes", store: AppGroup.defaults) private var unlockMinutes = 0

    /// A source the user picked but hasn't confirmed switching to yet.
    @State private var showProfiles = false

    /// Drives the keyboard's Done button for the multiline shield-message field.
    @FocusState private var shieldFieldFocused: Bool

    /// Frosted row background that lets the section's rounded corners clip it.
    private var glassRow: some View {
        Rectangle()
            .fill(ZTheme.Palette.matte)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NoFeedBackground()

                Form {
                    youSection
                    permissionSection
                    goalSection
                    shieldSection
                    breakReminderSection
                    unlockSection
                    weeklyRecapSection
                    aboutSection
                }
                .scrollContentBackground(.hidden)
                .tint(ZTheme.Palette.textPrimary)
                // Drag the form downward to dismiss. Independent of any toolbar,
                // so it works even where the keyboard accessory does not render.
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Settings")
            .toolbarBackground(.hidden, for: .navigationBar)
            // The shield-message field uses `axis: .vertical`, where Return
            // inserts a newline instead of submitting — so the keyboard needs an
            // explicit way out. Three independent paths, because a keyboard
            // accessory attached to a subview inside the ZStack does not
            // reliably render:
            //   1. this Done item, now hung off the NavigationStack's content root
            //   2. interactive scroll-to-dismiss (above)
            //   3. tapping the Done row in the section footer (see shieldSection)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { shieldFieldFocused = false }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showProfiles) { ProfilesView() }
            .onChange(of: reminderEnabled) { _, _ in updateReminder() }
            .onChange(of: reminderHour) { _, _ in updateReminder() }
            .onChange(of: reminderMinute) { _, _ in updateReminder() }
        }
    }

    /// Label + text field. Side-by-side normally; stacked at accessibility text
    /// sizes, where an `HStack` leaves neither child enough width and the field
    /// draws on top of the wrapped label.
    private var nameRow: some View {
        let field = TextField("Add your name", text: $userName)
            .foregroundStyle(ZTheme.Palette.text(0.7))
            .submitLabel(.done)

        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your name")
                    field.multilineTextAlignment(.leading)
                }
                .padding(.vertical, 2)
            } else {
                HStack {
                    Text("Your name")
                    Spacer()
                    field.multilineTextAlignment(.trailing)
                }
            }
        }
    }

    private var youSection: some View {
        Section("You") {
            nameRow
            Button {
                showProfiles = true
            } label: {
                HStack {
                    Text("Focus profiles")
                        .foregroundStyle(ZTheme.Palette.textPrimary)
                    Spacer()
                    Text("\(profiles.profiles.count)")
                        .foregroundStyle(ZTheme.Palette.text(0.5))
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(ZTheme.Palette.text(0.3))
                }
            }
        }
    }

    private var permissionSection: some View {
        Section("Screen Time") {
            switch authorization.status {
            case .approved:
                // Neutral Quiet chrome: the checkmark shape still reads as
                // "granted"; no standout green competing with the flat palette.
                Label("Access granted", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(ZTheme.Palette.textPrimary)
            default:
                Button("Grant Screen Time Access") {
                    Task { await authorization.requestAuthorization() }
                }
            }
        }
        .listRowBackground(glassRow)
    }

    private var shieldSection: some View {
        Section {
            // `axis: .vertical` makes Return insert a newline instead of
            // submitting, so this field needs an explicit way out of the
            // keyboard — otherwise it can be opened and never dismissed.
            TextField("e.g. Future you will thank you.",
                      text: $shieldMessage, axis: .vertical)
                .lineLimit(1...3)
                .focused($shieldFieldFocused)

            // Always-rendered escape hatch. The keyboard accessory can fail to
            // appear depending on how SwiftUI resolves the toolbar; an ordinary
            // row in the section cannot.
            if shieldFieldFocused {
                Button {
                    shieldFieldFocused = false
                } label: {
                    HStack {
                        Spacer()
                        Text("Done")
                            .font(ZTheme.Font.body(15, weight: .semibold))
                            .foregroundStyle(ZTheme.Palette.brandBright)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Done editing shield message")
            }
        } header: {
            Text("Shield message")
        } footer: {
            Text("Shown on the block screen when you open a distracting app during focus. Leave empty for the default.")
        }
        .listRowBackground(glassRow)
    }

    private var goalSection: some View {
        Section {
            Stepper(value: $dailyGoalMinutes, in: 30...480, step: 30) {
                LabeledContent("Daily focus goal", value: "\(dailyGoalMinutes) min")
            }
            Stepper(value: $dailySessionsGoal, in: 1...12, step: 1) {
                LabeledContent("Daily sessions goal", value: "\(dailySessionsGoal)")
            }
            Stepper(value: $streakGoal, in: 3...60, step: 1) {
                LabeledContent("Streak goal", value: "\(streakGoal) days")
            }
        } header: {
            Text("Daily Goals")
        } footer: {
            Text("Your daily targets, shown as progress orbs on Insights.")
        }
        .listRowBackground(glassRow)
    }

    private var breakReminderSection: some View {
        Section {
            Toggle("Daily break reminder", isOn: $reminderEnabled)
                .toggleStyle(.noFeed)
            if reminderEnabled {
                DatePicker("Remind me at", selection: reminderTime, displayedComponents: .hourAndMinute)
            }
        } header: {
            Text("Break Reminders")
        } footer: {
            Text("A gentle daily nudge to step away and recharge.")
        }
        .listRowBackground(glassRow)
    }

    private var unlockSection: some View {
        Section {
            Picker("Unlock window", selection: $unlockMinutes) {
                Text("Off").tag(0)
                ForEach(UnlockWindow.choices.filter { $0 > 0 }, id: \.self) { minutes in
                    Text("\(minutes) minutes").tag(minutes)
                }
            }
            .accessibilityIdentifier("settings-unlock-window")
        } header: {
            Text("Unlock Window")
        } footer: {
            // Says why fifteen is the floor, because "why can't I pick 2 minutes"
            // is the first question this setting raises and the answer is a real
            // constraint rather than a preference. Also says it lifts everything,
            // since a pass that only looked like it covered one app would be the
            // more dangerous misunderstanding.
            Text("Adds a second button to the block screen that lifts every block for a while, then puts them back. Fifteen minutes is the shortest window iOS can reliably close on its own. Never offered during a strict session.")
        }
        .listRowBackground(glassRow)
        .onChange(of: unlockMinutes) { _, new in
            // Ending a pass that is already running when the setting is turned
            // off — otherwise switching it off would leave the phone unshielded
            // for the rest of a window nobody can see any more.
            if new == 0 { UnlockWindow.clear() }
        }
    }

    private var weeklyRecapSection: some View {
        Section {
            Toggle("Weekly recap", isOn: $recapEnabled)
                .toggleStyle(.noFeed)
                .accessibilityIdentifier("settings-weekly-recap")
            if recapEnabled {
                DatePicker("Send it at", selection: recapTime, displayedComponents: .hourAndMinute)
            }
        } header: {
            Text("Weekly Recap")
        } footer: {
            // Says the day out loud because it is derived from the locale rather
            // than fixed — Sunday for most readers, Saturday where the week
            // starts on Sunday — and a setting that will not say when it fires
            // is a setting people turn off.
            Text("A summary of your week on \(lastDayOfWeekName) — hours focused, and how many times you reached for a blocked app and stopped. Skipped on weeks with no sessions.")
        }
        .listRowBackground(glassRow)
        .onChange(of: recapEnabled) { _, _ in updateRecap() }
        .onChange(of: recapHour) { _, _ in updateRecap() }
        .onChange(of: recapMinute) { _, _ in updateRecap() }
    }

    private var recapTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: recapHour, minute: recapMinute,
                                      second: 0, of: Date()) ?? Date()
            },
            set: { newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                recapHour = comps.hour ?? 18
                recapMinute = comps.minute ?? 0
            }
        )
    }

    /// The name of the last day of the reader's week, matching the day
    /// `NotificationService.nextWeekEnd` will actually pick.
    private var lastDayOfWeekName: String {
        let calendar = Calendar.current
        let index = calendar.firstWeekday == 1 ? 7 : calendar.firstWeekday - 1
        let symbols = calendar.weekdaySymbols          // [Sunday ... Saturday]
        return symbols.indices.contains(index - 1) ? symbols[index - 1] : "Sunday"
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: appVersion)
            LabeledContent("Phase", value: "2 — Sessions & Scheduling")
        }
        .listRowBackground(glassRow)
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: reminderHour, minute: reminderMinute,
                                      second: 0, of: Date()) ?? Date()
            },
            set: { newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                reminderHour = comps.hour ?? 15
                reminderMinute = comps.minute ?? 0
            }
        )
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private func updateReminder() {
        if reminderEnabled {
            NotificationService.shared.scheduleDailyReminder(
                hour: reminderHour, minute: reminderMinute,
                focusedToday: SessionHistory().todayFocusMinutes() > 0)
        } else {
            NotificationService.shared.cancelDailyBreakReminder()
        }
    }

    /// Re-arm the recap after a settings change rather than waiting for the next
    /// foreground. The decision itself lives in `AnalyticsService.armWeeklyRecap`,
    /// which reads these same keys — duplicating it here is how the toggle and
    /// the app end up disagreeing about whether the recap is on.
    private func updateRecap() {
        analytics.armWeeklyRecap()
    }
}

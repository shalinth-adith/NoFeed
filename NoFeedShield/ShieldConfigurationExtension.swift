//
//  ShieldConfigurationExtension.swift
//  NoFeedShield
//
//  Supplies the calm custom shield shown over a blocked app/website. iOS calls
//  the relevant overload depending on whether the block came from an app, a
//  website, or a category. We personalize with the subject's name when available.
//
//  Every overload draws the same screen. See `ShieldTheme` for what the second
//  button offers, and `MindfulPause` for the wait it can walk through.
//

import ManagedSettings
import ManagedSettingsUI

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        record(application.localizedDisplayName)
        return ShieldTheme.configuration(subject: application.localizedDisplayName)
    }

    /// The overload that runs under "Block everything", which shields by
    /// category — the default on all four shipped profiles.
    override func configuration(shielding application: Application,
                                in category: ActivityCategory) -> ShieldConfiguration {
        record(application.localizedDisplayName)
        return ShieldTheme.configuration(subject: application.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        record(webDomain.domain)
        return ShieldTheme.configuration(subject: webDomain.domain)
    }

    override func configuration(shielding webDomain: WebDomain,
                                in category: ActivityCategory) -> ShieldConfiguration {
        record(webDomain.domain)
        return ShieldTheme.configuration(subject: webDomain.domain)
    }

    /// Count the reach — unless this draw is the shield refreshing itself during
    /// a mindful pause. Each tap there answers `.defer`, iOS asks for a new
    /// screen, and counting each of those would turn one reach into several on
    /// Insights and in the weekly recap.
    private func record(_ name: String?) {
        guard !ShieldDoor.current().isMidPause else { return }
        DistractionLog.recordAttempt()
        PausedApp.record(name: name)
    }
}

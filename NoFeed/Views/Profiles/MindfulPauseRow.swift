//
//  MindfulPauseRow.swift
//  NoFeed
//
//  The profile editors' "Pause, don't block" switch, sitting under strict mode.
//
//  The two are opposites, so turning one on turns the other off rather than
//  leaving a combination that cannot be honoured: strict promises no way out,
//  and a pause is a way out. The data layer enforces the same rule
//  (`ActivityShieldStore` never records a strict enforcer as mindful); this
//  just makes the screen say what will actually happen.
//

import SwiftUI

struct MindfulPauseRow: View {
    @Binding var isMindful: Bool
    @Binding var isStrict: Bool
    var tone: Color

    var body: some View {
        // Its own heading: under "Strict mode" it read as a kind of strict,
        // which is the opposite of what it is.
        QuietFieldLabel(text: "Block screen", topPadding: QuietMetrics.sectionGap)
            .padding(.bottom, 2)
        QuietToggleRow(title: "Pause, don\u{2019}t block",
                       subtitle: "The block screen waits ten seconds, then lets you in",
                       isOn: Binding(get: { isMindful && !isStrict },
                                     set: { on in
                                         isMindful = on
                                         if on { isStrict = false }
                                     }),
                       tone: tone)
            .accessibilityIdentifier("profile-mindful-pause")
            .onChange(of: isStrict) { _, strict in
                if strict { isMindful = false }
            }
    }
}

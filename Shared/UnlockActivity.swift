//
//  UnlockActivity.swift
//  NoFeed (shared: app + NoFeedShieldAction + NoFeedMonitor)
//
//  The DeviceActivity name for an unlock window, split out of
//  `ShieldActionExtension` so both ends of the handshake can refer to the same
//  constant: the shield-action extension *registers* the interval, and the
//  monitor extension recognises it at `intervalDidEnd` to close the window.
//
//  Kept out of `UnlockWindow.swift` on purpose. That file is compiled into
//  `NoFeedShield` too, which only needs to read the setting and does not link
//  DeviceActivity — an `import DeviceActivity` there would drag a framework into
//  an extension that has no use for it.
//

import DeviceActivity

extension DeviceActivityName {
    /// The interval whose *end* puts the shields back. Nothing is enforced while
    /// it runs — it exists purely so the system wakes `NoFeedMonitor` on time.
    static let unlockWindow = Self("nofeed.unlock.window")
}

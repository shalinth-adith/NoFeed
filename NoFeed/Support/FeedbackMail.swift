//
//  FeedbackMail.swift
//  NoFeed
//
//  Builds the `mailto:` link behind Settings › Send feedback. The body carries
//  the three facts every bug report needs and nobody remembers to include: app
//  version and build, iOS version, and the device model identifier.
//
//  The URL assembly is a pure function so it can be tested without UIKit; the
//  one UIKit-dependent part (`current()`) only gathers the values.
//

import Foundation
import UIKit

enum FeedbackMail {
    /// The support address published on the site and in the privacy policy.
    static let address = "shalinth.adith@outlook.com"

    /// Builds `mailto:<to>?subject=…&body=…`. `URLComponents.queryItems` leaves
    /// `+`, `&` and newlines alone, which a mail client then misreads, so the
    /// values are percent-encoded by hand against the unreserved set.
    static func url(to: String = address,
                    version: String,
                    build: String,
                    system: String,
                    device: String) -> URL? {
        let subject = "NoFeed feedback"
        let body = "\n\n—\nNoFeed \(version) (\(build))\niOS \(system)\n\(device)"

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = to
        components.percentEncodedQueryItems = [
            URLQueryItem(name: "subject", value: encode(subject)),
            URLQueryItem(name: "body", value: encode(body))
        ]
        return components.url
    }

    /// The link for this install, read from the bundle and the device.
    static func current() -> URL? {
        let info = Bundle.main.infoDictionary
        return url(version: info?["CFBundleShortVersionString"] as? String ?? "?",
                   build: info?["CFBundleVersion"] as? String ?? "?",
                   system: UIDevice.current.systemVersion,
                   device: modelIdentifier())
    }

    /// "iPhone16,2" rather than "iPhone": the identifier is what distinguishes
    /// the models that behave differently.
    static func modelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result.append(Character(UnicodeScalar(UInt8(value))))
        }
        return identifier.isEmpty ? UIDevice.current.model : identifier
    }

    private static let unreserved = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))

    private static func encode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
    }
}

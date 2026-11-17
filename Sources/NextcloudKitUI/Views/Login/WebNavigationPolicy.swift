// SPDX-FileCopyrightText: 2026 Krateos B.V.
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

///
/// Decides which top-level pages a ``WebView`` may navigate to.
///
/// Branded apps use this to keep the in-app browser on a known set of pages, for example
/// so that a privacy statement cannot be used to reach the rest of a website.
///
/// Only main frame navigations are checked. Subframes (such as a CAPTCHA widget) load freely,
/// but anything they try to open in the main frame or in a new window is checked or blocked.
///
public struct WebNavigationPolicy: Sendable, Equatable {
    enum Rule: Sendable, Equatable {
        case unrestricted
        case singlePage(host: String, path: String)
        case hosts(Set<String>, blockedPathFragments: [String])
    }

    let rule: Rule

    ///
    /// Every navigation is allowed. This is the default and matches the behaviour before policies existed.
    ///
    public static let unrestricted = WebNavigationPolicy(rule: .unrestricted)

    ///
    /// Only the page at `url` may be shown: same host and path over HTTPS. Query and fragment are ignored,
    /// so anchors within the page still work. Every other link is blocked.
    ///
    public static func singlePage(_ url: URL) -> WebNavigationPolicy {
        WebNavigationPolicy(rule: .singlePage(host: (url.host ?? "").lowercased(), path: normalized(path: url.path)))
    }

    ///
    /// Only HTTPS pages on the given hosts may be shown, except paths that contain any of `blockedPathFragments` (case insensitive).
    ///
    public static func hosts(_ hosts: Set<String>, blockingPathsContaining blockedPathFragments: [String] = []) -> WebNavigationPolicy {
        WebNavigationPolicy(rule: .hosts(Set(hosts.map { $0.lowercased() }), blockedPathFragments: blockedPathFragments.map { $0.lowercased() }))
    }

    ///
    /// Whether this policy restricts navigation at all.
    ///
    public var isRestricted: Bool {
        rule != .unrestricted
    }

    ///
    /// Whether a main frame navigation to `url` is allowed.
    ///
    public func allows(_ url: URL) -> Bool {
        switch rule {
        case .unrestricted:
            return true
        case let .singlePage(host, path):
            guard url.scheme?.lowercased() == "https", let urlHost = url.host?.lowercased() else {
                return false
            }

            return urlHost == host && Self.normalized(path: url.path) == path
        case let .hosts(hosts, blockedPathFragments):
            guard url.scheme?.lowercased() == "https", let urlHost = url.host?.lowercased(), hosts.contains(urlHost) else {
                return false
            }

            let urlPath = url.path.lowercased()
            return blockedPathFragments.allSatisfy { urlPath.contains($0) == false }
        }
    }

    private static func normalized(path: String) -> String {
        var path = path

        while path.count > 1, path.hasSuffix("/") {
            path.removeLast()
        }

        return path.isEmpty ? "/" : path
    }
}

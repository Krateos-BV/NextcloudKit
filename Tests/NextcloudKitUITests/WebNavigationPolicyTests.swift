// SPDX-FileCopyrightText: 2026 Krateos B.V.
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
@testable import NextcloudKitUI
import Testing

///
/// Tests for ``WebNavigationPolicy`` and the ``WebView/Coordinator`` that enforces it.
///
struct WebNavigationPolicyTests {
    // swiftlint:disable force_unwrapping
    let privacy = URL(string: "https://example.com/privacy-statement/")!
    // swiftlint:enable force_unwrapping

    private func url(_ string: String) throws -> URL {
        try #require(URL(string: string))
    }

    // MARK: - Unrestricted

    @Test func unrestrictedAllowsEverything() async throws {
        #expect(WebNavigationPolicy.unrestricted.isRestricted == false)
        let target = try url("http://anything.example/pricing")
        #expect(WebNavigationPolicy.unrestricted.allows(target))
    }

    // MARK: - Single page

    @Test(arguments: [
        "https://example.com/privacy-statement/",
        "https://example.com/privacy-statement",
        "https://EXAMPLE.com/privacy-statement/#cookies",
        "https://example.com/privacy-statement/?lang=nl"
    ]) func singlePageAllowsItself(_ string: String) async throws {
        let target = try url(string)
        #expect(WebNavigationPolicy.singlePage(privacy).allows(target))
    }

    @Test(arguments: [
        "https://example.com/",
        "https://example.com/#personal-pricing",
        "https://example.com/pricing-en/",
        "https://example.com/privacy-statement/more/",
        "https://auth.example.com/if/flow/enrollment/",
        "http://example.com/privacy-statement/",
        "https://other.example/privacy-statement/"
    ]) func singlePageBlocksEverythingElse(_ string: String) async throws {
        let target = try url(string)
        #expect(WebNavigationPolicy.singlePage(privacy).allows(target) == false)
    }

    // MARK: - Hosts

    @Test(arguments: [
        "https://portal.example.com/index.php/login/v2/flow/abc",
        "https://auth.example.com/application/o/authorize/?client_id=x",
        "https://AUTH.example.com/if/flow/default-authentication-flow/"
    ]) func hostsAllowsListedHosts(_ string: String) async throws {
        let policy = WebNavigationPolicy.hosts(["portal.example.com", "Auth.Example.com"], blockingPathsContaining: ["enrollment"])
        let target = try url(string)
        #expect(policy.allows(target))
    }

    @Test(arguments: [
        "https://example.com/pricing-en/",
        "https://auth.example.com/if/flow/xenia-Enrollment/",
        "http://portal.example.com/login",
        "https://portal.example.com.evil.example/login"
    ]) func hostsBlocksOthers(_ string: String) async throws {
        let policy = WebNavigationPolicy.hosts(["portal.example.com", "auth.example.com"], blockingPathsContaining: ["enrollment"])
        let target = try url(string)
        #expect(policy.allows(target) == false)
    }

    // MARK: - Coordinator

    @MainActor @Test func coordinatorImplementsDelegateSelector() async throws {
        let coordinator = WebView.Coordinator(navigationPolicy: .singlePage(privacy))
        #expect(coordinator.responds(to: NSSelectorFromString("webView:decidePolicyForNavigationAction:decisionHandler:")))
    }

    @MainActor @Test func coordinatorUnrestrictedAllowsNewWindows() async throws {
        let coordinator = WebView.Coordinator(navigationPolicy: .unrestricted)
        let target = try url("https://example.com/pricing")
        #expect(coordinator.shouldAllow(target, isMainFrame: nil))
    }

    @MainActor @Test func coordinatorRestrictedFramesAndWindows() async throws {
        let coordinator = WebView.Coordinator(navigationPolicy: .singlePage(privacy))
        let pricing = try url("https://example.com/pricing-en/")

        #expect(coordinator.shouldAllow(privacy, isMainFrame: true))
        #expect(coordinator.shouldAllow(pricing, isMainFrame: true) == false)
        #expect(coordinator.shouldAllow(pricing, isMainFrame: nil) == false)
        let widget = try url("https://challenges.example/widget")
        #expect(coordinator.shouldAllow(widget, isMainFrame: false))
        #expect(coordinator.shouldAllow(nil, isMainFrame: true) == false)
    }
}

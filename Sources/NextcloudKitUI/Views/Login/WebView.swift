// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import WebKit

///
/// A generic web view which makes `WKWebView` available in SwiftUI which otherwise is not.
///
/// This is the base block for presentation of web-based content.
/// Be it a live website in form of a login process or just a static HTML document about legal matters shipped with the app bundle.
///
/// The web view is inspectable by Safari on connected developer machines for eased debugging.
///
/// All of the web view session data is not persistent.
///
/// An optional ``WebNavigationPolicy`` restricts which pages can be reached from the initial URL.
///
public struct WebView: ViewRepresentable {
    ///
    /// This must be a binding to support presentation inside sheets.
    /// The way this view gets created and updated inside a sheet has a race condition with sheet presentation.
    /// A sheet might be displayed before a passed in state variable might have been set.
    ///
    @Binding var initialURL: URL?

    let userAgent: String?

    let navigationPolicy: WebNavigationPolicy

    public init(initialURL: Binding<URL?>, userAgent: String? = nil, navigationPolicy: WebNavigationPolicy = .unrestricted) {
        self._initialURL = initialURL
        self.userAgent = userAgent
        self.navigationPolicy = navigationPolicy
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(navigationPolicy: navigationPolicy)
    }

    func makeView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()

        let webView = WKWebView(frame: CGRect.zero, configuration: configuration)
        webView.isInspectable = true

        if let userAgent {
            webView.customUserAgent = userAgent
        }

        webView.navigationDelegate = context.coordinator

        return webView
    }

    func updateView(_ webView: WKWebView, context: Context) {
        context.coordinator.navigationPolicy = navigationPolicy

        guard let initialURL = initialURL else {
            return
        }

        let request = URLRequest(url: initialURL)
        webView.load(request)
    }

    // MARK: - macOS

    #if os(macOS)

    public func makeNSView(context: Context) -> WKWebView {
        makeView(context: context)
    }

    public func updateNSView(_ webView: WKWebView, context: Context) {
        updateView(webView, context: context)
    }

    // MARK: - iOS

    #else

    public func makeUIView(context: Context) -> WKWebView {
        makeView(context: context)
    }

    public func updateUIView(_ webView: WKWebView, context: Context) {
        updateView(webView, context: context)
    }

    #endif

    // MARK: - Navigation policy

    ///
    /// Enforces the ``WebNavigationPolicy`` of the web view.
    ///
    @MainActor
    public final class Coordinator: NSObject, WKNavigationDelegate {
        var navigationPolicy: WebNavigationPolicy

        init(navigationPolicy: WebNavigationPolicy) {
            self.navigationPolicy = navigationPolicy
        }

        ///
        /// The decision without WebKit types, so it can be tested.
        ///
        /// - Parameters:
        ///     - url: The navigation target.
        ///     - isMainFrame: `true` for the main frame, `false` for a subframe, `nil` when the target is a new window.
        ///
        func shouldAllow(_ url: URL?, isMainFrame: Bool?) -> Bool {
            guard navigationPolicy.isRestricted else {
                return true
            }

            switch isMainFrame {
            case .none:
                // New windows (target="_blank", window.open) would leave the policy behind.
                return false
            case .some(false):
                return true
            case .some(true):
                guard let url else {
                    return false
                }

                return navigationPolicy.allows(url)
            }
        }

        @objc(webView:decidePolicyForNavigationAction:decisionHandler:)
        public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
            let allowed = shouldAllow(navigationAction.request.url, isMainFrame: navigationAction.targetFrame?.isMainFrame)
            decisionHandler(allowed ? .allow : .cancel)
        }
    }
}

#Preview {
    // swiftlint:disable force_unwrapping
    WebView(initialURL: .constant(URL(string: "http://localhost:8080")!), userAgent: nil)
}

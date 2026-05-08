//
//  OverlayVideoPlayers.swift
//  leanring-buddy
//
//  SwiftUI/AppKit bridges for onboarding and tutorial video playback.
//

import AVFoundation
import SwiftUI
import WebKit

// MARK: - Onboarding Video Player

/// NSViewRepresentable wrapping an AVPlayerLayer so HLS video plays
/// inside SwiftUI. Uses a custom NSView subclass to keep the player
/// layer sized to the view's bounds automatically.
struct OnboardingVideoPlayerView: NSViewRepresentable {
    let player: AVPlayer?

    func makeNSView(context: Context) -> AVPlayerNSView {
        let view = AVPlayerNSView()
        view.player = player
        return view
    }

    func updateNSView(_ nsView: AVPlayerNSView, context: Context) {
        nsView.player = player
    }
}

struct TutorialInlineYouTubePlayerView: NSViewRepresentable {
    let embedURL: String
    let isPlaying: Bool
    let commandNonce: Int
    let lastCommand: TutorialPlaybackCommand?
    let startAtSeconds: Int?

    func makeNSView(context: Context) -> TutorialInlineWebPlayerContainerView {
        let view = TutorialInlineWebPlayerContainerView()
        view.loadEmbedURL(embedURL, startAtSeconds: startAtSeconds, autoplay: isPlaying)
        return view
    }

    func updateNSView(_ nsView: TutorialInlineWebPlayerContainerView, context: Context) {
        nsView.loadEmbedURL(embedURL, startAtSeconds: startAtSeconds, autoplay: isPlaying)

        guard context.coordinator.lastCommandNonce != commandNonce else { return }
        context.coordinator.lastCommandNonce = commandNonce

        if let lastCommand {
            nsView.apply(command: lastCommand)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var lastCommandNonce: Int = -1
    }
}

class AVPlayerNSView: NSView {
    var player: AVPlayer? {
        didSet { playerLayer.player = player }
    }

    private let playerLayer = AVPlayerLayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        playerLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }
}

final class TutorialInlineWebPlayerContainerView: NSView {
    private static let localEmbedOrigin = "https://clickyhq.com"
    private let webView: WKWebView
    private var loadedEmbedURL: String?

    override init(frame frameRect: NSRect) {
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(frame: frameRect)
        wantsLayer = true
        webView.setValue(false, forKey: "drawsBackground")
        addSubview(webView)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func layout() {
        super.layout()
        webView.frame = bounds
    }

    func loadEmbedURL(_ embedURLString: String, startAtSeconds: Int?, autoplay: Bool) {
        let normalizedURL = normalizedEmbedURLString(
            embedURLString,
            startAtSeconds: startAtSeconds,
            autoplay: false
        )
        guard loadedEmbedURL != normalizedURL else { return }
        loadedEmbedURL = normalizedURL

        let html = """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            html, body {
              margin: 0;
              padding: 0;
              background: transparent;
              overflow: hidden;
              width: 100%;
              height: 100%;
            }
            iframe {
              width: 100%;
              height: 100%;
              border: 0;
            }
          </style>
          <script src="https://www.youtube.com/iframe_api"></script>
        </head>
        <body>
          <iframe
            id="clicky-tutorial-player"
            src="\(normalizedURL)"
            allow="autoplay; encrypted-media; picture-in-picture"
            allowfullscreen>
          </iframe>
          <script>
            window.clickyPlayer = null;
            window.clickyPlayerReady = false;
            window.onYouTubeIframeAPIReady = function() {
              window.clickyPlayer = new YT.Player('clicky-tutorial-player', {
                events: {
                  onReady: function() {
                    window.clickyPlayerReady = true;
                    if (\(autoplay ? "true" : "false")) {
                      window.clickyPlayer.playVideo();
                    }
                  }
                }
              });
            };
          </script>
        </body>
        </html>
        """

        webView.loadHTMLString(html, baseURL: URL(string: Self.localEmbedOrigin))
    }

    func apply(command: TutorialPlaybackCommand) {
        let script: String
        switch command {
        case .play:
            script = postMessageScript(functionName: "playVideo")
        case .pause:
            script = postMessageScript(functionName: "pauseVideo")
        case .togglePlayPause:
            script = """
            if (window.clickyPlayerReady && window.clickyPlayer) {
              const state = window.clickyPlayer.getPlayerState ? window.clickyPlayer.getPlayerState() : -1;
              if (state === 1) {
                window.clickyPlayer.pauseVideo();
              } else {
                window.clickyPlayer.playVideo();
              }
            } else {
              const iframe = document.getElementById('clicky-tutorial-player');
              iframe?.contentWindow?.postMessage('{"event":"command","func":"playVideo","args":""}', '*');
            }
            """
        case .seekBackward:
            script = """
            if (window.clickyPlayerReady && window.clickyPlayer) {
              const currentTime = window.clickyPlayer.getCurrentTime ? window.clickyPlayer.getCurrentTime() : 0;
              window.clickyPlayer.seekTo(Math.max(0, currentTime - 10), true);
            }
            """
        case .seekForward:
            script = """
            if (window.clickyPlayerReady && window.clickyPlayer) {
              const currentTime = window.clickyPlayer.getCurrentTime ? window.clickyPlayer.getCurrentTime() : 0;
              window.clickyPlayer.seekTo(currentTime + 10, true);
            }
            """
        case .dismiss:
            script = postMessageScript(functionName: "pauseVideo")
        }

        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    private func normalizedEmbedURLString(
        _ embedURLString: String,
        startAtSeconds: Int?,
        autoplay: Bool
    ) -> String {
        guard var components = URLComponents(string: embedURLString) else {
            return embedURLString
        }

        var queryItems = components.queryItems ?? []
        queryItems.removeAll { item in
            ["enablejsapi", "playsinline", "autoplay", "start", "controls", "rel", "modestbranding", "origin"].contains(item.name)
        }
        queryItems.append(URLQueryItem(name: "enablejsapi", value: "1"))
        queryItems.append(URLQueryItem(name: "playsinline", value: "1"))
        queryItems.append(URLQueryItem(name: "controls", value: "1"))
        queryItems.append(URLQueryItem(name: "rel", value: "0"))
        queryItems.append(URLQueryItem(name: "modestbranding", value: "1"))
        queryItems.append(URLQueryItem(name: "origin", value: Self.localEmbedOrigin))
        if let startAtSeconds {
            queryItems.append(URLQueryItem(name: "start", value: String(startAtSeconds)))
        }
        components.queryItems = queryItems
        return components.string ?? embedURLString
    }

    private func postMessageScript(functionName: String) -> String {
        """
        if (window.clickyPlayerReady && window.clickyPlayer && window.clickyPlayer.\(functionName)) {
          window.clickyPlayer.\(functionName)();
        } else {
          const iframe = document.getElementById('clicky-tutorial-player');
          iframe?.contentWindow?.postMessage('{"event":"command","func":"\(functionName)","args":""}', '*');
        }
        """
    }
}

//
//  CompanionStudioChrome.swift
//  leanring-buddy
//
//  Shared shell chrome for the Studio window.
//

import AppKit
import SwiftUI

struct CompanionStudioWindowHeader: View {
    let palette: CompanionStudioScalaPalette
    let sections: [CompanionStudioNextSection]
    @Binding var selection: CompanionStudioNextSection
    var showsSectionTabs: Bool = true

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("clicky")
                    .font(ClickyTypography.brand(size: 34))
                    .foregroundColor(palette.brandWordmark)

                Text("Studio")
                    .font(ClickyTypography.mono(size: 11, weight: .semibold))
                    .foregroundColor(palette.shellSecondaryText)
                    .tracking(1.0)
            }

            Spacer(minLength: 0)

            if showsSectionTabs {
                topTabs
            }
        }
    }

    @ViewBuilder
    private var topTabs: some View {
        Group {
            if #available(macOS 26.0, *) {
                GlassEffectContainer(spacing: 12) {
                    tabButtons
                }
            } else {
                tabButtons
            }
        }
    }

    private var tabButtons: some View {
        HStack(spacing: 14) {
            ForEach(sections) { section in
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        selection = section
                    }
                } label: {
                    Image(systemName: section.systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .help(section.title)
                .accessibilityLabel(section.title)
                .modifier(CompanionStudioToolbarIconButtonModifier(isSelected: selection == section))
            }
        }
    }
}

struct CompanionStudioSceneShell<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            content
                .frame(maxWidth: 920, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
    }
}

struct CompanionStudioNextBackdrop: View {
    let palette: CompanionStudioScalaPalette

    var body: some View {
        Group {
            if #available(macOS 26.0, *) {
                Color.clear
            } else {
                LinearGradient(
                    colors: [
                        palette.shellBackgroundTop.opacity(0.92),
                        palette.shellBackgroundMid.opacity(0.90),
                        palette.shellBackgroundBottom.opacity(0.88)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .ignoresSafeArea()
    }
}

struct CompanionStudioNextWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)

        DispatchQueue.main.async {
            guard let window = view.window else { return }

            positionTrafficLights(for: window)
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
            window.isOpaque = false
            window.toolbar = nil
            window.styleMask.insert(.fullSizeContentView)
            if #available(macOS 11.0, *) {
                window.titlebarSeparatorStyle = .none
            }
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }

            positionTrafficLights(for: window)
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
            window.isOpaque = false
            window.toolbar = nil
            window.styleMask.insert(.fullSizeContentView)
            if #available(macOS 11.0, *) {
                window.titlebarSeparatorStyle = .none
            }
        }
    }

    private func positionTrafficLights(for window: NSWindow) {
        guard
            let closeButton = window.standardWindowButton(.closeButton),
            let miniButton = window.standardWindowButton(.miniaturizeButton),
            let zoomButton = window.standardWindowButton(.zoomButton)
        else {
            return
        }

        let targetY: CGFloat = 14
        let startX: CGFloat = 14
        let spacing: CGFloat = 6

        closeButton.setFrameOrigin(NSPoint(x: startX, y: targetY))
        miniButton.setFrameOrigin(NSPoint(x: startX + closeButton.frame.width + spacing, y: targetY))
        zoomButton.setFrameOrigin(NSPoint(x: startX + closeButton.frame.width + miniButton.frame.width + (spacing * 2), y: targetY))
    }
}

struct CompanionStudioNextWindowBackgroundClearStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.containerBackground(Color.clear, for: .window)
        } else {
            content
        }
    }
}

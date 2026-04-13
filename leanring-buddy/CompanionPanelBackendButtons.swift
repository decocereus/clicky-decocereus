//
//  CompanionPanelBackendButtons.swift
//  leanring-buddy
//
//  Compact backend selection controls for the companion panel.
//

import SwiftUI

struct CompanionPanelBackendButtons: View {
    let selectedBackend: CompanionAgentBackend
    let setSelectedBackend: (CompanionAgentBackend) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(CompanionAgentBackend.allCases, id: \.rawValue) { backend in
                if backend == selectedBackend {
                    Button(action: {
                        setSelectedBackend(backend)
                    }) {
                        Text(backend.displayName)
                            .frame(maxWidth: .infinity)
                    }
                    .modifier(ClickyProminentActionStyle())
                    .pointerCursor()
                } else {
                    Button(action: {
                        setSelectedBackend(backend)
                    }) {
                        Text(backend.displayName)
                            .frame(maxWidth: .infinity)
                    }
                    .modifier(ClickySecondaryGlassButtonStyle())
                    .pointerCursor()
                }
            }
        }
    }
}

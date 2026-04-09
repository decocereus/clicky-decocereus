//
//  ClickyFontRegistrar.swift
//  leanring-buddy
//
//  Registers bundled font files so the shared typography layer can rely on
//  project-provided fonts instead of whatever happens to be installed locally.
//

import CoreText
import Foundation

enum ClickyFontRegistrar {
    static func registerBundledFonts() {
        let fontURLs = (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? [])
            + (Bundle.main.urls(forResourcesWithExtension: "otf", subdirectory: "Fonts") ?? [])
            + (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [])
            + (Bundle.main.urls(forResourcesWithExtension: "otf", subdirectory: nil) ?? [])

        for fontURL in fontURLs {
            CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
        }
    }
}

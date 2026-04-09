//
//  ClickyAuthSessionStore.swift
//  leanring-buddy
//
//  Small Keychain-backed storage for launch auth session state.
//

import Foundation

struct ClickyAuthSessionSnapshot: Codable {
    let sessionToken: String
    let userID: String
    let email: String
}

enum ClickyAuthSessionStore {
    private static let account = "clicky_auth_session"

    static func save(_ snapshot: ClickyAuthSessionSnapshot) throws {
        let encodedData = try JSONEncoder().encode(snapshot)
        guard let encodedString = String(data: encodedData, encoding: .utf8) else {
            throw NSError(domain: "ClickyAuthSessionStore", code: -1)
        }

        try ClickySecrets.save(key: encodedString, account: account)
    }

    static func load() -> ClickyAuthSessionSnapshot? {
        guard let storedValue = ClickySecrets.load(account: account),
              let storedData = storedValue.data(using: .utf8) else {
            return nil
        }

        return try? JSONDecoder().decode(ClickyAuthSessionSnapshot.self, from: storedData)
    }

    static func clear() {
        ClickySecrets.delete(account: account)
    }
}

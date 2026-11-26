//
//  EchoesInTimeApp.swift
//  EchoesInTime
//
//  Created by Daniel Schepisi on 20/8/2026.
//

import SwiftData
import SwiftUI

@main
struct EchoesInTimeApp: App {
    var body: some Scene {
        WindowGroup {
            LoginView()
        }
        .modelContainer(for: CachedPhoto.self)
    }
}

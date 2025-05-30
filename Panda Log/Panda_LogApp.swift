//
//  Panda_LogApp.swift
//  Panda Log
//
//  Created by George Mihailovski on 29/5/2025.
//

import SwiftUI

@main
struct Panda_LogApp: App {
    @State private var showAbout = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .sheet(isPresented: $showAbout) {
                    AboutView()
                }
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Panda Log") {
                    showAbout = true
                }
            }
            CommandGroup(after: .newItem) {
                Divider()
                Button("Open…") {
                    NotificationCenter.default.post(name: .openLogFile, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}

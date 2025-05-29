//
//  Panda_LogApp.swift
//  Panda Log
//
//  Created by George Mihailovski on 29/5/2025.
//
import SwiftUI

@main
struct Panda_LogApp: App {
    @State private var showAbout = false  // Step 1: State for the About window
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .sheet(isPresented: $showAbout) {   // Step 2: Show AboutView as a sheet
                    AboutView()
                }
        }
        .commands {
            CommandGroup(replacing: .appInfo) {    // Step 3: Custom About menu item
                Button("About Panda Log") {
                    showAbout = true
                }
            }
        }
    }
}

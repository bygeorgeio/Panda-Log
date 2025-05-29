//
//  AboutView.swift
//  Panda Log
//
//  Created by George Mihailovski on 29/5/2025.
//
import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 18) {
            Text("🐼")
                .font(.system(size: 56))
                .padding(.top, 24)

            Text("Panda Log")
                .font(.system(size: 32, weight: .bold, design: .rounded))

            Text("Inspired by CMTrace. Crafted for Mac by George Mihailovski.")
                .font(.system(size: 15, weight: .medium))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true) // Ensures wrapping!

            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.secondary)
                .padding(.top, 4)

            Link("bygeorge.io", destination: URL(string: "https://bygeorge.io")!)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.accentColor)
                .padding(.top, 2)

            Spacer()

            Text("Made in Australia")
                .font(.footnote)
                .foregroundColor(.secondary)
                .opacity(0.7)

            Button("Close") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            .padding(.bottom, 10)
        }
        .frame(width: 350, height: 370)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(radius: 18, y: 4)
        // .padding()  <--- REMOVE this line!
    }
}

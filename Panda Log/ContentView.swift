//
//  ContentView.swift
//  Panda Log
//
//  Created by George Mihailovski on 29/5/2025.
//  This view implements the main UI for the Panda Log app: a tab bar,
//  multiple log-tail views, and support for File > Open… via Notification.
//

import SwiftUI
import Foundation

// MARK: - Notification Extension

/// Custom notification name used to trigger the Open… panel
extension Notification.Name {
    static let openLogFile = Notification.Name("OpenLogFile")
}

// MARK: - Data Models

/// Represents a single open log tab in the UI.
struct LogTab: Identifiable, Equatable {
    let id: UUID
    var fileName: String       // Display name shown in the tab
    var filePath: String       // Full path to the log file
    var followTail: Bool       // Whether to auto-scroll as file grows
    var searchQuery: String = ""  // Filter text for searching within this tab
}

/// Represents a single line in the log, with type for colouring/badging.
struct LogLine: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let type: LogType

    enum LogType {
        case error, warning, info, other
    }
}

// MARK: - Log Tailer

/// Observes a file at `filePath` and streams new lines as they are appended.
class LogTailer: ObservableObject {
    @Published var lines: [LogLine] = []  // All lines read so far

    private var filePath: String
    private var fileHandle: FileHandle?
    private var source: DispatchSourceFileSystemObject?

    /// Initialise by reading existing content and then setting up tailing.
    init(filePath: String) {
        self.filePath = filePath
        self.lines = Self.readAllLines(path: filePath)
        fileHandle = FileHandle(forReadingAtPath: filePath)
        fileHandle?.seekToEndOfFile()
        tailFile()
    }

    deinit {
        source?.cancel()
    }

    /// Reads the entire file contents once.
    private static func readAllLines(path: String) -> [LogLine] {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        return content
            .components(separatedBy: .newlines)
            .compactMap { line in
                guard !line.isEmpty else { return nil }
                let type: LogLine.LogType
                let l = line.lowercased()
                if l.contains("error") { type = .error }
                else if l.contains("warn") { type = .warning }
                else if l.contains("info") { type = .info }
                else { type = .other }
                return LogLine(text: line, type: type)
            }
    }

    /// Determines the log type for a single line.
    private static func getType(for line: String) -> LogLine.LogType {
        let l = line.lowercased()
        if l.contains("error") { return .error }
        if l.contains("warn") { return .warning }
        if l.contains("info") { return .info }
        return .other
    }

    /// Starts a DispatchSource to watch the file descriptor and read new data.
    private func tailFile() {
        guard let fh = fileHandle else { return }
        let fd = fh.fileDescriptor
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .extend,
            queue: .main
        )
        source?.setEventHandler { [weak self] in
            guard let self = self else { return }
            let data = fh.readDataToEndOfFile()
            if let str = String(data: data, encoding: .utf8) {
                let newLines = str
                    .components(separatedBy: .newlines)
                    .filter { !$0.isEmpty }
                for line in newLines {
                    let logLine = LogLine(text: line, type: Self.getType(for: line))
                    DispatchQueue.main.async {
                        self.lines.append(logLine)
                    }
                }
            }
        }
        source?.resume()
    }
}

// MARK: - Main ContentView

/// The root view: displays a tab bar of open logs and the active log view.
struct ContentView: View {
    // MARK: State properties
    @State private var tabs: [LogTab] = []
    @State private var selectedTab: UUID?
    @State private var hoveredTab: UUID? = nil
    @State private var tailers: [UUID: LogTailer] = [:]
    @State private var lastSelectedTab: UUID?
    @FocusState private var searchFieldIsFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar at top
            MacTabBarView(
                tabs: tabs,
                selectedTab: selectedTab,
                hoveredTab: hoveredTab,
                tailers: tailers,
                onTabSelect: { selectedTab = $0 },
                onTabClose: { closeTab($0) },
                onTabHover: { tab, hover in hoveredTab = hover ? tab : nil },
                onPlus: openTab
            )

            Divider()

            // Active log view or placeholder
            if let selected = selectedTab,
               let tabIdx = tabs.firstIndex(where: { $0.id == selected }),
               let tailer = tailers[selected] {
                LogTabView(
                    tab: $tabs[tabIdx],
                    tailer: tailer,
                    shouldScrollToBottom: selected != lastSelectedTab,
                    searchFieldIsFocused: $searchFieldIsFocused
                )
                .id(selected)  // ensures fresh view when switching
            } else {
                Spacer()
                Text("Open a log file to get started!")
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        // Track selection changes to support 'scroll to bottom' logic
        .onChange(of: selectedTab) { new, old in
            lastSelectedTab = old
        }
        // Keyboard shortcuts handler (Cmd+F, Cmd+W, Cmd+L)
        .background(KeyShortcutHandler(
            focusSearch: { searchFieldIsFocused = true },
            closeTab: {
                if let sel = selectedTab { closeTab(sel) }
            },
            clearSearch: {
                if let sel = selectedTab,
                   let idx = tabs.firstIndex(where: { $0.id == sel }) {
                    tabs[idx].searchQuery = ""
                }
            }
        ))
        // Listen for File > Open… notification
        .onReceive(NotificationCenter.default.publisher(for: .openLogFile)) { _ in
            openTab()
        }
    }

    // MARK: - File Open and Tab Management

    /// Presents an NSOpenPanel to select one or more files, then adds them as tabs.
    func openTab() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true

        if panel.runModal() == .OK {
            for url in panel.urls {
                // Avoid reopening same file
                if !tabs.contains(where: { $0.filePath == url.path }) {
                    let tab = LogTab(
                        id: UUID(),
                        fileName: url.lastPathComponent,
                        filePath: url.path,
                        followTail: true
                    )
                    tabs.append(tab)
                    selectedTab = tab.id
                    tailers[tab.id] = LogTailer(filePath: url.path)
                }
            }
        }
    }

    /// Closes the tab with given ID, cleans up its tailer, and selects next tab.
    func closeTab(_ id: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs.remove(at: idx)
        tailers[id] = nil

        if selectedTab == id {
            // Select next tab if possible, else previous
            selectedTab = tabs.indices.contains(idx) ? tabs[idx].id : tabs.last?.id
        }
    }
}

// MARK: - MacTabBarView

/// Renders the horizontal row of tabs and the “+” button.
struct MacTabBarView: View {
    let tabs: [LogTab]
    let selectedTab: UUID?
    let hoveredTab: UUID?
    let tailers: [UUID: LogTailer]

    let onTabSelect: (UUID) -> Void
    let onTabClose: (UUID) -> Void
    let onTabHover: (UUID, Bool) -> Void
    let onPlus: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(tabs) { tab in
                ZStack {
                    // Background & highlight for selected tab
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedTab == tab.id
                              ? Color(NSColor.windowBackgroundColor)
                              : Color(NSColor.controlBackgroundColor))
                        .shadow(color: selectedTab == tab.id ? .black.opacity(0.10) : .clear, radius: 2, y: 1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    selectedTab == tab.id
                                        ? Color.accentColor.opacity(0.65)
                                        : (hoveredTab == tab.id ? Color.secondary.opacity(0.23) : Color.clear),
                                    lineWidth: selectedTab == tab.id ? 1.3 : 1
                                )
                        )
                        .opacity(selectedTab == tab.id ? 1 : (hoveredTab == tab.id ? 0.97 : 0.95))

                    // Tab content: badge, filename, close button
                    HStack(spacing: 7) {
                        TabBadge(tailer: tailers[tab.id], tab: tab)
                            .padding(.leading, 8)
                        Text(tab.fileName)
                            .font(.system(size: 14,
                                          weight: selectedTab == tab.id ? .semibold : .regular))
                            .foregroundColor(selectedTab == tab.id ? .accentColor : .primary)
                            .padding(.vertical, 7)
                            .padding(.trailing, 2)
                        Button(action: { onTabClose(tab.id) }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .opacity((hoveredTab == tab.id || selectedTab == tab.id) ? 1 : 0.35)
                                .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 7)
                        .contentShape(Rectangle())
                    }
                }
                .frame(height: 32)
                .contentShape(RoundedRectangle(cornerRadius: 8))
                .onTapGesture { onTabSelect(tab.id) }
                .onHover { hovering in onTabHover(tab.id, hovering) }
                .animation(.easeOut(duration: 0.15), value: selectedTab)
            }

            // “+” button to open new tabs
            Button(action: onPlus) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.accentColor)
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color(NSColor.controlBackgroundColor).opacity(0.85))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.accentColor.opacity(0.32), lineWidth: 1)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .help("Open a new log file")
            .padding(.leading, 3)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .bottom)
        .shadow(color: .black.opacity(0.07), radius: 6, y: 1)
    }
}

// MARK: - LogTabView

/// Displays the contents of a single tab: follow-tail toggle, search, and log lines.
struct LogTabView: View {
    @Binding var tab: LogTab
    @ObservedObject var tailer: LogTailer

    var shouldScrollToBottom: Bool
    var searchFieldIsFocused: FocusState<Bool>.Binding
    @State private var lastLinesCount = 0

    /// Filtered list of lines based on the search query
    private var filteredLines: [LogLine] {
        let q = tab.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let all = tailer.lines
        return q.isEmpty ? all : all.filter { $0.text.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar: follow-tail toggle and search field
            HStack {
                Toggle("Follow Tail", isOn: Binding(
                    get: { tab.followTail },
                    set: { tab.followTail = $0 }
                ))
                .toggleStyle(.checkbox)
                .padding(.leading, 12)

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundColor(.gray)
                    TextField("Search logs...", text: $tab.searchQuery)
                        .textFieldStyle(PlainTextFieldStyle())
                        .frame(maxWidth: 260)
                        .focused(searchFieldIsFocused)
                        // Prevent the field remaining focused after Enter
                        .onChange(of: searchFieldIsFocused.wrappedValue) { isFocused, _ in
                            if isFocused {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    searchFieldIsFocused.wrappedValue = false
                                }
                            }
                        }
                }
                .padding(7)
                .background(RoundedRectangle(cornerRadius: 8)
                                .fill(Color(NSColor.controlBackgroundColor)))
                .padding(.trailing, 13)
            }
            .padding(.vertical, 7)

            // Show count of search results when filtering
            if !tab.searchQuery.isEmpty {
                HStack {
                    Spacer()
                    Text("\(filteredLines.count) result\(filteredLines.count == 1 ? "" : "s")")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.trailing, 13)
                }
            }

            Divider()

            // Scrollable list of log lines
            ScrollViewReader { proxy in
                List(Array(filteredLines.enumerated()), id: \.element.id) { idx, line in
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        // Line numbers
                        Text("\(idx + 1)")
                            .frame(width: 48, alignment: .trailing)
                            .foregroundColor(.secondary)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(.trailing, 12)

                        // Log text, coloured by type
                        Text(line.text)
                            .foregroundColor(colour(for: line.type))
                            .textSelection(.enabled)
                    }
                    .id(line.id)
                    .background(
                        line.type == .error   ? Color.red.opacity(0.08) :
                        line.type == .warning ? Color.orange.opacity(0.06) :
                        Color.clear
                    )
                }
                .font(.system(size: 13, design: .monospaced))
                .listRowInsets(EdgeInsets(top: 1, leading: 0, bottom: 1, trailing: 0))
                .onAppear {
                    scrollToBottom(proxy)
                    lastLinesCount = filteredLines.count
                }
                .onChange(of: filteredLines.count) { newCount, _ in
                    if tab.followTail, newCount > lastLinesCount {
                        scrollToBottom(proxy)
                    }
                    lastLinesCount = newCount
                }
                .onChange(of: shouldScrollToBottom) { _, _ in
                    scrollToBottom(proxy)
                }
                .onChange(of: tab.searchQuery) { _, _ in
                    if let first = filteredLines.first {
                        proxy.scrollTo(first.id, anchor: .top)
                    }
                }
            }
        }
    }

    /// Helper to reliably scroll to bottom, with slight delays for SwiftUI quirks.
    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let last = filteredLines.last else { return }
        DispatchQueue.main.async { proxy.scrollTo(last.id, anchor: .bottom) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }

    /// Colour mapping for different log types
    private func colour(for type: LogLine.LogType) -> Color {
        switch type {
        case .error:   return .red
        case .warning: return .orange
        case .info:    return .blue
        case .other:   return .primary
        }
    }
}

// MARK: - TabBadge

/// Small red/orange dot with count, shown on each tab header for errors/warnings.
struct TabBadge: View {
    let tailer: LogTailer?
    let tab: LogTab

    var body: some View {
        // Filter through the tailer’s lines if a search query exists
        let lines: [LogLine] = {
            guard let tailer else { return [] }
            let q = tab.searchQuery.lowercased()
            if q.isEmpty { return tailer.lines }
            return tailer.lines.filter { $0.text.lowercased().contains(q) }
        }()

        let errorCount = lines.filter { $0.type == .error }.count
        let warningCount = lines.filter { $0.type == .warning }.count

        Group {
            if errorCount > 0 {
                badge(count: errorCount, color: .red)
            } else if warningCount > 0 {
                badge(count: warningCount, color: .orange)
            }
        }
    }

    /// Reusable small circle with a number or dot
    private func badge(count: Int, color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 9, height: 9)
            .overlay(
                Text(count < 10 ? "\(count)" : "•")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
            )
            .offset(y: 7)
    }
}

// MARK: - Keyboard Shortcuts Handler

/// Captures Cmd+F, Cmd+W, Cmd+L globally and invokes closures accordingly.
struct KeyShortcutHandler: NSViewRepresentable {
    let focusSearch: () -> Void
    let closeTab: () -> Void
    let clearSearch: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // Add a local monitor for keyDown events
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) {
                switch event.charactersIgnoringModifiers {
                case "f": focusSearch(); return nil
                case "w": closeTab();     return nil
                case "l": clearSearch();  return nil
                default: break
                }
            }
            return event
        }
        context.coordinator.monitor = monitor
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) { }

    func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        if let monitor = coordinator.monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    class Coordinator {
        var monitor: Any?
    }
}

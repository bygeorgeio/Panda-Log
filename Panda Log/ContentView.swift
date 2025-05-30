//
//  ContentView.swift
//  Panda Log
//
//  Created by George Mihailovski on 29/5/2025.
//

import SwiftUI
import Foundation

// MARK: - Notification Extension
extension Notification.Name {
    static let openLogFile = Notification.Name("OpenLogFile")
}

// MARK: - Model

struct LogTab: Identifiable, Equatable {
    let id: UUID
    var fileName: String
    var filePath: String
    var followTail: Bool
    var searchQuery: String = ""
}

struct LogLine: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let type: LogType
    enum LogType { case error, warning, info, other }
}

class LogTailer: ObservableObject {
    @Published var lines: [LogLine] = []
    private var filePath: String
    private var fileHandle: FileHandle?
    private var source: DispatchSourceFileSystemObject?

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

    private func tailFile() {
        guard let fh = fileHandle else { return }
        let fd = fh.fileDescriptor
        source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .extend, queue: .main)
        source?.setEventHandler { [weak self] in
            guard let self = self else { return }
            let data = fh.readDataToEndOfFile()
            if let str = String(data: data, encoding: .utf8) {
                let newLines = str.components(separatedBy: .newlines).filter { !$0.isEmpty }
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

    static func readAllLines(path: String) -> [LogLine] {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        return content.components(separatedBy: .newlines).compactMap { line in
            if line.isEmpty { return nil }
            let type: LogLine.LogType
            let l = line.lowercased()
            if l.contains("error") { type = .error }
            else if l.contains("warn") { type = .warning }
            else if l.contains("info") { type = .info }
            else { type = .other }
            return LogLine(text: line, type: type)
        }
    }

    static func getType(for line: String) -> LogLine.LogType {
        let l = line.lowercased()
        if l.contains("error") { return .error }
        else if l.contains("warn") { return .warning }
        else if l.contains("info") { return .info }
        else { return .other }
    }
}

// MARK: - ContentView

struct ContentView: View {
    @State private var tabs: [LogTab] = []
    @State private var selectedTab: UUID?
    @State private var hoveredTab: UUID? = nil
    @State private var tailers: [UUID: LogTailer] = [:]
    @State private var lastSelectedTab: UUID?
    @FocusState private var searchFieldIsFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
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
            if let selected = selectedTab,
               let tabIdx = tabs.firstIndex(where: { $0.id == selected }),
               let tailer = tailers[selected] {
                LogTabView(
                    tab: $tabs[tabIdx],
                    tailer: tailer,
                    shouldScrollToBottom: selected != lastSelectedTab,
                    searchFieldIsFocused: $searchFieldIsFocused
                )
                .id(selected)
            } else {
                Spacer()
                Text("Open a log file to get started!")
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .onChange(of: selectedTab) { newSelected, oldSelected in
            lastSelectedTab = oldSelected
        }
        .background(KeyShortcutHandler(
            focusSearch: {
                searchFieldIsFocused = true
            },
            closeTab: {
                if let selected = selectedTab {
                    closeTab(selected)
                }
            },
            clearSearch: {
                if let selected = selectedTab,
                   let idx = tabs.firstIndex(where: { $0.id == selected }) {
                    tabs[idx].searchQuery = ""
                }
            }
        ))
        .onReceive(NotificationCenter.default.publisher(for: .openLogFile)) { _ in
            openTab()
        }
    }

    func openTab() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            for url in panel.urls {
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

    func closeTab(_ id: UUID) {
        if let idx = tabs.firstIndex(where: { $0.id == id }) {
            tabs.remove(at: idx)
            tailers[id] = nil
            if selectedTab == id {
                selectedTab = tabs.indices.contains(idx) ? tabs[idx].id : tabs.last?.id
            }
        }
    }
}

// MARK: - MacTabBarView

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
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedTab == tab.id
                            ? Color(NSColor.windowBackgroundColor)
                            : Color(NSColor.controlBackgroundColor)
                        )
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

                    HStack(spacing: 7) {
                        TabBadge(tailer: tailers[tab.id], tab: tab)
                            .padding(.leading, 8)
                        Text(tab.fileName)
                            .font(.system(size: 14, weight: selectedTab == tab.id ? .semibold : .regular))
                            .foregroundColor(selectedTab == tab.id ? .accentColor : .primary)
                            .padding(.vertical, 7)
                            .padding(.trailing, 2)
                        Button(action: { onTabClose(tab.id) }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .opacity((hoveredTab == tab.id || selectedTab == tab.id) ? 1.0 : 0.35)
                                .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 7)
                        .contentShape(Rectangle())
                    }
                }
                .frame(height: 32)
                .fixedSize(horizontal: false, vertical: true)
                .contentShape(RoundedRectangle(cornerRadius: 8))
                .onTapGesture { onTabSelect(tab.id) }
                .onHover { hovering in onTabHover(tab.id, hovering) }
                .animation(.easeOut(duration: 0.15), value: selectedTab)
            }
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

struct LogTabView: View {
    @Binding var tab: LogTab
    @ObservedObject var tailer: LogTailer
    var shouldScrollToBottom: Bool
    var searchFieldIsFocused: FocusState<Bool>.Binding
    @State private var lastLinesCount = 0

    var filteredLines: [LogLine] {
        if tab.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return tailer.lines
        }
        let query = tab.searchQuery.lowercased()
        return tailer.lines.filter { $0.text.lowercased().contains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Toggle("Follow Tail", isOn: Binding(
                    get: { tab.followTail },
                    set: { tab.followTail = $0 }
                ))
                .toggleStyle(.checkbox)
                .padding(.leading, 12)
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search logs...", text: $tab.searchQuery)
                        .textFieldStyle(PlainTextFieldStyle())
                        .frame(maxWidth: 260)
                        .focused(searchFieldIsFocused)
                        .onChange(of: searchFieldIsFocused.wrappedValue) { isFocused, _ in
                            if isFocused {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    searchFieldIsFocused.wrappedValue = false
                                }
                            }
                        }
                }
                .padding(7)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
                .padding(.trailing, 13)
            }
            .padding(.vertical, 7)

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
            ScrollViewReader { proxy in
                List(Array(filteredLines.enumerated()), id: \.element.id) { idx, line in
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("\(idx + 1)")
                            .frame(width: 48, alignment: .trailing)
                            .foregroundColor(.secondary)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(.trailing, 12)
                        Text(line.text)
                            .foregroundColor(colour(for: line.type))
                            .textSelection(.enabled)
                    }
                    .id(line.id)
                    .background(
                        line.type == .error
                        ? Color.red.opacity(0.08)
                        : (line.type == .warning ? Color.orange.opacity(0.06) : Color.clear)
                    )
                }
                .font(.system(size: 13, design: .monospaced))
                .listRowInsets(EdgeInsets(top: 1, leading: 0, bottom: 1, trailing: 0))
                .onAppear {
                    reliableScrollToBottom(proxy: proxy)
                    lastLinesCount = filteredLines.count
                }
                .onChange(of: filteredLines.count) { count, _ in
                    if tab.followTail, count > lastLinesCount {
                        reliableScrollToBottom(proxy: proxy)
                    }
                    lastLinesCount = count
                }
                .onChange(of: shouldScrollToBottom) { _, _ in
                    reliableScrollToBottom(proxy: proxy)
                }
                .onChange(of: tab.searchQuery) { _, _ in
                    if let first = filteredLines.first {
                        DispatchQueue.main.async {
                            proxy.scrollTo(first.id, anchor: .top)
                        }
                    }
                }
            }
        }
    }

    private func reliableScrollToBottom(proxy: ScrollViewProxy) {
        guard let last = filteredLines.last else { return }
        DispatchQueue.main.async {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }

    private func colour(for type: LogLine.LogType) -> Color {
        switch type {
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        case .other: return .primary
        }
    }
}

// MARK: - TabBadge

struct TabBadge: View {
    let tailer: LogTailer?
    let tab: LogTab

    var body: some View {
        let lines: [LogLine] = {
            guard let tailer else { return [] }
            let query = tab.searchQuery.lowercased()
            if query.isEmpty { return tailer.lines }
            return tailer.lines.filter { $0.text.lowercased().contains(query) }
        }()

        let errorCount = lines.filter { $0.type == .error }.count
        let warningCount = lines.filter { $0.type == .warning }.count

        Group {
            if errorCount > 0 {
                Circle()
                    .fill(Color.red)
                    .frame(width: 9, height: 9)
                    .overlay(
                        Text(errorCount < 10 ? "\(errorCount)" : "•")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .offset(y: 7)
            } else if warningCount > 0 {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 9, height: 9)
                    .overlay(
                        Text(warningCount < 10 ? "\(warningCount)" : "•")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .offset(y: 7)
            }
        }
    }
}

// MARK: - Keyboard Shortcuts Handler

struct KeyShortcutHandler: NSViewRepresentable {
    let focusSearch: () -> Void
    let closeTab: () -> Void
    let clearSearch: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "f" {
                focusSearch()
                return nil
            }
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "w" {
                closeTab()
                return nil
            }
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "l" {
                clearSearch()
                return nil
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

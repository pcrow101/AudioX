//
//  ContentView.swift
//  AudioX
//
//  Created by paul crow on 17/05/2026.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var converter = FLACConverter()
    @State private var isDragTargeted = false
    
    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        .navigationTitle("AudioX")
        .toolbar {
            toolbarItems
        }
        .toolbarBackgroundVisibility(.visible, for: .windowToolbar)
    }
    
    // MARK: - Sidebar
    
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Section {
                Picker("Output Format", selection: $converter.outputFormat) {
                    ForEach(OutputFormat.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
            } header: {
                Label("Format", systemImage: "waveform")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
            
            Divider()
            
            Section {
                outputDirectoryPicker
            } header: {
                Label("Output", systemImage: "folder")
                    .font(.headline)
                    .padding(.horizontal)
            }
            
            Divider()
            
            Section {
                statusView
            } header: {
                Label("Status", systemImage: "info.circle")
                    .font(.headline)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 240)
    }
    
    private var outputDirectoryPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                chooseOutputDirectory()
            } label: {
                Label("Choose Folder…", systemImage: "folder.badge.plus")
            }
            .padding(.horizontal)
            
            if let dir = converter.outputDirectory {
                Text(dir.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                Text("Same as source")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
    }
    
    private var statusView: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch converter.status {
            case .idle:
                Text("Ready")
                    .foregroundStyle(.secondary)
            case .converting:
                ProgressView(value: converter.overallProgress) {
                    Text("Converting…")
                }
            case .completed(let success, let total):
                Label("\(success)/\(total) completed", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failed(let msg):
                Label(msg, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Detail View
    
    private var detailView: some View {
        VStack(spacing: 0) {
            Group {
                if converter.files.isEmpty {
                    emptyState
                } else {
                    fileList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onDrop(of: [.fileURL], isTargeted: $isDragTargeted) { providers in
                handleDrop(providers)
            }
            .overlay {
                if isDragTargeted {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [8]))
                        .background(Color.accentColor.opacity(0.05))
                        .padding(8)
                }
            }

            if !converter.files.isEmpty {
                convertBar
            }
        }
    }

    private var convertBar: some View {
        VStack(spacing: 8) {
            Divider()
            HStack(spacing: 16) {
                // Progress indicator when converting
                if converter.status == .converting {
                    ProgressView(value: converter.overallProgress)
                        .frame(maxWidth: .infinity)
                }

                Spacer()

                Button {
                    Task { await converter.convert() }
                } label: {
                    HStack(spacing: 6) {
                        if converter.status == .converting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Text(converter.status == .converting ? "Converting…" : "Convert to \(converter.outputFormat.rawValue)")
                            .fontWeight(.semibold)
                    }
                    .frame(minWidth: 220)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(converter.status == .converting)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
            .padding(.top, 8)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Drop FLAC files here")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Or use the Add button to select files")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            
            Button {
                chooseFiles()
            } label: {
                Label("Add Files…", systemImage: "plus.circle")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var fileList: some View {
        List {
            ForEach(converter.files) { item in
                HStack {
                    Image(systemName: "music.note")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.fileName)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if case .failed(let msg) = item.status {
                            Text(msg)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    statusIcon(for: item.status)
                }
            }
            .onDelete { offsets in
                converter.removeFiles(at: offsets)
            }
        }
    }
    
    @ViewBuilder
    private func statusIcon(for status: FileItemStatus) -> some View {
        switch status {
        case .pending:
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
        case .converting:
            ProgressView()
                .controlSize(.small)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem {
            Button {
                chooseFiles()
            } label: {
                Label("Add Files", systemImage: "plus")
            }
        }
        
        ToolbarItem {
            Button {
                converter.removeAll()
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .disabled(converter.files.isEmpty || converter.status == .converting)
        }
        
        ToolbarItem {
            Button {
                Task { await converter.convert() }
            } label: {
                Label("Convert", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(converter.files.isEmpty || converter.status == .converting)
        }
    }
    
    // MARK: - Actions
    
    private func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType(filenameExtension: "flac")!]
        
        if panel.runModal() == .OK {
            converter.addFiles(urls: panel.urls)
        }
    }
    
    private func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        
        if panel.runModal() == .OK {
            converter.outputDirectory = panel.url
        }
    }
    
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: "public.file-url") { data, _ in
                defer { group.leave() }
                if let data = data as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    urls.append(url)
                }
            }
        }
        
        group.notify(queue: .main) {
            converter.addFiles(urls: urls)
        }
        
        return true
    }
}

#Preview {
    ContentView()
}

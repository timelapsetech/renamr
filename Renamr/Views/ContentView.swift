import SwiftUI

struct ConfigView: View {
    @ObservedObject var viewModel: RenameViewModel
    @Binding var showSourceFolderPicker: Bool
    @Binding var showOutputFolderPicker: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 15) {
                // App Title and Tagline
                VStack(spacing: 2) {
                    Text("Renamr")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Fast, easy file renaming for images and other files.")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Source Directory Section
                DirectoryDropZone(
                    title: "Source Directory",
                    subtitle: "Drag and drop a folder here or click to select",
                    isTargeted: $viewModel.isSourceTargeted,
                    onDrop: viewModel.handleSourceDrop,
                    selectedPath: viewModel.sourceURL?.path
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    showSourceFolderPicker = true
                }
                .fileImporter(isPresented: $showSourceFolderPicker, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
                    switch result {
                    case .success(let urls):
                        if let url = urls.first {
                            viewModel.setSourceURLFromPicker(url)
                        }
                    case .failure:
                        break
                    }
                }
                
                // File Filters Section
                VStack(alignment: .leading, spacing: 4) {
                    Text("Input Filter")
                        .font(.headline)
                    
                    HStack {
                        Text("File Extension:")
                        TextField("ext", text: $viewModel.extensionFilter)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Text("(leave empty to include all files)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    Text("Only files with this extension will be included in the rename operation")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.05))
                )
                
                // Combined Options Section
                VStack(alignment: .leading, spacing: 8) {
                    // Mode Selector
                    Toggle("Rename Files Sequentially", isOn: $viewModel.sequentialMode)
                        .padding(.horizontal, 10)
                    
                    // All Options Container
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Rename Options")
                            .font(.headline)
                        
                        // Sequential Options Group
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Sequential Options")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 10) {
                                // Base Name
                                HStack {
                                    Text("Base Name:")
                                    TextField("Enter base name", text: $viewModel.basename)
                                        .textFieldStyle(.roundedBorder)
                                }
                                
                                // Number Padding
                                HStack {
                                    Text("Number Padding:")
                                    Stepper(value: $viewModel.numberPadding, in: 1...10) {
                                        Text("\(viewModel.numberPadding) digits")
                                    }
                                }
                                
                                // Start Number
                                HStack {
                                    Text("Start Number:")
                                    TextField("", value: $viewModel.startNumber, formatter: NumberFormatter())
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 80)
                                    Stepper("", value: $viewModel.startNumber, in: 1...999999) { _ in }
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.1))
                            )
                            .opacity(viewModel.sequentialMode ? 1.0 : 0.5)
                            .disabled(!viewModel.sequentialMode)
                        }
                        
                        // Non-Sequential Options
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Non-Sequential Options")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 10) {
                                // Pattern Type Picker
                                HStack {
                                    Text("Rename Pattern:")
                                    Picker("Pattern", selection: $viewModel.nonSequentialPattern) {
                                        ForEach(NonSequentialPattern.allCases, id: \.self) { pattern in
                                            Text(pattern.displayName).tag(pattern)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(width: 200)
                                }
                                
                                // Random name length if random pattern selected
                                if viewModel.nonSequentialPattern == .random {
                                    HStack {
                                        Text("Random Name Length:")
                                        Stepper(value: $viewModel.randomNameLength, in: 4...16) {
                                            Text("\(viewModel.randomNameLength) characters")
                                        }
                                    }
                                }
                                
                                if viewModel.nonSequentialPattern == .dateTime && !viewModel.sequentialMode {
                                    Text("Date-based naming will use image EXIF date when available, falling back to file creation date.")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.1))
                            )
                            .opacity(viewModel.sequentialMode ? 0.5 : 1.0)
                            .disabled(viewModel.sequentialMode)
                        }
                        
                        // Rename In Place Toggle
                        Toggle("Rename in place", isOn: $viewModel.renameInPlace)
                            .padding(.top, 8)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.05))
                    )
                }
                
                // Output Directory Section (shown when renameInPlace is false)
                if !viewModel.renameInPlace {
                    DirectoryDropZone(
                        title: "Output Directory",
                        subtitle: "Drag and drop output folder here or click to select",
                        isTargeted: $viewModel.isOutputTargeted,
                        onDrop: viewModel.handleOutputDrop,
                        selectedPath: viewModel.outputURL?.path
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showOutputFolderPicker = true
                    }
                    .fileImporter(isPresented: $showOutputFolderPicker, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
                        switch result {
                        case .success(let urls):
                            if let url = urls.first {
                                viewModel.outputURL = url
                            }
                        case .failure:
                            break
                        }
                    }
                }
                
                // Preview Button
                if viewModel.canStartRenaming {
                    Button(viewModel.previewGenerated ? "Update Preview" : "Show New Names") {
                        viewModel.generatePreview()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
                
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 10)
        }
        .frame(minWidth: 240, idealWidth: 300, maxWidth: 400)
    }
}

struct ContentView: View {
    @StateObject private var viewModel = RenameViewModel()
    @Environment(\.colorScheme) var colorScheme
    @State private var showSourceFolderPicker = false
    @State private var showOutputFolderPicker = false
    @State private var showPreviewPanel = true
    
    var body: some View {
        HStack(spacing: 0) {
            ConfigView(
                viewModel: viewModel,
                showSourceFolderPicker: $showSourceFolderPicker,
                showOutputFolderPicker: $showOutputFolderPicker
            )
            .frame(minWidth: 320, idealWidth: 400, maxWidth: 520)
            .background(colorScheme == .dark ? Color.black : Color.white)
            .overlay(
                Divider(), alignment: .trailing
            )
            
            if showPreviewPanel {
                ZStack(alignment: .topLeading) {
                    VStack(spacing: 0) {
                        HStack {
                            Spacer()
                            Button(action: { showPreviewPanel = false }) {
                                Image(systemName: "sidebar.right")
                                    .padding(8)
                            }
                            .buttonStyle(.plain)
                            .help("Hide Preview Panel")
                        }
                        .background(Color.clear)
                        if viewModel.previewGenerated {
                            PreviewView(viewModel: viewModel)
                        } else {
                            VStack {
                                Text("No preview")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.move(edge: .trailing))
                .background(colorScheme == .dark ? Color(NSColor.windowBackgroundColor) : Color(NSColor.windowBackgroundColor))
                .overlay(
                    Divider(), alignment: .leading
                )
            } else {
                Button(action: { showPreviewPanel = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "sidebar.right")
                        Text("Show Preview")
                    }
                    .padding(8)
                }
                .buttonStyle(.plain)
                .frame(maxHeight: .infinity)
                .background(Color.clear)
                .help("Show Preview Panel")
            }
        }
        .animation(.default, value: showPreviewPanel)
        .onAppear {
            viewModel.resetSourceURLIfNeeded()
        }
        .onChange(of: viewModel.shouldResetSourceURL) { _ in
            viewModel.resetSourceURLIfNeeded()
        }
    }
}

#Preview {
    ContentView()
} 
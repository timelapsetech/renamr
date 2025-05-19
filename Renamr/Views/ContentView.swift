import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = RenameViewModel()
    @Environment(\.colorScheme) var colorScheme
    
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
                    subtitle: "Drag and drop a folder here",
                    isTargeted: $viewModel.isSourceTargeted,
                    onDrop: viewModel.handleSourceDrop,
                    selectedPath: viewModel.sourceURL?.path
                )
                
                // File Filters Section
                HStack {
                    Text("File Extension:")
                        .font(.headline)
                    TextField("ext", text: $viewModel.extensionFilter)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text("(leave empty for all files)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 10)
                
                // Combined Options Section
                VStack(alignment: .leading, spacing: 8) {
                    // Mode Selector
                    Toggle("Rename Files Sequentially", isOn: $viewModel.sequentialMode)
                        .padding(.horizontal, 10)
                    
                    // All Options Container
                    VStack(alignment: .leading, spacing: 15) {
                        Text(viewModel.sequentialMode ? "Rename Options" : "Rename Options")
                            .font(.headline)
                        
                        // Sequential Options (Base Name)
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Base Name:")
                                TextField("Enter base name", text: $viewModel.basename)
                                    .textFieldStyle(.roundedBorder)
                            }
                            .disabled(!viewModel.sequentialMode)
                            .opacity(viewModel.sequentialMode ? 1.0 : 0.5)
                        }
                        
                        // Sequential Options (Number Padding)
                        HStack {
                            Text("Number Padding:")
                            Stepper(value: $viewModel.numberPadding, in: 1...10) {
                                Text("\(viewModel.numberPadding) digits")
                            }
                        }
                        .disabled(!viewModel.sequentialMode)
                        .opacity(viewModel.sequentialMode ? 1.0 : 0.5)
                        
                        // Sequential Options (Start Number)
                        HStack {
                            Text("Start Number:")
                            TextField("", value: $viewModel.startNumber, formatter: NumberFormatter())
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            Stepper("", value: $viewModel.startNumber, in: 1...999999) { _ in
                                // Empty text, we're using the TextField
                            }
                        }
                        .disabled(!viewModel.sequentialMode)
                        .opacity(viewModel.sequentialMode ? 1.0 : 0.5)
                        
                        // Non-Sequential Options
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
                            .disabled(viewModel.sequentialMode)
                            .opacity(viewModel.sequentialMode ? 0.5 : 1.0)
                            
                            // Random name length if random pattern selected
                            if viewModel.nonSequentialPattern == .random {
                                HStack {
                                    Text("Random Name Length:")
                                    Stepper(value: $viewModel.randomNameLength, in: 4...16) {
                                        Text("\(viewModel.randomNameLength) characters")
                                    }
                                }
                                .disabled(viewModel.sequentialMode)
                                .opacity(viewModel.sequentialMode ? 0.5 : 1.0)
                            }
                            
                            if viewModel.nonSequentialPattern == .dateTime && !viewModel.sequentialMode {
                                Text("Date-based naming will use image EXIF date when available, then file modification date, then current date.")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        
                        // Rename In Place Toggle
                        Toggle("Rename in place", isOn: $viewModel.renameInPlace)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.1))
                    )
                }
                
                // Output Directory Section (shown when renameInPlace is false)
                if !viewModel.renameInPlace {
                    DirectoryDropZone(
                        title: "Output Directory",
                        subtitle: "Drag and drop output folder here",
                        isTargeted: $viewModel.isOutputTargeted,
                        onDrop: viewModel.handleOutputDrop,
                        selectedPath: viewModel.outputURL?.path
                    )
                }
                
                // Progress Section
                if viewModel.isProcessing {
                    ProgressView(value: viewModel.progress, total: 1.0) {
                        Text("Processing files... \(Int(viewModel.progress * 100))%")
                    }
                    .padding()
                }
                
                // Action Buttons
                HStack {
                    Button("Start Renaming") {
                        viewModel.startRenaming()
                    }
                    .disabled(!viewModel.canStartRenaming)
                    .buttonStyle(.borderedProminent)
                    
                    Button("Cancel") {
                        viewModel.cancelRenaming()
                    }
                    .disabled(!viewModel.isProcessing)
                    .buttonStyle(.bordered)
                }
                .padding()
                
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 10)
        }
        .frame(minWidth: 380, idealWidth: 380, maxWidth: 380, minHeight: 640, idealHeight: viewModel.renameInPlace ? 640 : 720, maxHeight: 800)
        .background(colorScheme == .dark ? Color.black : Color.white)
        .onAppear {
            // Reset URL on app launch
            viewModel.resetSourceURLIfNeeded()
        }
        .onChange(of: viewModel.shouldResetSourceURL) { _ in
            // Reset URL when flag changes
            viewModel.resetSourceURLIfNeeded()
        }
    }
}

#Preview {
    ContentView()
} 
// NOTE: To use .quickLookPreview, set your deployment target to macOS 13.0+ and use Xcode 14+
import SwiftUI
import AppKit
import QuickLook

struct PreviewView: View {
    @ObservedObject var viewModel: RenameViewModel
    @State private var quickLookURL: URL? = nil
    
    // Helper for stats
    var totalSize: Int64 {
        viewModel.previewFiles.reduce(0) { $0 + (Int64((try? $1.sourceURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)) }
    }
    var averageSize: Int64 {
        guard !viewModel.previewFiles.isEmpty else { return 0 }
        return totalSize / Int64(viewModel.previewFiles.count)
    }
    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    var formattedAverageSize: String {
        ByteCountFormatter.string(fromByteCount: averageSize, countStyle: .file)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress Bar (if processing)
            if viewModel.isProcessing {
                VStack(spacing: 6) {
                    ProgressView(value: viewModel.progress) {
                        Text("\(viewModel.processingStage) \(Int(viewModel.progress * 100))%")
                            .font(.headline)
                    }
                    .progressViewStyle(.linear)
                    .padding(.horizontal)
                }
                .padding(.top, 12)
            }
            // Statistics Header
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 32) {
                    StatisticView(title: "Files Found", value: "\(viewModel.previewFiles.count)", systemImage: "doc.on.doc")
                    if viewModel.sequentialMode {
                        StatisticView(title: "First Number", value: "\(viewModel.startNumber)", systemImage: "number")
                        StatisticView(title: "Last Number", value: "\(viewModel.startNumber + viewModel.previewFiles.count - 1)", systemImage: "number")
                    }
                    StatisticView(title: "Total Size", value: formattedTotalSize, systemImage: "externaldrive")
                    StatisticView(title: "Average Size", value: formattedAverageSize, systemImage: "divide")
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.12))
            )
            .padding(.horizontal)
            
            // Column Headers
            HStack {
                Text("#")
                    .font(.subheadline).bold()
                    .frame(width: 36, alignment: .trailing)
                Text("Current Name")
                    .font(.subheadline).bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("New Name")
                    .font(.subheadline).bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Date/Time")
                    .font(.subheadline).bold()
                    .frame(width: 160, alignment: .leading)
                Text("Size")
                    .font(.subheadline).bold()
                    .frame(width: 80, alignment: .trailing)
                Spacer().frame(width: 60)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.08))
            
            // File List
            List(Array(viewModel.previewFiles.enumerated()), id: \.1.sourceURL) { (index, file) in
                FilePreviewTabularRow(
                    index: index,
                    file: file,
                    rowIsEven: index % 2 == 0,
                    viewModel: viewModel,
                    onPreview: {
                        quickLookURL = file.sourceURL
                    }
                )
                .contentShape(Rectangle())
            }
            .listStyle(.plain)
            
            // Action Button
            if viewModel.previewGenerated {
                Button("Rename Files") {
                    viewModel.startRenaming()
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
        }
        .quickLookPreview($quickLookURL)
    }
}

struct StatisticView: View {
    let title: String
    let value: String
    var systemImage: String? = nil
    
    var body: some View {
        HStack(spacing: 6) {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
                    .foregroundColor(.accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.title3)
                    .fontWeight(.medium)
            }
        }
    }
}

struct FilePreviewTabularRow: View {
    let index: Int
    let file: PreviewFile
    let rowIsEven: Bool
    let viewModel: RenameViewModel
    let onPreview: () -> Void
    
    var fileSize: String {
        let size = (try? file.sourceURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
    var dateInfo: (String, Bool) {
        // Returns (formatted date string, isEXIF)
        if let exifDate = viewModel.getExifDate(from: file.sourceURL) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return (formatter.string(from: exifDate) + " (EXIF)", true)
        } else if let creationDate = viewModel.getFileCreationDate(file.sourceURL) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return (formatter.string(from: creationDate), false)
        } else {
            return ("-", false)
        }
    }
    
    var body: some View {
        HStack {
            Text("\(index + 1)")
                .frame(width: 36, alignment: .trailing)
            Text(file.sourceURL.lastPathComponent)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(file.newName)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(dateInfo.0)
                .foregroundColor(dateInfo.1 ? .blue : .primary)
                .frame(width: 160, alignment: .leading)
            Text(fileSize)
                .frame(width: 80, alignment: .trailing)
            HStack(spacing: 12) {
                Button(action: onPreview) {
                    Image(systemName: "eye")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.space, modifiers: [])
                Button(action: {
                    NSWorkspace.shared.selectFile(file.sourceURL.path, inFileViewerRootedAtPath: file.sourceURL.deletingLastPathComponent().path)
                }) {
                    Image(systemName: "folder")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            .frame(width: 60)
        }
        .padding(.vertical, 2)
        .background(rowIsEven ? Color.gray.opacity(0.08) : Color.clear)
    }
}

#Preview {
    PreviewView(viewModel: RenameViewModel())
} 
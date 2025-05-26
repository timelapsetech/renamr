import SwiftUI
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum NonSequentialPattern: String, CaseIterable {
    case dateTime
    case random
    
    var displayName: String {
        switch self {
        case .dateTime: return "Date & Time"
        case .random: return "Random"
        }
    }
}

public class RenameViewModel: ObservableObject {
    @Published var sourceURL: URL?
    @Published var outputURL: URL?
    @Published public var basename: String = ""
    @Published public var numberPadding: Int = 4
    @Published public var startNumber: Int = 1
    @Published public var renameInPlace: Bool = true
    @Published var isProcessing: Bool = false
    @Published var progress: Double = 0
    @Published var isSourceTargeted: Bool = false
    @Published var isOutputTargeted: Bool = false
    @Published public var extensionFilter: String = ""
    @Published var shouldResetSourceURL: Bool = false
    
    // Rename mode
    @Published public var sequentialMode: Bool = true
    
    // Non-sequential options
    @Published public var nonSequentialPattern: NonSequentialPattern = .dateTime
    @Published public var randomNameLength: Int = 8
    
    // Track which naming scheme is being used
    @Published var isUsingDatePattern: Bool = false
    @Published var showingDateInfo: Bool = false
    
    // Store the base date for time lapse sequences
    private var timeLapseBaseDate: String?
    
    // Presets for base name patterns
    let presets = [
        "Manual": "Manual Entry",
        "TimelapseSequence": "Time Lapse Sequence",
        "DateSequence": "Date Sequence (YYYYMMDD_)",
        "IMG_": "Simple (IMG_)",
        "Photo_": "Photo_",
        "Scan_": "Scan_"
    ]
    
    private var currentOperation: Task<Void, Never>?
    private var usedRandomNames = Set<String>()
    
    @Published public var previewFiles: [PreviewFile] = []
    @Published public var previewGenerated = false
    @Published var processingStage: String = ""
    
    public init() {
        // Set Manual as the default option
        selectPreset("Manual")
    }
    
    var canStartRenaming: Bool {
        guard let sourceURL = sourceURL else { return false }
        if renameInPlace {
            return true
        }
        return outputURL != nil
    }
    
    func selectPreset(_ key: String) {
        if key == "Manual" {
            basename = ""
            showingDateInfo = false
            timeLapseBaseDate = nil
        } else if key == "TimelapseSequence" {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd"
            basename = formatter.string(from: Date()) + "1CO_"
            showingDateInfo = true
            timeLapseBaseDate = nil
        } else if key == "DateSequence" {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd"
            basename = formatter.string(from: Date()) + "_"
            showingDateInfo = true
            timeLapseBaseDate = nil
        } else {
            basename = key
            showingDateInfo = false
            timeLapseBaseDate = nil
        }
    }
    
    func handleSourceDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (data, error) in
            guard let data = data as? Data,
                  let path = String(data: data, encoding: .utf8),
                  let url = URL(string: path) else { return }
            
            DispatchQueue.main.async {
                self.sourceURL = url
                self.suggestBasenameFromSourceURL()
                self.previewFiles = []
                self.previewGenerated = false
            }
        }
        return true
    }
    
    func handleOutputDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (data, error) in
            guard let data = data as? Data,
                  let path = String(data: data, encoding: .utf8),
                  let url = URL(string: path) else { return }
            
            DispatchQueue.main.async {
                self.outputURL = url
            }
        }
        return true
    }
    
    public func generatePreview() {
        guard let sourceURL = sourceURL else { return }
        
        Task {
            await MainActor.run {
                isProcessing = true
                progress = 0
                processingStage = "Scanning files..."
            }
            
            let fileManager = FileManager.default
            let enumerator = fileManager.enumerator(at: sourceURL, includingPropertiesForKeys: [.isRegularFileKey, .isHiddenKey, .nameKey])
            var files: [URL] = []
            
            while let fileURL = enumerator?.nextObject() as? URL {
                if !shouldProcessFile(fileURL) { continue }
                files.append(fileURL)
            }
            // Sort files by EXIF date, then creation date, then filename
            let filesCopy = files.sorted { lhs, rhs in
                let lhsDate = getBestDate(for: lhs)
                let rhsDate = getBestDate(for: rhs)
                if let lhsDate = lhsDate, let rhsDate = rhsDate {
                    return lhsDate < rhsDate
                } else if lhsDate != nil {
                    return true
                } else if rhsDate != nil {
                    return false
                } else {
                    return lhs.lastPathComponent < rhs.lastPathComponent
                }
            }
            var previewFiles: [PreviewFile] = []
            for (index, fileURL) in filesCopy.enumerated() {
                let newName = generateNewName(for: fileURL, at: index)
                previewFiles.append(PreviewFile(sourceURL: fileURL, newName: newName))
                
                await MainActor.run {
                    progress = Double(index + 1) / Double(filesCopy.count)
                    processingStage = "Scanning files..."
                }
            }
            
            await MainActor.run {
                self.previewFiles = previewFiles
                self.previewGenerated = true
                self.isProcessing = false
                self.processingStage = ""
            }
        }
    }
    
    func startRenaming() {
        guard !previewFiles.isEmpty else { return }
        
        let previewFilesCopy = previewFiles
        currentOperation = Task {
            await MainActor.run {
                isProcessing = true
                progress = 0
                processingStage = "Renaming files..."
            }
            // Only process files that pass shouldProcessFile
            let filesToRename = previewFilesCopy.filter { shouldProcessFile($0.sourceURL) }
            // Sort files by EXIF date, then creation date, then filename
            let filesToRenameCopy = filesToRename.sorted { lhs, rhs in
                let lhsDate = getBestDate(for: lhs.sourceURL)
                let rhsDate = getBestDate(for: rhs.sourceURL)
                if let lhsDate = lhsDate, let rhsDate = rhsDate {
                    return lhsDate < rhsDate
                } else if lhsDate != nil {
                    return true
                } else if rhsDate != nil {
                    return false
                } else {
                    return lhs.sourceURL.lastPathComponent < rhs.sourceURL.lastPathComponent
                }
            }
            let fileManager = FileManager.default
            for (index, previewFile) in filesToRenameCopy.enumerated() {
                let destinationURL: URL
                if renameInPlace {
                    destinationURL = previewFile.sourceURL.deletingLastPathComponent().appendingPathComponent(previewFile.newName)
                } else {
                    guard let outputURL = outputURL else { continue }
                    destinationURL = outputURL.appendingPathComponent(previewFile.newName)
                }
                print("Copying from:", previewFile.sourceURL.path)
                print("To:", destinationURL.path)
                print("Source exists:", fileManager.fileExists(atPath: previewFile.sourceURL.path))
                if !renameInPlace, let outputURL = outputURL {
                    print("Output dir exists:", fileManager.fileExists(atPath: outputURL.path))
                }
                do {
                    if renameInPlace {
                        try fileManager.moveItem(at: previewFile.sourceURL, to: destinationURL)
                    } else {
                        try fileManager.copyItem(at: previewFile.sourceURL, to: destinationURL)
                    }
                    print("Copied file exists at output:", fileManager.fileExists(atPath: destinationURL.path))
                } catch {
                    print("Error renaming/copying file:", error)
                }
                await MainActor.run {
                    progress = Double(index + 1) / Double(filesToRenameCopy.count)
                    processingStage = "Renaming files..."
                }
            }
            
            await MainActor.run {
                isProcessing = false
                previewFiles = []
                previewGenerated = false
                processingStage = ""
            }
        }
    }
    
    func cancelRenaming() {
        currentOperation?.cancel()
        isProcessing = false
    }
    
    func resetSourceURLIfNeeded() {
        if shouldResetSourceURL {
            sourceURL = nil
            shouldResetSourceURL = false
        }
    }
    
    // MARK: - Private Methods
    public func generateNewName(for fileURL: URL, at index: Int) -> String {
        let fileExtension = fileURL.pathExtension
        if sequentialMode {
            let number = startNumber + index
            let paddedNumber = String(format: "%0\(numberPadding)d", number)
            // Always insert underscore if not present
            let base = basename.hasSuffix("_") ? basename : basename + "_"
            return "\(base)\(paddedNumber).\(fileExtension)"
        } else {
            switch nonSequentialPattern {
            case .dateTime:
                if let date = getFileDate(fileURL) {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyyMMdd_HHmmss"
                    return "\(formatter.string(from: date)).\(fileExtension)"
                }
                return "\(Date().timeIntervalSince1970).\(fileExtension)"
            case .random:
                let randomString = String((0..<randomNameLength).map { _ in
                    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()!
                })
                return "\(randomString).\(fileExtension)"
            }
        }
    }
    
    public func getFileDate(_ fileURL: URL) -> Date? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        return attributes?[.modificationDate] as? Date
    }
    
    public func shouldProcessFile(_ url: URL) -> Bool {
        // Skip directories, only process files
        do {
            let resourceValues = try url.resourceValues(forKeys: [.isRegularFileKey, .isHiddenKey, .nameKey])
            guard let isRegularFile = resourceValues.isRegularFile, isRegularFile else {
                return false
            }
            // Skip dot files and hidden files
            if let name = resourceValues.name, name.hasPrefix(".") { return false }
            if resourceValues.isHidden == true { return false }
        } catch {
            return false
        }
        // If no extension filter is specified, include all files
        if extensionFilter.isEmpty {
            return true
        }
        // Otherwise, match the extension
        let fileExtension = url.pathExtension.lowercased()
        return fileExtension.lowercased() == extensionFilter.lowercased()
    }
    
    // SEQUENTIAL NAMING LOGIC
    private func generateNewSequentialName(currentNumber: Int, fileURL: URL) -> String {
        let paddedNumber = String(format: "%0\(numberPadding)d", currentNumber)
        let fileExtension = fileURL.pathExtension
        
        // Add underscore if basename doesn't end with one
        let separator = basename.hasSuffix("_") ? "" : "_"
        return "\(basename)\(separator)\(paddedNumber).\(fileExtension)"
    }
    
    // NON-SEQUENTIAL NAMING LOGIC
    private func generateNewNonSequentialName(fileURL: URL) -> String {
        let fileExtension = fileURL.pathExtension
        
        switch nonSequentialPattern {
        case .dateTime:
            return generateDateTimeFileName(fileURL: fileURL)
        case .random:
            return generateRandomFileName(fileExtension: fileExtension)
        }
    }
    
    private func generateDateTimeFileName(fileURL: URL) -> String {
        let fileExtension = fileURL.pathExtension
        let dateTimeString = getDateTimeString(from: fileURL)
        return "\(dateTimeString).\(fileExtension)"
    }
    
    private func generateRandomFileName(fileExtension: String) -> String {
        var randomName: String
        
        // Generate a unique random name
        repeat {
            randomName = generateRandomString(length: randomNameLength)
        } while usedRandomNames.contains(randomName)
        
        // Add to used names to ensure uniqueness
        usedRandomNames.insert(randomName)
        
        return "\(randomName).\(fileExtension)"
    }
    
    private func generateRandomString(length: Int) -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in chars.randomElement()! })
    }
    
    private func getDateTimeString(from fileURL: URL) -> String {
        let date: Date
        
        // Try to get date from EXIF data first
        if let exifDate = getExifDate(from: fileURL) {
            date = exifDate
        }
        // Try file modification date next
        else if let modDate = getFileModificationDate(from: fileURL) {
            date = modDate
        }
        // Fall back to current date/time
        else {
            date = Date()
        }
        
        // Format as YYYY-MM-DD-HHMMSS-MSS
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let baseString = formatter.string(from: date)
        
        // Add milliseconds for uniqueness
        let milliseconds = Int((date.timeIntervalSince1970.truncatingRemainder(dividingBy: 1)) * 1000)
        return "\(baseString)-\(String(format: "%03d", milliseconds))"
    }
    
    private func getFileModificationDate(from fileURL: URL) -> Date? {
        do {
            let resourceValues = try fileURL.resourceValues(forKeys: [.contentModificationDateKey])
            return resourceValues.contentModificationDate
        } catch {
            print("Error reading file modification date: \(error)")
            return nil
        }
    }
    
    private func getDatePrefix(from fileURL: URL) -> String {
        // Try to get date from EXIF data first (for images)
        if let exifDate = getExifDate(from: fileURL) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd"
            return formatter.string(from: exifDate)
        }
        
        // Try to get file modification date as fallback
        if let modificationDate = getFileModificationDate(from: fileURL) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd"
            return formatter.string(from: modificationDate)
        }
        
        // Use current date as final fallback
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: Date())
    }
    
    func getExifDate(from fileURL: URL) -> Date? {
        // Check if the file is an image type
        let fileExtension = fileURL.pathExtension.lowercased()
        let imageExtensions = ["jpg", "jpeg", "tiff", "heic", "png", "raw", "cr2", "crw", "nef", "arw"]
        
        if !imageExtensions.contains(fileExtension) {
            return nil
        }
        
        guard let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else {
            return nil
        }
        
        guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            return nil
        }
        
        // Try to get EXIF dictionary
        guard let exifDict = imageProperties["{Exif}"] as? [String: Any] else {
            // If no EXIF, try to get the creation date from the main properties
            if let tiffDict = imageProperties["{TIFF}"] as? [String: Any],
               let dateTimeStr = tiffDict["DateTime"] as? String {
                return parseExifDate(dateTimeStr)
            }
            
            return nil
        }
        
        // Check for DateTimeOriginal first (when the image was taken)
        if let dateTimeOriginal = exifDict["DateTimeOriginal"] as? String {
            return parseExifDate(dateTimeOriginal)
        }
        
        // Fallback to DateTime
        if let dateTime = exifDict["DateTime"] as? String {
            return parseExifDate(dateTime)
        }
        
        return nil
    }
    
    private func parseExifDate(_ dateString: String) -> Date? {
        // EXIF dates are typically in format: "YYYY:MM:DD HH:MM:SS"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: dateString)
    }
    
    // Helper to get best date for sorting
    private func getBestDate(for fileURL: URL) -> Date? {
        if let exif = getExifDate(from: fileURL) {
            return exif
        }
        if let creation = getFileCreationDate(fileURL) {
            return creation
        }
        return nil
    }
    
    func getFileCreationDate(_ fileURL: URL) -> Date? {
        do {
            let resourceValues = try fileURL.resourceValues(forKeys: [.creationDateKey])
            return resourceValues.creationDate
        } catch {
            return nil
        }
    }
    
    // Also handle picker-based folder selection
    func setSourceURLFromPicker(_ url: URL) {
        self.sourceURL = url
        self.suggestBasenameFromSourceURL()
        self.previewFiles = []
        self.previewGenerated = false
    }
    
    private func suggestBasenameFromSourceURL() {
        guard let url = sourceURL else { return }
        let folderName = url.lastPathComponent
        // Remove trailing numbers/underscores if present
        let base = folderName.replacingOccurrences(of: #"[_\d]+$"#, with: "", options: .regularExpression)
        self.basename = base
    }
    
    public func performRename() async {
        // Implementation of performRename method
    }
    
    public func outputFileExists(named name: String) -> Bool {
        guard let outputURL = outputURL else { return false }
        let path = outputURL.appendingPathComponent(name).resolvingSymlinksInPath().path
        return FileManager.default.fileExists(atPath: path)
    }
} 
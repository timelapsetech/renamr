import SwiftUI
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum NonSequentialPattern: String, CaseIterable {
    case dateTime
    case random
    
    var displayName: String {
        switch self {
        case .dateTime: return "Date & Time"
        case .random: return "Random"
        }
    }
}

class RenameViewModel: ObservableObject {
    @Published var sourceURL: URL?
    @Published var outputURL: URL?
    @Published var basename: String = ""
    @Published var numberPadding: Int = 4
    @Published var startNumber: Int = 1
    @Published var renameInPlace: Bool = true
    @Published var isProcessing: Bool = false
    @Published var progress: Double = 0
    @Published var isSourceTargeted: Bool = false
    @Published var isOutputTargeted: Bool = false
    @Published var extensionFilter: String = ""
    @Published var shouldResetSourceURL: Bool = false
    
    // Rename mode
    @Published var sequentialMode: Bool = true
    
    // Non-sequential options
    @Published var nonSequentialPattern: NonSequentialPattern = .dateTime
    @Published var randomNameLength: Int = 8
    
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
    
    init() {
        // Set Manual as the default option
        selectPreset("Manual")
    }
    
    var canStartRenaming: Bool {
        sourceURL != nil && (sequentialMode ? !basename.isEmpty : true) && (renameInPlace || outputURL != nil)
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
        
        if provider.hasItemConformingToTypeIdentifier("public.file-url") {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (urlData, error) in
                DispatchQueue.main.async {
                    if let urlData = urlData as? Data,
                       let url = NSURL(dataRepresentation: urlData, relativeTo: nil) as URL? {
                        self.sourceURL = url
                        // Set default basename from folder name
                        self.setDefaultBasename(from: url)
                    }
                }
            }
            return true
        }
        return false
    }
    
    private func setDefaultBasename(from url: URL) {
        let folderName = url.lastPathComponent
        if let underscoreIndex = folderName.firstIndex(of: "_") {
            // If underscore found, use everything before it
            basename = String(folderName[..<underscoreIndex])
        } else {
            // If no underscore, use the whole folder name
            basename = folderName
        }
    }
    
    func handleOutputDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        if provider.hasItemConformingToTypeIdentifier("public.file-url") {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (urlData, error) in
                DispatchQueue.main.async {
                    if let urlData = urlData as? Data,
                       let url = NSURL(dataRepresentation: urlData, relativeTo: nil) as URL? {
                        self.outputURL = url
                    }
                }
            }
            return true
        }
        return false
    }
    
    func startRenaming() {
        guard let sourceURL = sourceURL else { return }
        
        isProcessing = true
        progress = 0
        usedRandomNames.removeAll()
        
        currentOperation = Task {
            do {
                let fileManager = FileManager.default
                let enumerator1 = fileManager.enumerator(at: sourceURL,
                                                      includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
                                                      options: [.skipsHiddenFiles])
                
                var currentNumber = startNumber
                var totalFiles = 0
                var processedFiles = 0
                
                // New code: collect all eligible files with their dates for sorting
                var filesToProcess: [(url: URL, date: Date)] = []
                
                // First collect all files to process
                while let fileURL = enumerator1?.nextObject() as? URL {
                    if shouldProcessFile(fileURL) {
                        // Get file date (EXIF date or modification date)
                        let fileDate = getEffectiveDate(from: fileURL)
                        filesToProcess.append((fileURL, fileDate))
                        totalFiles += 1
                    }
                }
                
                if totalFiles == 0 {
                    await MainActor.run {
                        isProcessing = false
                        progress = 0
                        shouldResetSourceURL = true
                    }
                    return
                }
                
                // Sort files by date (oldest first) when in sequential mode
                if sequentialMode {
                    filesToProcess.sort { $0.date < $1.date }
                }
                
                // Process files in the sorted order
                for (index, fileInfo) in filesToProcess.enumerated() {
                    if Task.isCancelled { break }
                    
                    let fileURL = fileInfo.url
                    let newName: String
                    
                    if sequentialMode {
                        newName = generateNewSequentialName(currentNumber: currentNumber, fileURL: fileURL)
                    } else {
                        newName = generateNewNonSequentialName(fileURL: fileURL)
                    }
                    
                    if renameInPlace {
                        try fileManager.moveItem(at: fileURL,
                                               to: fileURL.deletingLastPathComponent().appendingPathComponent(newName))
                    } else if let outputURL = outputURL {
                        let relativePath = fileURL.path.replacingOccurrences(of: sourceURL.path, with: "")
                        let destinationURL = outputURL.appendingPathComponent(relativePath)
                        try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(),
                                                      withIntermediateDirectories: true)
                        try fileManager.copyItem(at: fileURL, to: destinationURL.deletingLastPathComponent().appendingPathComponent(newName))
                    }
                    
                    currentNumber += 1
                    processedFiles += 1
                    
                    let progressValue = min(Double(processedFiles) / Double(totalFiles), 1.0)
                    await MainActor.run {
                        progress = progressValue
                    }
                }
            } catch {
                print("Error during renaming: \(error)")
            }
            
            await MainActor.run {
                isProcessing = false
                progress = 0
                shouldResetSourceURL = true
            }
        }
    }
    
    func cancelRenaming() {
        currentOperation?.cancel()
        isProcessing = false
        progress = 0
    }
    
    private func shouldProcessFile(_ url: URL) -> Bool {
        // Skip directories, only process files
        do {
            let resourceValues = try url.resourceValues(forKeys: [.isRegularFileKey])
            guard let isRegularFile = resourceValues.isRegularFile, isRegularFile else {
                return false
            }
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
    
    private func getExifDate(from fileURL: URL) -> Date? {
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
    
    func resetSourceURLIfNeeded() {
        if shouldResetSourceURL {
            sourceURL = nil
            shouldResetSourceURL = false
        }
    }
    
    // Add a helper method to get the effective date for a file
    private func getEffectiveDate(from fileURL: URL) -> Date {
        // Try to get date from EXIF data first (for images)
        if let exifDate = getExifDate(from: fileURL) {
            return exifDate
        }
        
        // Try to get file modification date as fallback
        if let modificationDate = getFileModificationDate(from: fileURL) {
            return modificationDate
        }
        
        // Use current date as final fallback
        return Date()
    }
} 
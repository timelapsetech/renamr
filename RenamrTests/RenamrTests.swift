//
//  RenamrTests.swift
//  RenamrTests
//
//  Created by David Klee on 5/25/25.
//

import Testing
import XCTest
@testable import Renamr

struct RenamrTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

}

final class RenameViewModelTests: XCTestCase {
    var tempDir: URL!
    var outputDir: URL!
    var viewModel: RenameViewModel!

    override func setUpWithError() throws {
        let base = URL(fileURLWithPath: "/tmp/renamr-test", isDirectory: true)
        tempDir = base.appendingPathComponent("source")
        outputDir = base.appendingPathComponent("output")
        try? FileManager.default.removeItem(at: tempDir)
        try? FileManager.default.removeItem(at: outputDir)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        viewModel = RenameViewModel()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        try? FileManager.default.removeItem(at: outputDir)
    }

    func createFile(named name: String, contents: Data = Data(), date: Date? = nil) -> URL {
        let url = tempDir.appendingPathComponent(name)
        FileManager.default.createFile(atPath: url.path, contents: contents)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "File should exist after creation: \(url.path)")
        if let date = date {
            try? FileManager.default.setAttributes([.modificationDate: date, .creationDate: date], ofItemAtPath: url.path)
        }
        return url
    }

    func testSequentialRenamingOrderAndNames() throws {
        // Create files with different dates
        let date1 = Date(timeIntervalSince1970: 1000)
        let date2 = Date(timeIntervalSince1970: 2000)
        _ = createFile(named: "A.jpg", date: date2)
        _ = createFile(named: "B.jpg", date: date1)
        viewModel.sourceURL = tempDir
        viewModel.sequentialMode = true
        viewModel.basename = "Test"
        viewModel.numberPadding = 3
        viewModel.startNumber = 1
        viewModel.generatePreview()
        // Wait for async preview
        let exp = expectation(description: "Preview")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { exp.fulfill() }
        wait(for: [exp], timeout: 2)
        // Should be sorted by date (fileB, fileA)
        XCTAssertEqual(viewModel.previewFiles.map { $0.sourceURL.lastPathComponent }, ["B.jpg", "A.jpg"])
        XCTAssertEqual(viewModel.previewFiles.map { $0.newName }, ["Test_001.jpg", "Test_002.jpg"])
    }

    func testCopyVsMove() async throws {
        let file = createFile(named: "A.jpg")
        viewModel.sourceURL = tempDir
        viewModel.outputURL = outputDir
        viewModel.sequentialMode = true
        viewModel.renameInPlace = false
        viewModel.extensionFilter = "" // Ensure no filter
        print("Temp dir contents before preview:", try! FileManager.default.contentsOfDirectory(atPath: tempDir.path))
        viewModel.generatePreview()
        let exp = expectation(description: "Preview")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { exp.fulfill() }
        await fulfillment(of: [exp], timeout: 2)
        print("Preview files:", viewModel.previewFiles.map { $0.sourceURL.lastPathComponent })
        print("Temp dir contents before renaming:", try! FileManager.default.contentsOfDirectory(atPath: tempDir.path))
        print("Output dir contents before renaming:", try! FileManager.default.contentsOfDirectory(atPath: outputDir.path))
        let newName = viewModel.previewFiles.first?.newName ?? "_0001.jpg"
        let expectedOutputPath = outputDir.appendingPathComponent(newName).path
        let resolvedOutputPath = URL(fileURLWithPath: expectedOutputPath).resolvingSymlinksInPath().path
        print("Using newName for assertion:", newName)
        print("Test expects output file at:", expectedOutputPath)
        print("Resolved output path for assertion:", resolvedOutputPath)
        await viewModel.startRenaming()
        try await Task.sleep(nanoseconds: 500_000_000) // Wait for file system sync
        print("Temp dir contents after renaming:", try! FileManager.default.contentsOfDirectory(atPath: tempDir.path))
        print("Output dir contents after renaming:", try! FileManager.default.contentsOfDirectory(atPath: outputDir.path))
        // File should exist in both source and output
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        XCTAssertTrue(viewModel.outputFileExists(named: newName))
    }

    func testHiddenAndDotFilesIgnored() throws {
        _ = createFile(named: ".DS_Store")
        _ = createFile(named: "visible.txt")
        viewModel.sourceURL = tempDir
        viewModel.sequentialMode = true
        viewModel.generatePreview()
        let exp = expectation(description: "Preview")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { exp.fulfill() }
        wait(for: [exp], timeout: 2)
        XCTAssertEqual(viewModel.previewFiles.count, 1)
        XCTAssertEqual(viewModel.previewFiles.first?.sourceURL.lastPathComponent, "visible.txt")
    }

    // Add more tests for extension filtering, random naming, EXIF ordering, etc.
}

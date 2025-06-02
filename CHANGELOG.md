# Changelog

All notable changes to the Renamr application will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.3] - 2024-06-02
### Added
- Source directory is now automatically cleared after renaming completes

### Changed
- Optimized file scanning and renaming operations for better performance
- Implemented batch processing to reduce UI updates
- Improved progress reporting during file operations
- Added memory optimizations for handling large directories

## [1.2.2] - 2024-05-26
### Added/Changed
- UI improvements: clearer grouping for sequential/non-sequential options, improved file extension filter labeling
- Date-based renaming now uses EXIF date, then file creation date only
- Fixed Swift 6 warnings and async test compatibility
- Minor bug fixes and code cleanup

## [1.2.1] - 2024-05-25
### Changed
- Refactored sidebar and file preview display: the preview is now a collapsible right panel, and the config section is always visible on the left.

## [1.2] - 2024-05-25
### Added
- Preview table, which now shows file date/time used for sorting, and indicates if EXIF was used.
- Alternating row backgrounds (zebra striping) for better readability.
- Real-time progress bar and status for both scanning and renaming phases.
- Quick Look preview for files (via eye icon or spacebar on button).
- Clickable drop zones for both source and output directories (opens folder picker or supports drag-and-drop).
- Output files are now copied (not moved) when 'rename in place' is unchecked.
- Files are always renamed in oldest-first order (EXIF date, then creation date, then filename).
- Table now shows file size and sequential number.
- UI/UX improvements for macOS look and feel.

### Fixed
- Fixed hidden/dot files always being ignored.

### Changed
- Refactored code for better SwiftUI and macOS compatibility.
## [1.1.1] - 2024-05-16

### Changed
- Removed photos library access requirement
- Improved security by removing unnecessary entitlements


## [1.1.0] - 2024-05-16

### Added
- Automatic underscore insertion between basename and number
- Automatic basename population from source folder name
- New application icon

### Changed
- Simplified renaming logic to use manual basename entry
- Improved window sizing and layout
- Removed preset options for more straightforward usage

### Fixed
- Removed unnecessary gray space in application window
- Fixed inconsistent date-based naming behavior

## [1.0.0] - 2024-05-16

### Added
- Initial release of Renamr
- Sequential numbering with configurable padding and start number
- Date-based naming with EXIF data extraction
- Random name generation option
- Date-ordering for sequential renaming (oldest to newest)
- Drag and drop interface for source and output directories
- File extension filtering
- Rename in place or to separate output directory
- Dark/Light mode support
- Progress tracking
- Custom application icon

### Known Issues
- None at this time 
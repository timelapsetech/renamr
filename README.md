# Renamr

A modern macOS application for batch file renaming with a focus on images and other files. Renamr features a clean, intuitive interface and powerful renaming capabilities.

![Renamr Application](Resources/app_screenshot.png)

## Features

- **Clean, Modern Interface**: Drag-and-drop UI with native macOS controls
- **Sequential Renaming**: Number files in sequence with customizable base names and padding
- **Smart Date Ordering**: When using sequential mode, files are automatically ordered by date (EXIF date for images, then file modification date)
- **Non-Sequential Options**:
  - Date & Time based naming (using EXIF data when available)
  - Random unique name generation
- **File Management**:
  - Rename in place or to a separate output directory
  - File extension filtering
  - Support for all file types with special handling for images
- **Preset Templates**: Quick access to common naming patterns
- **Progress Tracking**: Real-time progress monitoring for large batches
- **Dark/Light Mode Support**: Automatically adapts to your macOS appearance settings

## Requirements

- macOS 12.0 or later
- 64-bit processor
- Permissions to access files/folders you want to rename

## Installation

1. Download the latest release from the [Releases](https://github.com/your-username/renamr/releases) page
2. Drag Renamr.app to your Applications folder
3. Launch from Applications or Spotlight

## Usage

### Basic Renaming
1. Drag and drop a source folder onto the Source Directory zone
2. Choose between sequential or non-sequential renaming
3. Configure your renaming options
4. Click "Start Renaming"

### Sequential Renaming
- Enter a base name (e.g., "Photo_")
- Set the number padding (e.g., 3 digits: 001, 002, etc.)
- Choose a starting number
- Files will be processed in date order (oldest first)

### Non-Sequential Renaming
- **Date & Time**: Names files based on their capture date or modification date
- **Random**: Generates unique random names with configurable length

### Output Options
- Toggle "Rename in place" to modify files in their original location
- When unchecked, drag a destination folder to copy renamed files to that location

## Development

### Setup
1. Clone the repository
2. Open `Renamr.xcodeproj` in Xcode
3. Build and run the project

### Requirements
- Xcode 14.0 or later
- Swift 5.5+

## Credits

- Icon design: Time Lapse Technologies
- Developer: Time Lapse Technologies

## License

Copyright © 2024 Time Lapse Technologies. All rights reserved. 
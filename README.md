# MacLimpador

A macOS system maintenance app built with SwiftUI. Helps users analyze and clean up disk space, manage installed applications, and monitor system resources.

## Requirements

- macOS 13.0+
- Xcode 15.0+

## Installation

### Homebrew

```bash
brew install --cask maclimpador
```

### Manual

1. Download the latest release from [GitHub Releases](https://github.com/Juan-Severiano/MacLimpador/releases)
2. Open the `.app` bundle
3. Drag to Applications

## Features

### Storage Analysis
- Scan and identify large files
- Detect orphaned files from uninstalled apps
- Homebrew package management
- System cache cleanup

### System Cleanup
- Empty Trash
- Clear system caches
- Remove temporary files

### App Management
- View installed applications
- Uninstall apps completely
- Remove app leftovers

### Monitoring
- Disk usage overview
- Menu bar quick access
- System stats dashboard

## Building

```bash
# Clone the repository
git clone https://github.com/Juan-Severiano/MacLimpador.git
cd MacLimpador

# Open in Xcode
open MacLimpador.xcodeproj

# Or build from command line
xcodebuild -project MacLimpador.xcodeproj -scheme MacLimpador -configuration Debug build
```

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the Creative Non-Commercial MIT License.
See [LICENSE](LICENSE) for details.

## Disclaimer

This tool modifies system files. Use at your own risk. Always backup important data before performing cleanup operations.
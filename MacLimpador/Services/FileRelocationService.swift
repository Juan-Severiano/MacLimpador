import Foundation
import AppKit

final class FileRelocationService {
    static let shared = FileRelocationService()
    
    private let fileManager = FileManager.default
    
    private init() {}
    
    func selectDestination() async -> URL? {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let panel = NSOpenPanel()
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                panel.allowsMultipleSelection = false
                panel.canCreateDirectories = true
                panel.title = "Select Destination"
                panel.message = "Choose where to move the selected files"
                
                let response = panel.runModal()
                
                if response == .OK {
                    continuation.resume(returning: panel.url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    func moveFiles(_ items: [ScanResult], to destination: URL, createSymlink: Bool = false) async throws -> (moved: Int, failed: Int, manifest: String) {
        var movedCount = 0
        var failedCount = 0
        var manifestContent = "# File Relocation Manifest\n"
        manifestContent += "# Generated: \(Date())\n\n"
        
        // Check available space
        let requiredSpace = items.reduce(0) { $0 + $1.size }
        guard let availableSpace = try? destination.resourceValues(forKeys: [.volumeAvailableCapacityKey]).volumeAvailableCapacity,
              Int64(availableSpace) > requiredSpace else {
            throw RelocationError.insufficientSpace
        }
        
        for item in items {
            let sourceURL = URL(fileURLWithPath: item.path)
            let fileName = sourceURL.lastPathComponent
            let destURL = destination.appendingPathComponent(fileName)
            
            do {
                // For directories, move recursively
                if item.isDirectory {
                    try fileManager.moveItem(at: sourceURL, to: destURL)
                } else {
                    // Check if destination file exists
                    if fileManager.fileExists(atPath: destURL.path) {
                        let newName = generateUniqueName(for: fileName, in: destination)
                        let newURL = destination.appendingPathComponent(newName)
                        try fileManager.moveItem(at: sourceURL, to: newURL)
                    } else {
                        try fileManager.moveItem(at: sourceURL, to: destURL)
                    }
                }
                
                movedCount += 1
                
                // Add to manifest
                manifestContent += "- \(item.path) -> \(destURL.path)\n"
                
                // Create symlink if requested
                if createSymlink {
                    let symlinkURL = sourceURL.deletingLastPathComponent().appendingPathComponent(fileName)
                    try fileManager.createSymbolicLink(atPath: symlinkURL.path, withDestinationPath: destURL.path)
                }
            } catch {
                failedCount += 1
                manifestContent += "# FAILED: \(item.path) - \(error.localizedDescription)\n"
            }
        }
        
        // Write manifest
        let manifestURL = destination.appendingPathComponent("MacLimpador_Manifest.md")
        try? manifestContent.write(to: manifestURL, atomically: true, encoding: .utf8)
        
        return (movedCount, failedCount, manifestURL.path)
    }
    
    func estimateTransferTime(for items: [ScanResult], to destination: URL) -> TimeInterval {
        // Estimate based on file size and typical transfer speeds
        let totalSize = items.reduce(0) { $0 + $1.size }
        
        // Assume ~100 MB/s for typical SSD
        let transferSpeed: Int64 = 100_000_000
        let seconds = Double(totalSize) / Double(transferSpeed)
        
        return seconds
    }
    
    func copyFiles(_ items: [ScanResult], to destination: URL) async throws -> (copied: Int, failed: Int) {
        var copiedCount = 0
        var failedCount = 0
        
        for item in items {
            let sourceURL = URL(fileURLWithPath: item.path)
            let fileName = sourceURL.lastPathComponent
            let destURL = destination.appendingPathComponent(fileName)
            
            do {
                if item.isDirectory {
                    try fileManager.copyItem(at: sourceURL, to: destURL)
                } else {
                    if fileManager.fileExists(atPath: destURL.path) {
                        let newName = generateUniqueName(for: fileName, in: destination)
                        let newURL = destination.appendingPathComponent(newName)
                        try fileManager.copyItem(at: sourceURL, to: newURL)
                    } else {
                        try fileManager.copyItem(at: sourceURL, to: destURL)
                    }
                }
                copiedCount += 1
            } catch {
                failedCount += 1
            }
        }
        
        return (copiedCount, failedCount)
    }
    
    private func generateUniqueName(for name: String, in directory: URL) -> String {
        let ext = (name as NSString).pathExtension
        let baseName = (name as NSString).deletingPathExtension
        
        var counter = 1
        var newName = name
        
        while fileManager.fileExists(atPath: directory.appendingPathComponent(newName).path) {
            if ext.isEmpty {
                newName = "\(baseName) (\(counter))"
            } else {
                newName = "\(baseName) (\(counter)).\(ext)"
            }
            counter += 1
        }
        
        return newName
    }
}

enum RelocationError: Error, LocalizedError {
    case insufficientSpace
    case permissionDenied
    case destinationNotWritable
    
    var errorDescription: String? {
        switch self {
        case .insufficientSpace:
            return "Insufficient space at destination"
        case .permissionDenied:
            return "Permission denied to access files"
        case .destinationNotWritable:
            return "Cannot write to destination"
        }
    }
}
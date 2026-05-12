import Foundation

struct HomebrewPackage: Identifiable {
    let id: String
    let name: String
    let version: String
    let size: Int64
    let isCask: Bool
    let isDependency: Bool
    let usedRecently: Bool
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

final class HomebrewService {
    static let shared = HomebrewService()
    
    private init() {}
    
    func listInstalledPackages() async -> [HomebrewPackage] {
        var packages: [HomebrewPackage] = []
        
        // Get formulae and casks in parallel for speed
        async let formulaeNames = runBrewCommand("list --formula")
        async let casksNames = runBrewCommand("list --cask")
        
        let allFormulae = (await formulaeNames)?.components(separatedBy: "\n").filter { !$0.isEmpty } ?? []
        let allCasks = (await casksNames)?.components(separatedBy: "\n").filter { !$0.isEmpty } ?? []
        
        await withTaskGroup(of: HomebrewPackage?.self) { group in
            for name in allFormulae {
                group.addTask { await self.getPackageInfo(name: name, isCask: false) }
            }
            for name in allCasks {
                group.addTask { await self.getPackageInfo(name: name, isCask: true) }
            }
            
            for await package in group {
                if let pkg = package {
                    packages.append(pkg)
                }
            }
        }
        
        return packages.sorted { $0.size > $1.size }
    }
    
    func getPackagesAsScanResults() async -> [ScanResult] {
        let pkgs = await listInstalledPackages()
        return pkgs.map { pkg in
            ScanResult(
                path: pkg.isCask ? "/Applications/\(pkg.name).app" : "brew/\(pkg.name)",
                name: pkg.name,
                size: pkg.size,
                category: .package,
                confidence: 0.2, // Packages are usually kept unless the user wants to uninstall
                reason: "Installed via Homebrew (\(pkg.version))",
                isDirectory: pkg.isCask
            )
        }
    }
    
    private func getPackageInfo(name: String, isCask: Bool) async -> HomebrewPackage {
        let size = await getPackageSize(name: name, isCask: isCask)
        let version = await getPackageVersion(name: name, isCask: isCask)
        let isDependency = await isPackageDependency(name: name)
        let usedRecently = await wasPackageUsedRecently(name: name)
        
        return HomebrewPackage(
            id: name,
            name: name,
            version: version,
            size: size,
            isCask: isCask,
            isDependency: isDependency,
            usedRecently: usedRecently
        )
    }
    
    private func getPackageSize(name: String, isCask: Bool) async -> Int64 {
        let prefix = isCask ? "--cask " : ""
        guard let output = await runBrewCommand("info \(prefix)\(name)") else { return 0 }
        
        // Parse size from output
        let lines = output.components(separatedBy: "\n")
        for line in lines where line.contains("B") && line.contains(name) {
            // Try to extract size
            if let match = line.range(of: #"(\d+\.?\d*\s*[KMGT]B)"#, options: .regularExpression) {
                let sizeStr = String(line[match])
                return parseSize(sizeStr)
            }
        }
        
        return 0
    }
    
    private func getPackageVersion(name: String, isCask: Bool) async -> String {
        let prefix = isCask ? "--cask " : ""
        guard let output = await runBrewCommand("info \(prefix)\(name)") else { return "unknown" }
        
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            if line.contains(name) && line.contains(":") {
                let parts = line.components(separatedBy: ":")
                if parts.count > 1 {
                    return parts[1].trimmingCharacters(in: .whitespaces)
                }
            }
        }
        
        return "unknown"
    }
    
    private func isPackageDependency(name: String) async -> Bool {
        guard let leaves = await runBrewCommand("leaves") else { return false }
        return !leaves.contains(name)
    }
    
    private func wasPackageUsedRecently(name: String) async -> Bool {
        let binPath = "/usr/local/bin/\(name)"
        let altBinPath = "/opt/homebrew/bin/\(name)"
        
        for path in [binPath, altBinPath] {
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
                  let accessDate = attributes[.modificationDate] as? Date else {
                continue
            }
            
            let daysSince = Calendar.current.dateComponents([.day], from: accessDate, to: Date()).day ?? 999
            return daysSince < 30
        }
        
        return false
    }
    
    func getCleanupCandidates() async -> [(name: String, size: String)] {
        guard let output = await runBrewCommand("cleanup --dry-run") else {
            return []
        }
        
        var candidates: [(String, String)] = []
        
        for line in output.components(separatedBy: "\n") {
            if line.contains("Would remove") {
                let parts = line.components(separatedBy: "Would remove")
                if parts.count > 1 {
                    let item = parts[1].trimmingCharacters(in: .whitespaces)
                    // Parse size if available
                    candidates.append((item, "Cleanup candidate"))
                }
            }
        }
        
        return candidates
    }
    
    func runCleanup() async throws -> String {
        guard let output = await runBrewCommand("cleanup -v") else {
            throw HomebrewError.cleanupFailed
        }
        return output
    }
    
    func removePackage(_ package: HomebrewPackage) async throws {
        let prefix = package.isCask ? "uninstall --cask " : "uninstall "
        let command = "\(prefix)\(package.name)"
        
        guard let output = await runBrewCommand(command) else {
            throw HomebrewError.removeFailed(package.name)
        }
        
        if output.contains("Error") || output.contains("error") {
            throw HomebrewError.removeFailed(package.name)
        }
    }
    
    private func runBrewCommand(_ arguments: String) async -> String? {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/local/bin/brew")
            process.arguments = arguments.components(separatedBy: " ")
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: output.isEmpty ? nil : output)
            } catch {
                // Try alternative brew path
                let altProcess = Process()
                altProcess.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")
                altProcess.arguments = arguments.components(separatedBy: " ")
                
                let altPipe = Pipe()
                altProcess.standardOutput = altPipe
                altProcess.standardError = altPipe
                
                do {
                    try altProcess.run()
                    altProcess.waitUntilExit()
                    
                    let data = altPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: output.isEmpty ? nil : output)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func parseSize(_ sizeStr: String) -> Int64 {
        let cleaned = sizeStr.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "")
        
        var multiplier: Int64 = 1
        if cleaned.contains("GB") || cleaned.contains("G") {
            multiplier = 1_000_000_000
        } else if cleaned.contains("MB") || cleaned.contains("M") {
            multiplier = 1_000_000
        } else if cleaned.contains("KB") || cleaned.contains("K") {
            multiplier = 1_000
        }
        
        let numberStr = cleaned.replacingOccurrences(of: #"[A-Za-z]"#, with: "", options: .regularExpression)
        guard let number = Double(numberStr) else { return 0 }
        
        return Int64(number) * multiplier
    }
}

enum HomebrewError: Error, LocalizedError {
    case cleanupFailed
    case removeFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .cleanupFailed:
            return "Homebrew cleanup failed"
        case .removeFailed(let name):
            return "Failed to remove package: \(name)"
        }
    }
}
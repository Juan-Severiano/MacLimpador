import Foundation

actor SmartScanService {
    static let shared = SmartScanService()
    private init() {}

    private let fm = FileManager.default
    private var home: URL { fm.homeDirectoryForCurrentUser }

    func scan() -> AsyncStream<SmartScanProgress> {
        AsyncStream { continuation in
            Task {
                let steps: [(SmartScanCategory, String, () async -> SmartScanCategoryResult)] = [
                    (.systemJunk,         "Escaneando lixo do sistema...",   { await self.scanSystemJunk() }),
                    (.mailAttachments,    "Escaneando anexos de e-mail...",  { await self.scanMailAttachments() }),
                    (.trashBins,          "Escaneando lixeiras...",           { await self.scanTrashBins() }),
                    (.universalBinaries,  "Escaneando binários extra...",    { await self.scanUniversalBinaries() }),
                ]

                let total = Double(steps.count)
                for (index, (_, stepName, scanner)) in steps.enumerated() {
                    let result = await scanner()
                    let progress = Double(index + 1) / total
                    continuation.yield(SmartScanProgress(
                        categoryResult: result,
                        progress: progress,
                        currentStep: stepName
                    ))
                }
                continuation.finish()
            }
        }
    }

    // MARK: - System Junk

    private func scanSystemJunk() async -> SmartScanCategoryResult {
        var subcategories: [SmartScanSubcategory] = []

        // Xcode Junk (pode ser muito grande)
        let xcodeJunk = await scanXcodeJunk()
        if xcodeJunk.totalSize > 0 { subcategories.append(xcodeJunk) }

        // User Cache Files
        let userCache = scanTopLevelDirectory(
            at: home.appendingPathComponent("Library/Caches"),
            name: "Cache do Usuário",
            icon: "person.fill.viewfinder"
        )
        if userCache.totalSize > 0 { subcategories.append(userCache) }

        // System Cache Files
        let systemCache = scanTopLevelDirectory(
            at: URL(fileURLWithPath: "/Library/Caches"),
            name: "Cache do Sistema",
            icon: "gearshape.fill"
        )
        if systemCache.totalSize > 0 { subcategories.append(systemCache) }

        // User Log Files
        let userLogs = scanTopLevelDirectory(
            at: home.appendingPathComponent("Library/Logs"),
            name: "Logs do Usuário",
            icon: "doc.text.fill"
        )
        if userLogs.totalSize > 0 { subcategories.append(userLogs) }

        // System Log Files
        let systemLogs = scanTopLevelDirectory(
            at: URL(fileURLWithPath: "/Library/Logs"),
            name: "Logs do Sistema",
            icon: "doc.text.fill"
        )
        if systemLogs.totalSize > 0 { subcategories.append(systemLogs) }

        // Language Files
        let langFiles = scanLanguageFiles()
        if langFiles.totalSize > 0 { subcategories.append(langFiles) }

        return SmartScanCategoryResult(category: .systemJunk, subcategories: subcategories)
    }

    private func scanXcodeJunk() async -> SmartScanSubcategory {
        var items: [SmartScanItem] = []

        let xcodePaths: [(String, String)] = [
            ("Library/Developer/Xcode/DerivedData",       "Xcode DerivedData"),
            ("Library/Developer/Xcode/Archives",          "Xcode Archives"),
            ("Library/Developer/Xcode/DocumentationCache","Xcode Documentation Cache"),
            ("Library/Caches/com.apple.dt.Xcode",         "Xcode Caches"),
        ]

        for (relativePath, name) in xcodePaths {
            let url = home.appendingPathComponent(relativePath)
            guard fm.fileExists(atPath: url.path) else { continue }
            let size = calculateSize(at: url)
            if size > 0 {
                items.append(SmartScanItem(path: url, name: name, size: size))
            }
        }

        // Simulator Runtimes — múltiplas localizações possíveis
        let simPaths: [URL] = [
            URL(fileURLWithPath: "/Library/Developer/CoreSimulator/Cryptex"),
            home.appendingPathComponent("Library/Developer/CoreSimulator/Profiles/Runtimes"),
            home.appendingPathComponent("Library/Developer/CoreSimulator/Volumes"),
        ]
        var addedSimulator = false
        for simPath in simPaths {
            guard !addedSimulator, fm.fileExists(atPath: simPath.path) else { continue }
            let size = calculateSize(at: simPath)
            if size > 0 {
                items.append(SmartScanItem(path: simPath, name: "Xcode Simulator Runtimes", size: size))
                addedSimulator = true
            }
        }

        let total = items.reduce(0) { $0 + $1.size }
        return SmartScanSubcategory(name: "Lixo do Xcode", iconName: "hammer.fill", items: items, totalSize: total)
    }

    private func scanTopLevelDirectory(at url: URL, name: String, icon: String) -> SmartScanSubcategory {
        guard fm.fileExists(atPath: url.path),
              let contents = try? fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
              ) else {
            return SmartScanSubcategory(name: name, iconName: icon, items: [], totalSize: 0)
        }

        var items: [SmartScanItem] = []
        for itemURL in contents {
            let size = calculateSize(at: itemURL)
            if size > 0 {
                items.append(SmartScanItem(path: itemURL, name: itemURL.lastPathComponent, size: size))
            }
        }

        let total = items.reduce(0) { $0 + $1.size }
        return SmartScanSubcategory(name: name, iconName: icon, items: items, totalSize: total)
    }

    private func scanLanguageFiles() -> SmartScanSubcategory {
        let preferred = Set(
            Locale.preferredLanguages
                .compactMap { Locale(identifier: $0).language.languageCode?.identifier }
        )
        let alwaysKeep = Set(["en", "pt", "Base"])

        var items: [SmartScanItem] = []
        let appDirs: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            home.appendingPathComponent("Applications"),
        ]

        for appDir in appDirs {
            guard let apps = try? fm.contentsOfDirectory(
                at: appDir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for app in apps where app.pathExtension == "app" {
                let resourcesPath = app.appendingPathComponent("Contents/Resources")
                guard let resources = try? fm.contentsOfDirectory(
                    at: resourcesPath,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                ) else { continue }

                for resource in resources where resource.pathExtension == "lproj" {
                    let langCode = resource.deletingPathExtension().lastPathComponent
                    guard !alwaysKeep.contains(langCode), !preferred.contains(langCode) else { continue }
                    let size = calculateSize(at: resource)
                    if size > 1024 {
                        let appName = app.deletingPathExtension().lastPathComponent
                        items.append(SmartScanItem(path: resource, name: "\(appName) (\(langCode))", size: size))
                    }
                }
            }
        }

        let total = items.reduce(0) { $0 + $1.size }
        return SmartScanSubcategory(name: "Arquivos de Idioma", iconName: "globe", items: items, totalSize: total)
    }

    // MARK: - Mail Attachments

    private func scanMailAttachments() async -> SmartScanCategoryResult {
        let mailPaths: [(URL, String)] = [
            (home.appendingPathComponent("Library/Mail Downloads"), "Downloads de E-mail"),
            (home.appendingPathComponent("Library/Containers/com.apple.mail/Data/Library/Mail Downloads"), "Anexos do Mail"),
        ]

        var subcategories: [SmartScanSubcategory] = []
        for (path, name) in mailPaths {
            guard fm.fileExists(atPath: path.path) else { continue }
            let subcat = scanTopLevelDirectory(at: path, name: name, icon: "paperclip")
            if subcat.totalSize > 0 { subcategories.append(subcat) }
        }

        return SmartScanCategoryResult(category: .mailAttachments, subcategories: subcategories)
    }

    // MARK: - Trash Bins

    private func scanTrashBins() async -> SmartScanCategoryResult {
        var subcategories: [SmartScanSubcategory] = []

        let mainTrash = home.appendingPathComponent(".Trash")
        if fm.fileExists(atPath: mainTrash.path) {
            let subcat = scanTopLevelDirectory(at: mainTrash, name: "Lixeira Principal", icon: "trash.fill")
            if subcat.totalSize > 0 { subcategories.append(subcat) }
        }

        if let volumes = try? fm.contentsOfDirectory(
            at: URL(fileURLWithPath: "/Volumes"),
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for vol in volumes {
                let trashPath = vol.appendingPathComponent(".Trashes")
                guard fm.fileExists(atPath: trashPath.path) else { continue }
                let size = calculateSize(at: trashPath)
                guard size > 0 else { continue }
                let item = SmartScanItem(path: trashPath, name: vol.lastPathComponent, size: size)
                subcategories.append(SmartScanSubcategory(
                    name: "Lixeira: \(vol.lastPathComponent)",
                    iconName: "externaldrive.fill",
                    items: [item],
                    totalSize: size
                ))
            }
        }

        return SmartScanCategoryResult(category: .trashBins, subcategories: subcategories)
    }

    // MARK: - Universal Binaries

    private func scanUniversalBinaries() async -> SmartScanCategoryResult {
        #if arch(arm64)
        var items: [SmartScanItem] = []
        let appDirs: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            home.appendingPathComponent("Applications"),
        ]

        for appDir in appDirs {
            guard let apps = try? fm.contentsOfDirectory(
                at: appDir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for app in apps where app.pathExtension == "app" {
                if let item = checkUniversalBinary(app: app) {
                    items.append(item)
                }
            }
        }

        let total = items.reduce(0) { $0 + $1.size }
        let subcats = total > 0
            ? [SmartScanSubcategory(name: "Binários Universais", iconName: "cpu.fill", items: items, totalSize: total)]
            : [SmartScanSubcategory]()
        return SmartScanCategoryResult(category: .universalBinaries, subcategories: subcats)
        #else
        return SmartScanCategoryResult(category: .universalBinaries, subcategories: [])
        #endif
    }

    private func checkUniversalBinary(app: URL) -> SmartScanItem? {
        let infoPlistPath = app.appendingPathComponent("Contents/Info.plist")
        guard let plist = NSDictionary(contentsOf: infoPlistPath),
              let execName = plist["CFBundleExecutable"] as? String else { return nil }

        let execPath = app.appendingPathComponent("Contents/MacOS/\(execName)")
        guard fm.fileExists(atPath: execPath.path) else { return nil }

        let output = runProcess("/usr/bin/lipo", args: ["-archs", execPath.path])
        guard let archs = output, archs.contains("x86_64") && archs.contains("arm64") else { return nil }

        // Estimate x86_64 slice ≈ half the binary (lipo -thin is destructive so we estimate)
        let execSize = (try? fm.attributesOfItem(atPath: execPath.path)[.size] as? Int64) ?? 0
        let sliceEstimate = execSize / 2
        guard sliceEstimate > 512 * 1024 else { return nil } // skip tiny binaries

        let appName = app.deletingPathExtension().lastPathComponent
        return SmartScanItem(path: execPath, name: appName, size: sliceEstimate)
    }

    // MARK: - Utilities

    func calculateSize(at url: URL) -> Int64 {
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }

        if !isDir.boolValue {
            return (try? fm.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
        }

        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                  values.isDirectory != true else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }

    private func runProcess(_ path: String, args: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    // MARK: - Deletion

    func deleteItems(in result: SmartScanCategoryResult) async -> Int64 {
        var freed: Int64 = 0
        for subcat in result.subcategories where subcat.isSelected {
            for item in subcat.items where item.isSelected {
                do {
                    var trashedURL: NSURL?
                    try fm.trashItem(at: item.path, resultingItemURL: &trashedURL)
                    freed += item.size
                } catch {
                    // Skip items that can't be moved to trash
                }
            }
        }
        return freed
    }
}

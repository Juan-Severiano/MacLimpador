import Foundation

nonisolated enum OperationLogLevel: String, Codable, Sendable {
    case info
    case warning
    case error
}

nonisolated struct OperationLogEntry: Codable, Sendable {
    let id: UUID
    let timestamp: Date
    let level: OperationLogLevel
    let operation: String
    let message: String
    let metadata: [String: String]

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: OperationLogLevel,
        operation: String,
        message: String,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.operation = operation
        self.message = message
        self.metadata = metadata
    }
}

actor OperationLogger {
    static let shared = OperationLogger()

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let logsDirectory: URL
    private let logFileURL: URL

    private init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let home = fileManager.homeDirectoryForCurrentUser
        logsDirectory = home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("MacLimpador", isDirectory: true)
        logFileURL = logsDirectory.appendingPathComponent("operations.log", isDirectory: false)

        if !fileManager.fileExists(atPath: logsDirectory.path) {
            try? fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        }

        if !fileManager.fileExists(atPath: logFileURL.path) {
            fileManager.createFile(atPath: logFileURL.path, contents: nil)
        }
    }

    func log(
        level: OperationLogLevel,
        operation: String,
        message: String,
        metadata: [String: String] = [:]
    ) {
        let entry = OperationLogEntry(level: level, operation: operation, message: message, metadata: metadata)

        do {
            let data = try encoder.encode(entry)
            ensureLogFile()

            if let handle = try? FileHandle(forWritingTo: logFileURL) {
                defer { try? handle.close() }
                try handle.seekToEnd()
                handle.write(data)
                handle.write(Data("\n".utf8))
            }
        } catch {
            // Logging should never crash the app.
        }
    }

    private func ensureLogFile() {
        if !fileManager.fileExists(atPath: logsDirectory.path) {
            try? fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        }

        if !fileManager.fileExists(atPath: logFileURL.path) {
            fileManager.createFile(atPath: logFileURL.path, contents: nil)
        }
    }
}

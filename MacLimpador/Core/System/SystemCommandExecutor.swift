import Foundation

struct CommandExecutionResult: Sendable {
    let command: String
    let arguments: [String]
    let stdout: String
    let stderr: String
    let exitCode: Int32

    var success: Bool { exitCode == 0 }
}

enum CommandExecutionError: Error, LocalizedError {
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .launchFailed(let reason):
            return reason
        }
    }
}

actor SystemCommandExecutor {
    static let shared = SystemCommandExecutor()

    private init() {}

    func run(_ command: String, arguments: [String] = [], timeout: TimeInterval = 30) async throws -> CommandExecutionResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: command)
            process.arguments = arguments

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            let timeoutTask = DispatchWorkItem {
                if process.isRunning {
                    process.terminate()
                }
            }

            process.terminationHandler = { proc in
                timeoutTask.cancel()

                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                let stdout = String(decoding: stdoutData, as: UTF8.self)
                let stderr = String(decoding: stderrData, as: UTF8.self)

                continuation.resume(returning: CommandExecutionResult(
                    command: command,
                    arguments: arguments,
                    stdout: stdout,
                    stderr: stderr,
                    exitCode: proc.terminationStatus
                ))
            }

            do {
                try process.run()
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutTask)
            } catch {
                continuation.resume(throwing: CommandExecutionError.launchFailed(error.localizedDescription))
            }
        }
    }
}

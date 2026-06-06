import Foundation

// MARK: - CommandResult

/// The result of a shell command execution.
public struct CommandResult: Sendable, Equatable {
    public let executable: String
    public let arguments: [String]
    public let exitCode: Int32
    public let output: String
    public let error: String
    public let timedOut: Bool

    /// Stdout and stderr joined, with empty parts dropped.
    public var combinedOutput: String {
        [output, error].filter { !$0.isEmpty }.joined(separator: "\n")
    }

    /// True when the command exited with code 0 and did not time out.
    public var succeeded: Bool { exitCode == 0 && !timedOut }

    public init(
        executable: String,
        arguments: [String],
        exitCode: Int32,
        output: String,
        error: String,
        timedOut: Bool = false
    ) {
        self.executable = executable
        self.arguments = arguments
        self.exitCode = exitCode
        self.output = output
        self.error = error
        self.timedOut = timedOut
    }
}

// MARK: - CommandRunner

/// Runs external executables safely.
///
/// Security model (enforced unconditionally):
/// - Executable must be an absolute path (rejects relative paths and bare names).
/// - Shell trampolines are blocked: `/bin/sh`, `/bin/bash`, `/bin/zsh`, `/usr/bin/env`.
/// - No implicit shell expansion; arguments are passed as-is to `Process`.
public struct CommandRunner: Sendable {
    public init() {}

    /// Runs `executable` with `arguments`, timing out after `timeout` seconds.
    /// Executes on a detached utility-priority task to avoid blocking the caller.
    public func run(
        _ executable: String,
        _ arguments: [String] = [],
        timeout: TimeInterval = 5
    ) async -> CommandResult {
        await Task.detached(priority: .utility) {
            Self.runBlocking(executable: executable, arguments: arguments, timeout: timeout)
        }.value
    }

    // MARK: - Private

    private static let blockedExecutables: Set<String> = [
        "/bin/sh", "/bin/bash", "/bin/zsh", "/usr/bin/env"
    ]

    private static func runBlocking(
        executable: String,
        arguments: [String],
        timeout: TimeInterval
    ) -> CommandResult {
        guard executable.hasPrefix("/") else {
            return .rejected(
                executable: executable,
                arguments: arguments,
                reason: "rejected: executable must be an absolute path"
            )
        }
        guard !blockedExecutables.contains(executable) else {
            return .rejected(
                executable: executable,
                arguments: arguments,
                reason: "rejected: shell execution is not allowed"
            )
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            return .rejected(
                executable: executable,
                arguments: arguments,
                reason: "launch failed: \(error.localizedDescription)"
            )
        }

        let deadline = Date().addingTimeInterval(timeout)
        var timedOut = false

        while process.isRunning {
            if Date() >= deadline {
                timedOut = true
                process.terminate()
                break
            }
            Thread.sleep(forTimeInterval: 0.02)
        }

        process.waitUntilExit()

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()

        return CommandResult(
            executable: executable,
            arguments: arguments,
            exitCode: timedOut ? -1 : process.terminationStatus,
            output: String(data: outData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            error: String(data: errData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            timedOut: timedOut
        )
    }
}

// MARK: - Convenience

private extension CommandResult {
    static func rejected(executable: String, arguments: [String], reason: String) -> CommandResult {
        CommandResult(
            executable: executable,
            arguments: arguments,
            exitCode: -1,
            output: "",
            error: reason
        )
    }
}

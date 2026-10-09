import Foundation

public struct ProcessResult: Sendable {
    public let status: Int32
    public let stdout: Data
    public let stderr: Data

    public var stdoutString: String { String(decoding: stdout, as: UTF8.self) }
    public var stderrString: String { String(decoding: stderr, as: UTF8.self) }
}

public struct ProcessError: Error, CustomStringConvertible, Sendable {
    public let command: String
    public let status: Int32
    public let stderr: String

    public init(command: String, status: Int32, stderr: String) {
        self.command = command
        self.status = status
        self.stderr = stderr
    }

    public var description: String { "\(command) failed (\(status)): \(stderr)" }
}

/// Runs external tools (git, rg, …) off the main thread and collects their output.
public enum ProcessRunner {
    public static func run(
        _ executable: URL, _ arguments: [String], cwd: URL? = nil, stdin: Data? = nil
    ) async throws -> ProcessResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = executable
                process.arguments = arguments
                if let cwd { process.currentDirectoryURL = cwd }
                let out = Pipe(), err = Pipe()
                process.standardOutput = out
                process.standardError = err
                let inPipe = stdin == nil ? nil : Pipe()
                process.standardInput = inPipe ?? FileHandle.nullDevice
                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }
                if let inPipe, let stdin {
                    DispatchQueue.global().async {
                        inPipe.fileHandleForWriting.write(stdin)
                        try? inPipe.fileHandleForWriting.close()
                    }
                }
                // Drain stderr concurrently so a full pipe can never deadlock the child.
                var errData = Data()
                let group = DispatchGroup()
                group.enter()
                DispatchQueue.global().async {
                    errData = err.fileHandleForReading.readDataToEndOfFile()
                    group.leave()
                }
                let outData = out.fileHandleForReading.readDataToEndOfFile()
                group.wait()
                process.waitUntilExit()
                continuation.resume(returning: ProcessResult(
                    status: process.terminationStatus, stdout: outData, stderr: errData))
            }
        }
    }
}

import Foundation
import Testing
@testable import MarginSupport

@Test func runCapturesStdoutAndStatus() async throws {
    let result = try await ProcessRunner.run(URL(fileURLWithPath: "/bin/echo"), ["hello"])
    #expect(result.status == 0)
    #expect(result.stdoutString == "hello\n")
}

@Test func runCapturesStderrAndNonZeroStatus() async throws {
    let result = try await ProcessRunner.run(URL(fileURLWithPath: "/bin/sh"), ["-c", "echo oops >&2; exit 3"])
    #expect(result.status == 3)
    #expect(result.stderrString == "oops\n")
}

@Test func runPassesStdin() async throws {
    let result = try await ProcessRunner.run(URL(fileURLWithPath: "/bin/cat"), [], stdin: Data("piped".utf8))
    #expect(result.stdoutString == "piped")
}

@Test func runHandlesLargeOutputWithoutDeadlock() async throws {
    let result = try await ProcessRunner.run(
        URL(fileURLWithPath: "/bin/sh"), ["-c", "yes x | head -n 200000; yes y | head -n 200000 >&2"])
    #expect(result.stdout.count == 400_000)
    #expect(result.stderr.count == 400_000)
}

@Test func toolLocatorFindsShAndRejectsUnknown() {
    #expect(ToolLocator.find("sh", environment: ["PATH": "/bin"])?.path == "/bin/sh")
    #expect(ToolLocator.find("definitely-not-a-tool-xyz", environment: ["PATH": ""]) == nil)
}

@Test func requireThrowsMissingToolErrorWithHint() {
    #expect(throws: MissingToolError.self) {
        try ToolLocator.require("definitely-not-a-tool-xyz", installHint: "brew install xyz")
    }
}

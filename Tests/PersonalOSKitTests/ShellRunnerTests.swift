import Testing
@testable import ShellRunner

@Suite("CommandRunner — security model")
struct ShellRunnerTests {

    let runner = CommandRunner()

    // MARK: - Security: blocked inputs

    @Test("rejects relative executable path")
    func rejectsRelativePath() async {
        let result = await runner.run("git", ["status"])
        #expect(result.exitCode == -1)
        #expect(result.error.contains("absolute path"))
        #expect(!result.succeeded)
    }

    @Test("rejects bare executable name")
    func rejectsBareExecutable() async {
        let result = await runner.run("ls")
        #expect(result.exitCode == -1)
        #expect(result.error.contains("absolute path"))
    }

    @Test("rejects /bin/sh")
    func rejectsShSh() async {
        let result = await runner.run("/bin/sh", ["-c", "echo test"])
        #expect(result.exitCode == -1)
        #expect(result.error.contains("shell execution"))
    }

    @Test("rejects /bin/bash")
    func rejectsBash() async {
        let result = await runner.run("/bin/bash", ["-c", "echo test"])
        #expect(result.exitCode == -1)
        #expect(result.error.contains("shell execution"))
    }

    @Test("rejects /bin/zsh")
    func rejectsZsh() async {
        let result = await runner.run("/bin/zsh", ["-c", "echo test"])
        #expect(result.exitCode == -1)
        #expect(result.error.contains("shell execution"))
    }

    @Test("rejects /usr/bin/env")
    func rejectsEnv() async {
        let result = await runner.run("/usr/bin/env", ["echo", "test"])
        #expect(result.exitCode == -1)
        #expect(result.error.contains("shell execution"))
    }

    // MARK: - Valid execution

    @Test("accepts /usr/bin/true")
    func acceptsTrue() async {
        let result = await runner.run("/usr/bin/true")
        #expect(result.exitCode == 0)
        #expect(result.succeeded)
        #expect(!result.timedOut)
    }

    @Test("accepts /usr/bin/false and returns exit code 1")
    func acceptsFalse() async {
        let result = await runner.run("/usr/bin/false")
        #expect(result.exitCode == 1)
        #expect(!result.succeeded)
    }

    @Test("captures stdout correctly")
    func capturesStdout() async {
        let result = await runner.run("/bin/echo", ["hello-personaloskit"])
        #expect(result.exitCode == 0)
        #expect(result.output == "hello-personaloskit")
    }

    @Test("captures stderr correctly")
    func capturesStderr() async {
        // /usr/bin/false writes nothing, but /bin/ls on a missing path writes to stderr
        let result = await runner.run("/bin/ls", ["/nonexistent-path-xyzxyz"])
        #expect(result.exitCode != 0)
        #expect(!result.error.isEmpty)
    }

    @Test("combinedOutput merges stdout and stderr")
    func combinedOutput() async {
        let result = await runner.run("/bin/echo", ["combined"])
        #expect(result.combinedOutput == "combined")
    }

    // MARK: - Timeout

    @Test("times out a slow process")
    func timesOut() async {
        let result = await runner.run("/bin/sleep", ["10"], timeout: 0.1)
        #expect(result.timedOut)
        #expect(result.exitCode == -1)
        #expect(!result.succeeded)
    }
}

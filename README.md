# PersonalOSKit

Shared Swift Package for the personal macOS operating system portfolio.

Consumed by: FOKS_BLOOMBERG · System_Org 2 · PersonalLifeOS

---

## Modules

### ShellRunner

Safe, async/await shell command execution.

```swift
import ShellRunner

let runner = CommandRunner()
let result = await runner.run("/usr/bin/git", ["-C", repoPath, "status", "--short"])
if result.succeeded {
    print(result.output)
}
```

**Security model (enforced unconditionally):**
- Executable must be an absolute path — relative paths and bare names are rejected
- Shell trampolines are blocked: `/bin/sh`, `/bin/bash`, `/bin/zsh`, `/usr/bin/env`
- No shell expansion — arguments are passed directly to `Process`

---

### OllamaClient

Async/await HTTP client for a local Ollama instance.

```swift
import OllamaClient

let client = OllamaClient()

// Check availability
let available = await client.isAvailable()

// List models
let models = await client.models()

// Non-streaming generate
let reply = try await client.generate(model: "llama3.2", prompt: "Summarise this log: ...")

// Streaming generate
for try await token in client.generateStream(model: "llama3.2", prompt: prompt) {
    await MainActor.run { label.stringValue += token }
}
```

---

## Adding to a project

In your `Package.swift`:

```swift
dependencies: [
    .package(path: "../../PersonalOSKit"),
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "ShellRunner", package: "PersonalOSKit"),
            .product(name: "OllamaClient", package: "PersonalOSKit"),
        ]
    )
]
```

---

## Running tests

```zsh
swift test --package-path ~/Developer/PersonalOSKit
```

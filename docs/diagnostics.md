# Inspect dependency activity

Astral reports typed-key registration, resolution, and scope lifecycle through unified logging. Diagnostics are off by default and are intended to make dependency configuration failures visible during development.

## Enable dependency logs

Set the process-wide `Astral.debug` level during app startup:

```swift
import Astral
import SwiftUI

@main
struct ExampleApp: App {
  init() {
    Astral.debug = .normal
  }

  var body: some Scene {
    WindowGroup { ContentView() }
  }
}
```

| Level | Output |
| --- | --- |
| `.off` | No Astral diagnostics. |
| `.normal` | Resolution requests and outcomes, failures, removals, and `removeAll()` results. |
| `.trace` | Normal logs plus eager and factory-based `set` operations. |

Events include the dependency value type, static key type, and a short opaque identifier that correlates activity within one scope. Astral does not log dependency values or the caller-provided `DependencyKey.debugName`.

Resolution failures distinguish missing registrations, circular factories, and errors thrown by factories.

`Astral.debug` is safe to read or write from concurrent tasks. Optional diagnostic calls are compiled out when Astral is built without `DEBUG`.

Logs use the `eu.lelfe.astral` subsystem and `Astral` category.

Next: [Working with keys and scopes](scopes-and-dependencies.md) · [Migrate to Astral 2.0](migrating-to-2.0.md)

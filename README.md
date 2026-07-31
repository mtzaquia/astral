# 🌌 Astral

[![Tests](https://github.com/mtzaquia/astral/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/mtzaquia/astral/actions/workflows/tests.yml)
[![Swift 6.3](https://img.shields.io/badge/Swift-6.3-orange.svg)](https://www.swift.org/)
[![iOS 17+](https://img.shields.io/badge/iOS-17%2B-blue.svg)](https://github.com/mtzaquia/astral/blob/main/Package.swift)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue.svg)](https://github.com/mtzaquia/astral/blob/main/Package.swift)
![Class C](https://img.shields.io/badge/class-C-orange)

Astral is a Swift dependency-injection library built around typed keys and property wrappers.

Define the value associated with a key, set that key in a scope, and inject it where it is needed. Astral uses the key type as identity, so multiple dependencies can share a value type without relying on strings.

- Starts with an implicit global scope and adds custom scopes when isolation is needed.
- Supports eager values and concurrency-safe deferred factories.
- Requires `Sendable` dependencies and factories without imposing main-actor isolation.
- Reports missing registrations and circular factories through typed errors.
- Captures an immutable dependency snapshot when `@Dependency` initializes.
- Provides opt-in lifecycle diagnostics in debug builds.

```swift
import Astral

protocol ProfileService: Sendable {
  func loadProfile()
}

struct LiveProfileService: ProfileService {
  func loadProfile() {}
}

enum ProfileServiceKey: DependencyKey {
  typealias Value = any ProfileService
}

Scope.global.set(
  LiveProfileService(),
  for: ProfileServiceKey.self
)

final class ProfileModel {
  @Dependency(ProfileServiceKey.self) var profileService

  func refresh() {
    profileService.loadProfile()
  }
}
```

## Install

Astral 2.0 supports iOS 17 and macOS 14 or later and uses Swift tools version 6.3. Add it to your Swift Package Manager dependencies:

```swift
dependencies: [
  .package(url: "https://github.com/mtzaquia/astral.git", from: "2.0.0"),
]
```

Then add the `Astral` product to each target that imports it.

## Five-minute start

Define one key for each dependency. The key's associated `Value` is the type callers receive:

```swift
import Astral

protocol APIClient: Sendable {
  func fetchProfile()
}

struct LiveAPIClient: APIClient {
  func fetchProfile() {}
}

enum APIClientKey: DependencyKey {
  typealias Value = any APIClient
}
```

Set the dependency during application startup:

```swift
Scope.global.set(LiveAPIClient(), for: APIClientKey.self)
```

Then inject it. Omitting `scope:` uses `Scope.global`:

```swift
final class AccountModel {
  @Dependency(APIClientKey.self) var apiClient

  func reload() {
    apiClient.fetchProfile()
  }
}
```

That is the core idea: a `DependencyKey` provides compile-time identity and value typing, while a `Scope` owns the current registration.

## Documentation

- [Working with keys and scopes](docs/scopes-and-dependencies.md) — set values and factories, recover from failures, isolate features, and remove registrations.
- [Inspect dependency activity](docs/diagnostics.md) — enable unified logs for typed-key registration and resolution.
- [Migrate to Astral 2.0](docs/migrating-to-2.0.md) — replace `Storage`, named registrations, lazy flags, and `clear()`.

## License

Copyright (c) 2021 @mtzaquia

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

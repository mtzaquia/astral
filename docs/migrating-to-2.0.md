# Migrate to Astral 2.0

Astral 2.0 replaces string-backed `Storage` lookups with typed dependency keys, makes concurrency requirements explicit, and separates recoverable resolution from APIs that treat missing configuration as a programming error.

## Update deployment and toolchain requirements

Astral 2.0 requires Swift 6.3, iOS 17 or later, and macOS 14 or later.

Update the package requirement:

```swift
dependencies: [
  .package(url: "https://github.com/mtzaquia/astral.git", from: "2.0.0"),
]
```

## Replace `Storage` extensions with keys

Astral 1.x exposed a computed property on `Storage`:

```swift
extension Storage {
  var apiClient: APIClient { resolve() }
}
```

In Astral 2.0, define a key whose associated value is the dependency type:

```swift
enum APIClientKey: DependencyKey {
  typealias Value = any APIClient
}
```

The value type must conform to `Sendable`. For protocol-backed dependencies, make the protocol inherit from `Sendable`:

```swift
protocol APIClient: Sendable {
  func fetchProfile()
}
```

The key type provides identity, so separate keys no longer collide when they use the same value type or readable name.

## Replace registration calls

Replace eager `register` calls:

```swift
// Astral 1.x
Scope.global.register(LiveAPIClient())

// Astral 2.0
Scope.global.set(LiveAPIClient(), for: APIClientKey.self)
```

Replace `lazy: true` with an explicit `@Sendable` factory:

```swift
// Astral 1.x
Scope.global.register(lazy: true, LiveAPIClient())

// Astral 2.0
Scope.global.set(for: APIClientKey.self) {
  LiveAPIClient()
}
```

Factories may throw. Failures are not cached, so the next resolution retries.

Named registrations no longer exist. Define another key whenever one value type needs another registration:

```swift
enum PreviewAPIClientKey: DependencyKey {
  typealias Value = any APIClient
}
```

## Update dependency wrappers

Replace the `Storage` key path with the dependency key type:

```swift
// Astral 1.x
@Dependency(\.apiClient) var apiClient

// Astral 2.0
@Dependency(APIClientKey.self) var apiClient
```

The implicit scope remains `Scope.global`. Existing custom scopes move across unchanged:

```swift
@Dependency(APIClientKey.self, scope: .previews)
var apiClient
```

The 2.0 wrapper resolves eagerly during consumer initialization instead of waiting for the property's first read. Configure the scope before creating consumers. The wrapper still retains its resolved value after a registration is replaced or removed.

## Choose recoverable or required resolution

`resolve(_:)` now throws:

```swift
let apiClient = try scope.resolve(APIClientKey.self)
```

It reports missing registrations and circular factory chains through `DependencyResolutionError`, and forwards errors thrown by factories.

Use `require(_:)` when failure is unrecoverable:

```swift
let apiClient = scope.require(APIClientKey.self)
```

`@Dependency` uses required resolution and terminates the process when initialization cannot resolve its key.

## Replace scope clearing

Replace `clear()` with targeted or complete removal:

```swift
scope.remove(APIClientKey.self)
scope.removeAll()
```

Removal and replacement are synchronous. A factory already serving a caller is not cancelled, but its result cannot restore an obsolete registration.

Next: [Working with keys and scopes](scopes-and-dependencies.md) · [Inspect dependency activity](diagnostics.md)

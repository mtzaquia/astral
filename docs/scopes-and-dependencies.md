# Working with keys and scopes

Astral pairs each dependency with a `DependencyKey` type and stores its current registration in a `Scope`. Start with the implicit global scope, then introduce custom scopes when a feature, preview, or test needs an independent registration set.

## Define a typed key

Conform an uninhabited type to `DependencyKey` and specify the value callers should receive:

```swift
import Astral

protocol AccountService: Sendable {
  func reload()
}

struct LiveAccountService: AccountService {
  func reload() {}
}

enum AccountServiceKey: DependencyKey {
  typealias Value = any AccountService
}
```

The key type itself is the registration identity. Two keys can use the same `Value` type or `debugName` without colliding.

`Value` must conform to `Sendable`. Astral keeps its registry safe to share across isolation domains but does not add synchronization to the dependency itself. Use actors, immutable values, or `@MainActor` types according to the dependency's own ownership.

## Set an eager value

Set an immediately available value during application startup:

```swift
Scope.global.set(
  LiveAccountService(),
  for: AccountServiceKey.self
)
```

`set(_:for:)` returns after replacing any previous value or factory for that key.

## Inject from the global scope

`@Dependency` uses `Scope.global` when `scope:` is omitted:

```swift
final class AccountModel {
  @Dependency(AccountServiceKey.self) var accountService

  func reload() {
    accountService.reload()
  }
}
```

The wrapper resolves when `AccountModel` initializes and retains that value. Configure the scope before creating the consumer. Later replacements and removals affect new resolutions, not wrappers that already captured a value.

`@Dependency` treats resolution failure as a programming error and terminates the process with the key and underlying error.

## Defer creation with a factory

Use a factory when construction should wait until the first resolution:

```swift
Scope.global.set(for: AccountServiceKey.self) {
  LiveAccountService()
}
```

The factory is an escaping `@Sendable` closure and executes on the caller that begins resolution. Astral invokes it outside the registry lock. Concurrent callers wait for the same in-flight invocation and receive its successful result.

If a factory throws, Astral forwards the error and leaves the factory registered so a later resolution can retry:

```swift
Scope.global.set(for: AccountServiceKey.self) {
  try makeAccountService()
}
```

Lazy actor-isolated construction is intentionally not implicit. Create `@MainActor` dependencies eagerly from the main actor and set the resulting value in the scope.

## Recover from resolution failures

Call `resolve(_:)` when the caller can handle missing configuration or factory failures:

```swift
do {
  let service = try Scope.global.resolve(AccountServiceKey.self)
  service.reload()
} catch {
  print("Dependency configuration failed: \(error)")
}
```

Astral throws `DependencyResolutionError.notRegistered` when no registration exists and `DependencyResolutionError.circularDependency` when factories resolve back to a key already in their synchronous chain. Errors thrown by a factory pass through unchanged.

Call `require(_:)` when missing configuration should terminate immediately:

```swift
let service = Scope.global.require(AccountServiceKey.self)
```

## Introduce a custom scope

Define a custom scope only when a registration set needs independent ownership:

```swift
extension Scope {
  static let previews = Scope()
}

struct PreviewAccountService: AccountService {
  func reload() {}
}

Scope.previews.set(
  PreviewAccountService(),
  for: AccountServiceKey.self
)

final class PreviewAccountModel {
  @Dependency(AccountServiceKey.self, scope: .previews)
  var accountService
}
```

Scopes are `Sendable` and may be shared across concurrency domains. Operations on one scope do not affect another.

## Replace or remove registrations

Calling `set` for the same key replaces its previous value, factory, or in-flight invocation:

```swift
Scope.global.set(
  PreviewAccountService(),
  for: AccountServiceKey.self
)
```

Remove one key or the whole scope:

```swift
Scope.global.remove(AccountServiceKey.self)
Scope.global.removeAll()
```

Removal does not cancel a factory already executing for a caller, but that older result cannot overwrite a replacement or reappear after removal.

Next: [Inspect dependency activity](diagnostics.md) · [Migrate to Astral 2.0](migrating-to-2.0.md)

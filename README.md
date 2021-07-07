# Astral

Astral is a lightweight, scalable framework for strongly-typed dependency injection with property wrapper support.

Astral is mostly inspired by `SwiftUI.Environment`.

## Instalation

Astral is available via Swift Package Manager.

```swift
dependencies: [
  .package(url: "https://github.com/mtzaquia/astral.git", branch: "main"),
],
```

## Usage

### Create your scope (optional)

For simpler projects, you should be good to go with the `Scope.global`. For larger and/or modularised projects, prefer creating your scope by declaring it in an extension.

```swift
extension Scope {
  static let myScope = Scope()
}
``` 

### Register instances

Before using your dependencies, make sure an instance is available or can be lazily resolved.

```swift
// No name needed, the type will be used as key automatically.
Scope.myScope.register(SampleDependency())

// A dependency that will be initialised on the first access.
Scope.myScope.register(lazy: true, MyDependency())

// A dependency registered with a custom name, which also needs to be used when fetching it with `resolve(named:)`.
Scope.myScope.register(named: "CustomName", lazy: true, MyDependency())
``` 

### Extend the storage

For strongly-typed access, declare your properties in a `Storage` extension. If you are not using a custom name when registering this dependency, all you need to do is call `resolve()` as your getter - type inference will do the rest. 

```swift
// Your declaration will use its type to automatically resolve the instance.
extension Storage { 
  var myDependency: SampleDependency { resolve() }
}

// If you registered your dependency with a custom name, make sure to pass it to `.resolve(named:)`. 
extension Storage {
  var myDependency: MyDependency { resolve(named: "CustomName") }
}
```

### Fetching the instance

Finally, simply declare a property with the `@Dependency` property wrapper, providing the key path you have declared on `Storage`.

If you ommit the `scope:` parameter, the lookup will happen on `Scope.global`.   

```swift
struct MyModel {
  // ...
  @Dependency(\.myDependency, scope: .myScope) var myDependency
  func method() {
    myDependency.doSomething()
  }
  
  // ...
}
``` 

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

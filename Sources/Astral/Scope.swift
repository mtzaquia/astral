//
//  Scope.swift
//
//  Copyright (c) 2021 @mtzaquia
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import Foundation

/// A type that defines a contained scope of dependencies.
///
/// It is recommended that you extended this type with your own declarations, so that your dependencies are properly segregated.
/// ```swift
/// extension Scope {
///   static let myScope = Scope()
/// }
/// ```
public final class Scope {
  let storage: Storage = Storage()
}

public extension Scope {
  /// A global scope for storage of generic dependencies.
  static let global = Scope()

  /// This method will store a dependency for later use. Dependencies registered this way can be later accessed with ``Dependencies/resolve(named:)``.
  ///
  /// - Parameters:
  ///   - named: The name to be used when registering this dependency. By default, this will be the description of the instance type.
  ///   - lazy: A flag indicating whether the instance should be lazily instantiated. Defaults to `false`.
  ///   - instance: The instance to be registered for the given name.
  func register<Dependency>(named: String? = nil, lazy: Bool = false, _ instance: @autoclosure @escaping () -> Dependency) {
    storage.register(named: named, lazy: lazy, instance)
  }

  /// Removes all the stored dependencies from this particular scope.
  func clear() {
    storage.clear()
  }
}

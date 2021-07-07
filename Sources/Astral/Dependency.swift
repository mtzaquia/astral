//
//  Dependency.swift
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

/// A property wrapper that fetches previously registered dependencies from a given ``Scope``.
@propertyWrapper
public struct Dependency<T> {
  public lazy var wrappedValue: T = {
    scope.storage[keyPath: keyPath]
  }()

  private var keyPath: KeyPath<Storage, T>
  private var scope: Scope

  /// Use this wrapper to fetch a previously registered dependencies from a given ``Scope``.
  /// - Parameters:
  ///   - keyPath: The ``Storage`` key path in which the dependency is stored.
  ///   - scope: The ``Scope`` in which the dependency is stored. Defaults to ``Scope/global``.
  public init(_ keyPath: KeyPath<Storage, T>, scope: Scope = .global) {
    self.keyPath = keyPath
    self.scope = scope
  }
}

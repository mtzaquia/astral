//
//  Storage.swift
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
import OSLog

/// A type that stores and orchestrates dependencies access in a thread-safe way.
public final class Storage {
  init() {}

  private let uuid: UUID = UUID()
  private var storage = [String: Any]()
  private var lazyStorage = [String: () -> Any]()
  private lazy var queue = DispatchQueue(label: "astral.\(uuid).queue", attributes: .concurrent)
}

extension Storage {
  func register<Dependency>(named: String?, lazy: Bool, _ instance: @escaping () -> Dependency) {
    let key = key(named: named, for: Dependency.self)

    queue.async(flags: .barrier) { [weak self] in
      guard let self = self else { return }
      if lazy {
        self.lazyStorage[key] = instance
      } else {
        self.storage[key] = instance()
      }

      Logger.astral.info("Registered \(Dependency.self) for key '\(key)'.")
    }
  }

  /// This method will fetch a dependency for immediate use. If the dependency was lazily registered, it will be instantiated on its first access.
  ///
  /// - Parameters:
  ///   - named: The name used when registering the desired dependency. By default, this will be the description of the instance type and can be ommitted, if inferred.
  public func resolve<Dependency>(named: String? = nil) -> Dependency {
    let key = key(named: named, for: Dependency.self)

    var result: Dependency?
    queue.sync {
      result = storage[key] as? Dependency
    }

    if let result = result {
      return result
    }

    queue.sync {
      result = lazyStorage[key]?() as? Dependency
    }

    if let result = result {
      Logger.astral.info("Initialised lazy dependency \(Dependency.self).")
      queue.async(flags: .barrier) { [weak self] in
        guard let self = self else { return }
        self.lazyStorage[key] = nil
        self.storage[key] = result
      }

      return result
    }

    fatalError("Unable to find registered dependency for key '\(key)'.")
  }

  /// Removes all the stored dependencies from this particular scope.
  func clear() {
    queue.async(flags: .barrier) { [weak self] in
      guard let self = self else { return }
      self.storage = [String: Any]()
      self.lazyStorage = [String: () -> Any]()
    }
  }
}

private extension Storage {
  func key<Key>(named: String?, for type: Key.Type) -> String {
    if let name = named, !name.isEmpty {
      return name
    } else {
      return String(describing: type)
    }
  }
}


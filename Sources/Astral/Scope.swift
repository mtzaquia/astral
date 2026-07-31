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

/// An independent collection of dependency registrations.
///
/// ``Scope/global`` provides the default registration set. Define additional
/// scopes when a feature, preview, or test needs isolated dependencies.
///
/// ```swift
/// extension Scope {
///   static let profile = Scope()
/// }
/// ```
public final class Scope: Sendable {
	private let storage = Storage()
	
	/// Creates an empty dependency scope.
	public init() {}
}

public extension Scope {
	/// The process-wide scope used by ``Dependency`` when no scope is supplied.
	static let global = Scope()

	/// Sets an immediately available value for a typed dependency key.
	///
	/// Setting the same key again replaces its previous value or factory before
	/// this method returns. Existing ``Dependency`` wrappers retain the value they
	/// captured earlier.
	///
	/// - Parameters:
	///   - value: The value to store.
	///   - key: The key that identifies the value.
	func set<Key: DependencyKey>(_ value: Key.Value, for key: Key.Type) {
		storage.set(value, for: key)
	}

	/// Sets a factory that creates a typed dependency when first resolved.
	///
	/// Concurrent callers share one in-flight invocation. The factory executes
	/// outside the scope's synchronization lock, and its successful result is
	/// cached while this registration remains current. A thrown error is not
	/// cached, so a later resolution retries the factory.
	///
	/// - Parameters:
	///   - key: The key that identifies the value.
	///   - factory: A concurrency-safe factory that produces the value.
	func set<Key: DependencyKey>(
		for key: Key.Type,
		factory: @escaping @Sendable () throws -> Key.Value
	) {
		storage.set(for: key, factory: factory)
	}

	/// Resolves a typed dependency from this scope.
	///
	/// - Parameter key: The key to resolve.
	/// - Returns: The registered value or the cached result of its factory.
	/// - Throws: ``DependencyResolutionError/notRegistered(_:)`` when the key is
	///   absent, ``DependencyResolutionError/circularDependency(_:)`` when lazy
	///   factories form a cycle, or an error thrown by the registered factory.
	func resolve<Key: DependencyKey>(_ key: Key.Type) throws -> Key.Value {
		try storage.resolve(key)
	}

	/// Resolves a typed dependency or terminates the process on failure.
	///
	/// Use this method when missing configuration is a programming error. Use
	/// ``resolve(_:)`` when the caller can recover.
	///
	/// - Parameters:
	///   - key: The key to resolve.
	///   - file: The source file reported when resolution fails.
	///   - line: The source line reported when resolution fails.
	/// - Returns: The registered value or the cached result of its factory.
	func require<Key: DependencyKey>(
		_ key: Key.Type,
		file: StaticString = #fileID,
		line: UInt = #line
	) -> Key.Value {
		do {
			return try resolve(key)
		} catch {
			fatalError(
				"Unable to resolve '\(Key.debugName)': \(error)",
				file: file,
				line: line
			)
		}
	}

	/// Removes one typed dependency registration.
	///
	/// Removing an in-flight factory prevents its result from being cached, but
	/// does not cancel the invocation already serving a caller.
	///
	/// - Parameter key: The key to remove.
	/// - Returns: `true` when a value, factory, or in-flight invocation existed.
	@discardableResult
	func remove<Key: DependencyKey>(_ key: Key.Type) -> Bool {
		storage.remove(key)
	}

	/// Removes every dependency registration from this scope.
	///
	/// In-flight factories are not cancelled, and their results are not cached
	/// after this method returns. Existing ``Dependency`` wrappers retain their
	/// captured values.
	func removeAll() {
		storage.removeAll()
	}
}

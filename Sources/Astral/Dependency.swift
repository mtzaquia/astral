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

/// A property wrapper that requires a typed dependency from a ``Scope``.
///
/// The wrapper resolves during initialization and retains that value for its
/// lifetime. Clearing or replacing the registration does not change an existing
/// wrapper.
@propertyWrapper
public struct Dependency<Key: DependencyKey>: Sendable {
	/// The dependency captured when the wrapper was initialized.
	public let wrappedValue: Key.Value

	/// Creates a wrapper that requires a dependency from a scope.
	///
	/// This initializer terminates the process when resolution fails. Use
	/// ``Scope/resolve(_:)`` when the caller can recover from failure.
	///
	/// - Parameters:
	///   - key: The typed key to resolve.
	///   - scope: The scope to query. Defaults to ``Scope/global``.
	///   - file: The source file reported when resolution fails.
	///   - line: The source line reported when resolution fails.
	public init(
		_ key: Key.Type,
		scope: Scope = .global,
		file: StaticString = #fileID,
		line: UInt = #line
	) {
		wrappedValue = scope.require(key, file: file, line: line)
	}
}

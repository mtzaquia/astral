//
//  DependencyKey.swift
//
//  Copyright (c) 2026 @mtzaquia
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

/// A type-level key that identifies one dependency in a ``Scope``.
///
/// Define an uninhabited type for each dependency:
///
/// ```swift
/// enum APIClientKey: DependencyKey {
///   typealias Value = any APIClient
/// }
/// ```
///
/// The key type itself provides identity. ``debugName`` is used only in
/// caller-facing errors and does not participate in lookup.
public protocol DependencyKey: Sendable {
	/// The value registered for this key.
	associatedtype Value: Sendable

	/// A caller-readable name used in resolution errors.
	static var debugName: String { get }
}

public extension DependencyKey {
	/// The fully qualified key type name.
	static var debugName: String {
		String(reflecting: Self.self)
	}
}

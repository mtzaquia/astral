//
//  DependencyResolutionError.swift
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

/// An error produced while resolving a dependency from a ``Scope``.
public enum DependencyResolutionError: Error, Equatable, Sendable {
	/// No value or factory is registered for the requested key.
	case notRegistered(String)

	/// Lazy factories formed a cycle while resolving the listed key path.
	case circularDependency([String])
}

extension DependencyResolutionError: CustomStringConvertible {
	/// A caller-readable explanation of the resolution failure.
	public var description: String {
		switch self {
		case let .notRegistered(key):
			"No dependency is registered for '\(key)'."
		case let .circularDependency(path):
			"Circular dependency detected: \(path.joined(separator: " → "))."
		}
	}
}

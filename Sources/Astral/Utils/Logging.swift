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

import os

/// A namespace for process-wide Astral configuration.
public enum Astral {
	/// The amount of dependency-resolution detail emitted in debug builds.
	public enum DebugLogLevel: Equatable, Sendable {
		/// Emits no Astral diagnostics.
		case off

		/// Logs resolution requests and outcomes, failures, and removals.
		case normal

		/// Adds dependency-setting details to normal diagnostics.
		case trace
	}

	private nonisolated static let debugLock =
		OSAllocatedUnfairLock(initialState: DebugLogLevel.off)

	/// Controls the process-wide diagnostics emitted by Astral.
	///
	/// Logging is ``DebugLogLevel/off`` by default. Reads and writes are safe
	/// from any concurrency domain, and diagnostic calls are compiled out when
	/// Astral is built without `DEBUG`.
	///
	/// ```swift
	/// Astral.debug = .trace
	/// ```
	public nonisolated static var debug: DebugLogLevel {
		get { debugLock.withLock { $0 } }
		set { debugLock.withLock { $0 = newValue } }
	}
}

nonisolated let astralLog = Logger(
	subsystem: "eu.lelfe.astral",
	category: "Astral"
)

enum AstralRegistrationMode: String {
	case eager
	case factory
}

enum AstralResolutionSource: String {
	case stored
	case factory
}

enum AstralResolutionFailure: String {
	case missing
	case circular
	case factory
}

enum AstralLogEvent {
	case dependencySet(
		storageID: String,
		key: String,
		type: String,
		mode: AstralRegistrationMode
	)
	case resolutionRequested(
		storageID: String,
		key: String,
		type: String
	)
	case resolutionSucceeded(
		storageID: String,
		key: String,
		type: String,
		source: AstralResolutionSource
	)
	case resolutionFailed(
		storageID: String,
		key: String,
		type: String,
		reason: AstralResolutionFailure
	)
	case dependencyRemoved(
		storageID: String,
		key: String,
		existed: Bool
	)
	case scopeCleared(storageID: String, removedCount: Int)

	var logLevel: Astral.DebugLogLevel {
		switch self {
		case .dependencySet:
			.trace
		default:
			.normal
		}
	}

	var message: String {
		switch self {
		case let .dependencySet(storageID, key, type, mode):
			"[dependency][s:\(storageID)] • set \(type) | key=\(key) mode=\(mode.rawValue)"
		case let .resolutionRequested(storageID, key, type):
			"[dependency][s:\(storageID)] ⇢ resolving \(type) | key=\(key)"
		case let .resolutionSucceeded(storageID, key, type, source):
			"[dependency][s:\(storageID)] ✓ resolved \(type) | key=\(key) source=\(source.rawValue)"
		case let .resolutionFailed(storageID, key, type, reason):
			"[dependency][s:\(storageID)] ✗ resolution failed \(type) | key=\(key) reason=\(reason.rawValue)"
		case let .dependencyRemoved(storageID, key, existed):
			"[dependency][s:\(storageID)] − removed | key=\(key) existed=\(existed)"
		case let .scopeCleared(storageID, removedCount):
			"[scope][s:\(storageID)] ✓ removed all | count=\(removedCount)"
		}
	}
}

extension Logger {
	func astralDebug(_ event: @autoclosure () -> AstralLogEvent) {
#if DEBUG
		let configuredLevel = Astral.debug
		guard configuredLevel != .off else { return }

		let event = event()
		guard configuredLevel.includes(event.logLevel) else { return }
		debug("\(event.message, privacy: .public)")
#endif
	}
}

extension Astral.DebugLogLevel {
	func includes(_ eventLevel: Self) -> Bool {
		switch (self, eventLevel) {
		case (.trace, _), (.normal, .normal), (.off, .off):
			true
		default:
			false
		}
	}
}

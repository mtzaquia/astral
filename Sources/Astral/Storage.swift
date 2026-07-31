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

/// Lock-backed type-erased storage whose public boundary accepts only `Sendable`
/// values and factories. Every entry and resolution stack access is protected by
/// `condition`, which is the invariant supporting unchecked sendability.
final class Storage: @unchecked Sendable {
	private typealias Factory = @Sendable () throws -> any Sendable

	private struct StorageKey: Hashable, Sendable {
		let identifier: ObjectIdentifier
		let debugName: String
		let diagnosticName: String
		let valueType: String

		init<Key: DependencyKey>(_ key: Key.Type) {
			identifier = ObjectIdentifier(key)
			debugName = Key.debugName
			diagnosticName = String(reflecting: Key.self)
			valueType = String(reflecting: Key.Value.self)
		}

		static func == (lhs: Self, rhs: Self) -> Bool {
			lhs.identifier == rhs.identifier
		}

		func hash(into hasher: inout Hasher) {
			hasher.combine(identifier)
		}
	}

	private enum Entry {
		case value(any Sendable)
		case factory(token: UInt64, Factory)
		case initializing(token: UInt64, owner: ObjectIdentifier)
	}

	private let condition = NSCondition()
	private var entries = [StorageKey: Entry]()
	private var resolutionStacks = [ObjectIdentifier: [String]]()
	private var nextToken: UInt64 = 0

	private let logIdentifier = String(UUID().uuidString.prefix(8))

	func set<Key: DependencyKey>(_ value: Key.Value, for key: Key.Type) {
		let storageKey = StorageKey(key)

		condition.withLock {
			entries[storageKey] = .value(value)
			condition.broadcast()
		}

		astralLog.astralDebug(.dependencySet(
			storageID: logIdentifier,
			key: storageKey.diagnosticName,
			type: storageKey.valueType,
			mode: .eager
		))
	}

	func set<Key: DependencyKey>(
		for key: Key.Type,
		factory: @escaping @Sendable () throws -> Key.Value
	) {
		let storageKey = StorageKey(key)
		let erasedFactory: Factory = { try factory() }

		condition.withLock {
			nextToken &+= 1
			entries[storageKey] = .factory(token: nextToken, erasedFactory)
			condition.broadcast()
		}

		astralLog.astralDebug(.dependencySet(
			storageID: logIdentifier,
			key: storageKey.diagnosticName,
			type: storageKey.valueType,
			mode: .factory
		))
	}

	func resolve<Key: DependencyKey>(_ key: Key.Type) throws -> Key.Value {
		let storageKey = StorageKey(key)
		let owner = ObjectIdentifier(Thread.current)

		astralLog.astralDebug(.resolutionRequested(
			storageID: logIdentifier,
			key: storageKey.diagnosticName,
			type: storageKey.valueType
		))

		while true {
			condition.lock()

			switch entries[storageKey] {
			case let .value(value):
				condition.unlock()
				astralLog.astralDebug(.resolutionSucceeded(
					storageID: logIdentifier,
					key: storageKey.diagnosticName,
					type: storageKey.valueType,
					source: .stored
				))
				return cast(value, for: key)

			case let .factory(token, factory):
				entries[storageKey] = .initializing(token: token, owner: owner)
				resolutionStacks[owner, default: []].append(storageKey.debugName)
				condition.unlock()

				do {
					let value = try factory()
					finish(
						storageKey,
						token: token,
						owner: owner,
						replacement: .value(value)
					)
					astralLog.astralDebug(.resolutionSucceeded(
						storageID: logIdentifier,
						key: storageKey.diagnosticName,
						type: storageKey.valueType,
						source: .factory
					))
					return cast(value, for: key)
				} catch {
					finish(
						storageKey,
						token: token,
						owner: owner,
						replacement: .factory(token: token, factory)
					)
					astralLog.astralDebug(.resolutionFailed(
						storageID: logIdentifier,
						key: storageKey.diagnosticName,
						type: storageKey.valueType,
						reason: failureReason(for: error)
					))
					throw error
				}

			case let .initializing(_, initializingOwner):
				if initializingOwner == owner {
					let path = resolutionStacks[owner, default: []]
						+ [storageKey.debugName]
					condition.unlock()
					let error = DependencyResolutionError.circularDependency(path)
					astralLog.astralDebug(.resolutionFailed(
						storageID: logIdentifier,
						key: storageKey.diagnosticName,
						type: storageKey.valueType,
						reason: .circular
					))
					throw error
				}

				condition.wait()
				condition.unlock()

			case nil:
				condition.unlock()
				let error = DependencyResolutionError.notRegistered(
					storageKey.debugName
				)
				astralLog.astralDebug(.resolutionFailed(
					storageID: logIdentifier,
					key: storageKey.diagnosticName,
					type: storageKey.valueType,
					reason: .missing
				))
				throw error
			}
		}
	}

	@discardableResult
	func remove<Key: DependencyKey>(_ key: Key.Type) -> Bool {
		let storageKey = StorageKey(key)
		let existed = condition.withLock {
			let existed = entries.removeValue(forKey: storageKey) != nil
			condition.broadcast()
			return existed
		}

		astralLog.astralDebug(.dependencyRemoved(
			storageID: logIdentifier,
			key: storageKey.diagnosticName,
			existed: existed
		))
		return existed
	}

	func removeAll() {
		let removedCount = condition.withLock {
			let count = entries.count
			entries.removeAll(keepingCapacity: false)
			condition.broadcast()
			return count
		}

		astralLog.astralDebug(.scopeCleared(
			storageID: logIdentifier,
			removedCount: removedCount
		))
	}

	private func finish(
		_ key: StorageKey,
		token: UInt64,
		owner: ObjectIdentifier,
		replacement: Entry
	) {
		condition.withLock {
			popResolutionStack(for: owner)

			if case let .initializing(currentToken, currentOwner) = entries[key],
				currentToken == token,
				currentOwner == owner {
				entries[key] = replacement
			}

			condition.broadcast()
		}
	}

	private func popResolutionStack(for owner: ObjectIdentifier) {
		guard var stack = resolutionStacks[owner] else { return }
		stack.removeLast()
		resolutionStacks[owner] = stack.isEmpty ? nil : stack
	}

	private func cast<Key: DependencyKey>(
		_ value: any Sendable,
		for key: Key.Type
	) -> Key.Value {
		guard let value = value as? Key.Value else {
			preconditionFailure(
				"Astral storage invariant failed for '\(Key.debugName)'."
			)
		}
		return value
	}

	private func failureReason(for error: any Error) -> AstralResolutionFailure {
		switch error {
		case DependencyResolutionError.circularDependency:
			.circular
		case DependencyResolutionError.notRegistered:
			.missing
		default:
			.factory
		}
	}
}

private extension NSCondition {
	func withLock<Result>(_ body: () throws -> Result) rethrows -> Result {
		lock()
		defer { unlock() }
		return try body()
	}
}

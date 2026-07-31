//
//  AstralTests.swift
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
import Testing
@testable import Astral

private final class SampleDependency: Sendable {
	let identifier: Int

	init(identifier: Int) {
		self.identifier = identifier
	}
}

private protocol SampleService: Sendable {
	var identifier: Int { get }
}

private struct LiveSampleService: SampleService {
	let identifier: Int
}

private enum SampleKey: DependencyKey {
	typealias Value = SampleDependency
	static let debugName = "sample"
}

private enum AlternateSampleKey: DependencyKey {
	typealias Value = SampleDependency
	static let debugName = "sample"
}

private enum ProtocolKey: DependencyKey {
	typealias Value = any SampleService
	static let debugName = "service"
}

private enum IntegerKey: DependencyKey {
	typealias Value = Int
	static let debugName = "integer"
}

private enum DefaultNameKey: DependencyKey {
	typealias Value = Int
}

private enum FirstCycleKey: DependencyKey {
	typealias Value = Int
	static let debugName = "first"
}

private enum SecondCycleKey: DependencyKey {
	typealias Value = Int
	static let debugName = "second"
}

private enum FactoryFailure: Error, Equatable {
	case unavailable
}

private final class LockedCounter: @unchecked Sendable {
	private let lock = NSLock()
	private var count = 0

	var value: Int {
		lock.withLock { count }
	}

	@discardableResult
	func increment() -> Int {
		lock.withLock {
			count += 1
			return count
		}
	}
}

private final class BlockingFactory: @unchecked Sendable {
	private let started = DispatchSemaphore(value: 0)
	private let proceed = DispatchSemaphore(value: 0)

	func make(_ value: SampleDependency) -> SampleDependency {
		started.signal()
		proceed.wait()
		return value
	}

	func waitUntilStarted() -> Bool {
		started.wait(timeout: .now() + 2) == .success
	}

	func resume() {
		proceed.signal()
	}
}

@Suite("Scope")
struct ScopeTests {
	@Test("Sets and resolves an eager value")
	func resolvesEagerValue() throws {
		let scope = Scope()
		let dependency = SampleDependency(identifier: 1)

		scope.set(dependency, for: SampleKey.self)

		#expect(try scope.resolve(SampleKey.self) === dependency)
		#expect(scope.require(SampleKey.self) === dependency)
	}

	@Test("Registers a concrete value for a protocol key")
	func resolvesProtocolValue() throws {
		let scope = Scope()
		let dependency = LiveSampleService(identifier: 42)

		scope.set(dependency, for: ProtocolKey.self)

		#expect(try scope.resolve(ProtocolKey.self).identifier == 42)
	}

	@Test("Uses key type identity instead of value type or debug name")
	func isolatesTypedKeys() throws {
		let scope = Scope()
		let first = SampleDependency(identifier: 1)
		let second = SampleDependency(identifier: 2)

		scope.set(first, for: SampleKey.self)
		scope.set(second, for: AlternateSampleKey.self)

		#expect(try scope.resolve(SampleKey.self) === first)
		#expect(try scope.resolve(AlternateSampleKey.self) === second)
	}

	@Test("Keeps registrations isolated between scopes")
	func isolatesScopes() throws {
		let firstScope = Scope()
		let secondScope = Scope()
		let first = SampleDependency(identifier: 1)
		let second = SampleDependency(identifier: 2)

		firstScope.set(first, for: SampleKey.self)
		secondScope.set(second, for: SampleKey.self)

		#expect(try firstScope.resolve(SampleKey.self) === first)
		#expect(try secondScope.resolve(SampleKey.self) === second)
	}

	@Test("A new setting replaces either registration mode")
	func replacesRegistration() throws {
		let scope = Scope()
		let eager = SampleDependency(identifier: 1)
		let fromFactory = SampleDependency(identifier: 2)
		let replacement = SampleDependency(identifier: 3)

		scope.set(eager, for: SampleKey.self)
		scope.set(for: SampleKey.self) { fromFactory }
		#expect(try scope.resolve(SampleKey.self) === fromFactory)

		scope.set(replacement, for: SampleKey.self)
		#expect(try scope.resolve(SampleKey.self) === replacement)
	}

	@Test("Missing resolution reports the key")
	func reportsMissingRegistration() {
		let scope = Scope()

		#expect(throws: DependencyResolutionError.notRegistered("sample")) {
			try scope.resolve(SampleKey.self)
		}
	}

	@Test("Provides stable caller-readable error descriptions")
	func describesResolutionErrors() {
		#expect(
			DependencyResolutionError.notRegistered("sample").description
				== "No dependency is registered for 'sample'."
		)
		#expect(
			DependencyResolutionError.circularDependency([
				"first",
				"second",
				"first",
			]).description
				== "Circular dependency detected: first → second → first."
		)
		#expect(DefaultNameKey.debugName.contains("DefaultNameKey"))
	}

	@Test("Defers and caches one factory invocation across concurrent callers")
	func resolvesFactoryOnce() async throws {
		let scope = Scope()
		let counter = LockedCounter()

		scope.set(for: SampleKey.self) {
			SampleDependency(identifier: counter.increment())
		}

		#expect(counter.value == 0)

		let identifiers = try await withThrowingTaskGroup(
			of: ObjectIdentifier.self,
			returning: [ObjectIdentifier].self
		) { group in
			for _ in 0..<100 {
				group.addTask {
					ObjectIdentifier(try scope.resolve(SampleKey.self))
				}
			}

			return try await group.reduce(into: []) { $0.append($1) }
		}

		#expect(Set(identifiers).count == 1)
		#expect(counter.value == 1)
	}

	@Test("A failed factory is retried")
	func retriesFailedFactory() throws {
		let scope = Scope()
		let counter = LockedCounter()

		scope.set(for: SampleKey.self) {
			guard counter.increment() > 1 else {
				throw FactoryFailure.unavailable
			}
			return SampleDependency(identifier: 2)
		}

		#expect(throws: FactoryFailure.unavailable) {
			try scope.resolve(SampleKey.self)
		}
		#expect(try scope.resolve(SampleKey.self).identifier == 2)
		#expect(counter.value == 2)
	}

	@Test("Factories can resolve other dependencies")
	func composesFactories() throws {
		let scope = Scope()
		scope.set(41, for: IntegerKey.self)
		scope.set(for: SampleKey.self) {
			SampleDependency(
				identifier: try scope.resolve(IntegerKey.self) + 1
			)
		}

		#expect(try scope.resolve(SampleKey.self).identifier == 42)
	}

	@Test("Circular factories report the complete path")
	func reportsCircularDependency() {
		let scope = Scope()
		scope.set(for: FirstCycleKey.self) {
			try scope.resolve(SecondCycleKey.self)
		}
		scope.set(for: SecondCycleKey.self) {
			try scope.resolve(FirstCycleKey.self)
		}

		#expect(
			throws: DependencyResolutionError.circularDependency([
				"first",
				"second",
				"first",
			])
		) {
			try scope.resolve(FirstCycleKey.self)
		}
	}

	@Test("Removes one registration without disturbing another")
	func removesRegistration() throws {
		let scope = Scope()
		scope.set(SampleDependency(identifier: 1), for: SampleKey.self)
		scope.set(SampleDependency(identifier: 2), for: AlternateSampleKey.self)

		#expect(scope.remove(SampleKey.self))
		#expect(!scope.remove(SampleKey.self))
		#expect(throws: DependencyResolutionError.notRegistered("sample")) {
			try scope.resolve(SampleKey.self)
		}
		#expect(try scope.resolve(AlternateSampleKey.self).identifier == 2)
	}

	@Test("Removes every registration")
	func removesAllRegistrations() {
		let scope = Scope()
		scope.set(SampleDependency(identifier: 1), for: SampleKey.self)
		scope.set(42, for: IntegerKey.self)

		scope.removeAll()

		#expect(throws: DependencyResolutionError.notRegistered("sample")) {
			try scope.resolve(SampleKey.self)
		}
		#expect(throws: DependencyResolutionError.notRegistered("integer")) {
			try scope.resolve(IntegerKey.self)
		}
	}

	@Test("Removing an in-flight factory prevents late caching")
	func removesInFlightFactory() async throws {
		let scope = Scope()
		let factory = BlockingFactory()
		let dependency = SampleDependency(identifier: 1)
		scope.set(for: SampleKey.self) {
			factory.make(dependency)
		}

		let resolution = Task.detached {
			try scope.resolve(SampleKey.self)
		}

		guard factory.waitUntilStarted() else {
			factory.resume()
			Issue.record("Factory did not start before the timeout.")
			return
		}

		#expect(scope.remove(SampleKey.self))
		factory.resume()

		#expect(try await resolution.value === dependency)
		#expect(throws: DependencyResolutionError.notRegistered("sample")) {
			try scope.resolve(SampleKey.self)
		}
	}

	@Test("Replacing an in-flight factory preserves the new value")
	func replacesInFlightFactory() async throws {
		let scope = Scope()
		let factory = BlockingFactory()
		let previous = SampleDependency(identifier: 1)
		let replacement = SampleDependency(identifier: 2)
		scope.set(for: SampleKey.self) {
			factory.make(previous)
		}

		let resolution = Task.detached {
			try scope.resolve(SampleKey.self)
		}

		guard factory.waitUntilStarted() else {
			factory.resume()
			Issue.record("Factory did not start before the timeout.")
			return
		}

		scope.set(replacement, for: SampleKey.self)
		factory.resume()

		#expect(try await resolution.value === previous)
		#expect(try scope.resolve(SampleKey.self) === replacement)
	}
}

private extension Scope {
	static let wrapperTests = Scope()
}

private final class GlobalModel {
	@Dependency(SampleKey.self) var dependency
}

private final class CustomScopeModel {
	@Dependency(SampleKey.self, scope: .wrapperTests) var dependency
}

@Suite("Dependency property wrapper", .serialized)
struct DependencyTests {
	@Test("Uses the global scope implicitly")
	func usesImplicitGlobalScope() {
		defer { Scope.global.removeAll() }
		let dependency = SampleDependency(identifier: 1)
		Scope.global.set(dependency, for: SampleKey.self)

		#expect(GlobalModel().dependency === dependency)
	}

	@Test("Supports an explicit custom scope")
	func usesCustomScope() {
		defer { Scope.wrapperTests.removeAll() }
		let dependency = SampleDependency(identifier: 1)
		Scope.wrapperTests.set(dependency, for: SampleKey.self)

		#expect(CustomScopeModel().dependency === dependency)
	}

	@Test("Captures an eager snapshot")
	func capturesSnapshot() {
		defer { Scope.global.removeAll() }
		let first = SampleDependency(identifier: 1)
		let second = SampleDependency(identifier: 2)
		Scope.global.set(first, for: SampleKey.self)
		let model = GlobalModel()

		Scope.global.set(second, for: SampleKey.self)
		let secondModel = GlobalModel()
		Scope.global.removeAll()

		#expect(model.dependency === first)
		#expect(secondModel.dependency === second)
	}
}

@MainActor
private final class MainActorDependency {}

private enum MainActorKey: DependencyKey {
	typealias Value = MainActorDependency
}

@Suite("Isolation")
struct IsolationTests {
	@Test("Accepts an eagerly created main-actor dependency")
	@MainActor
	func resolvesMainActorDependency() throws {
		let scope = Scope()
		let dependency = MainActorDependency()

		scope.set(dependency, for: MainActorKey.self)

		#expect(try scope.resolve(MainActorKey.self) === dependency)
	}
}

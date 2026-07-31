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

import Testing
@testable import Astral

@Suite("Astral diagnostics", .serialized)
struct LoggingTests {
	@Test("Assigns every event to its intended level")
	func assignsEventLevels() {
		let normalEvents: [AstralLogEvent] = [
			.resolutionRequested(
				storageID: "12345678",
				key: "Example.APIClientKey",
				type: "Example.APIClient"
			),
			.resolutionSucceeded(
				storageID: "12345678",
				key: "Example.APIClientKey",
				type: "Example.APIClient",
				source: .stored
			),
			.resolutionFailed(
				storageID: "12345678",
				key: "Example.APIClientKey",
				type: "Example.APIClient",
				reason: .missing
			),
			.dependencyRemoved(
				storageID: "12345678",
				key: "Example.APIClientKey",
				existed: true
			),
			.scopeCleared(storageID: "12345678", removedCount: 2),
		]

		for event in normalEvents {
			#expect(event.logLevel == .normal)
		}

		#expect(
			AstralLogEvent.dependencySet(
				storageID: "12345678",
				key: "Example.APIClientKey",
				type: "Example.APIClient",
				mode: .factory
			).logLevel == .trace
		)
	}

	@Test("Includes only events allowed by the configured level")
	func includesExpectedLevels() {
		let expectations: [
			(configured: Astral.DebugLogLevel, event: Astral.DebugLogLevel, included: Bool)
		] = [
			(.off, .off, true),
			(.off, .normal, false),
			(.off, .trace, false),
			(.normal, .off, false),
			(.normal, .normal, true),
			(.normal, .trace, false),
			(.trace, .off, true),
			(.trace, .normal, true),
			(.trace, .trace, true),
		]

		for expectation in expectations {
			#expect(
				expectation.configured.includes(expectation.event)
					== expectation.included
			)
		}
	}

	@Test("Renders every event as a stable structured message")
	func rendersStableMessages() {
		let expectations: [(event: AstralLogEvent, message: String)] = [
			(
				.dependencySet(
					storageID: "12345678",
					key: "Example.APIClientKey",
					type: "Example.APIClient",
					mode: .factory
				),
				"[dependency][s:12345678] • set Example.APIClient | key=Example.APIClientKey mode=factory"
			),
			(
				.resolutionRequested(
					storageID: "12345678",
					key: "Example.APIClientKey",
					type: "Example.APIClient"
				),
				"[dependency][s:12345678] ⇢ resolving Example.APIClient | key=Example.APIClientKey"
			),
			(
				.resolutionSucceeded(
					storageID: "12345678",
					key: "Example.APIClientKey",
					type: "Example.APIClient",
					source: .stored
				),
				"[dependency][s:12345678] ✓ resolved Example.APIClient | key=Example.APIClientKey source=stored"
			),
			(
				.resolutionFailed(
					storageID: "12345678",
					key: "Example.APIClientKey",
					type: "Example.APIClient",
					reason: .circular
				),
				"[dependency][s:12345678] ✗ resolution failed Example.APIClient | key=Example.APIClientKey reason=circular"
			),
			(
				.dependencyRemoved(
					storageID: "12345678",
					key: "Example.APIClientKey",
					existed: true
				),
				"[dependency][s:12345678] − removed | key=Example.APIClientKey existed=true"
			),
			(
				.scopeCleared(storageID: "12345678", removedCount: 2),
				"[scope][s:12345678] ✓ removed all | count=2"
			),
		]

		for expectation in expectations {
			#expect(expectation.event.message == expectation.message)
		}
	}

	@Test("Does not render caller-provided key debug names")
	func omitsCallerDebugNames() {
		let secretName = "production-customer-token"
		let message = AstralLogEvent.dependencySet(
			storageID: "12345678",
			key: "Example.APIClientKey",
			type: "Example.APIClient",
			mode: .eager
		).message

		#expect(message.contains("key=Example.APIClientKey"))
		#expect(!message.contains(secretName))
	}

	@Test("Reads and writes configuration outside the main actor")
	func configuresOutsideMainActor() async {
		defer { Astral.debug = .off }

		let level = await Task.detached {
			Astral.debug = .normal
			return Astral.debug
		}.value

		#expect(level == .normal)
	}

	@Test("Supports concurrent configuration access")
	func supportsConcurrentConfigurationAccess() async {
		defer { Astral.debug = .off }

		let levels = [
			Astral.DebugLogLevel.off,
			.normal,
			.trace,
		]

		await withTaskGroup(of: Void.self) { group in
			for index in 0..<100 {
				group.addTask {
					Astral.debug = levels[index % levels.count]
					_ = Astral.debug
				}
			}
		}

		Astral.debug = .trace
		#expect(Astral.debug == .trace)
	}
}

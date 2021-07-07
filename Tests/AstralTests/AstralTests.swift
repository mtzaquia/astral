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

import XCTest
@testable import Astral
import OSLog

class SampleDependency {
  init() {
    Logger.astral.info("\(String(describing: self)) has been initiated.")
  }

  func use() {
    Logger.astral.info("\(String(describing: self)) has been used.")
  }
}

extension Scope {
  static let test = Scope()
}

@available(iOS 15, *)
final class AstralTests: XCTestCase {
  override func tearDown() {
    Scope.test.clear()
  }

  func testNamedInjection() async throws {
    Scope.test.register(named: "sample", SampleDependency())

    let model = ModelNameFetching()
    XCTAssertNotNil(model.namedDependency)
  }

  func testInferredInjection() async throws {
    Scope.test.register(SampleDependency())

    let model = ModelInferredFetching()
    XCTAssertNotNil(model.inferredDependency)
  }

  func testLazyInjection() async throws {
    Scope.test.register(lazy: true, SampleDependency())

    let model = ModelInferredFetching()
    XCTAssertNotNil(model.inferredDependency)
  }
}

//
//  UtilitiesTests.swift
//  LANImageUploaderTests
//

import Testing
import Foundation
@testable import LANImageUploader

struct UtilitiesTests {

    @Test func testRemovingSuffix() {
        #expect("hello.txt".removingSuffix(".txt") == "hello")
        #expect("hello".removingSuffix(".txt") == "hello")
        #expect("".removingSuffix(".txt") == "")
    }

    @Test func testCalculateRefractionOffset() {
        // angle = 0, tan(0) = 0
        let offset0 = LiquidGlassUtils.calculateRefractionOffset(depth: 10, angle: 0)
        #expect(offset0.width == 0)
        #expect(offset0.height == 0)

        // angle = 45, tan(45) = 1
        let offset45 = LiquidGlassUtils.calculateRefractionOffset(depth: 10, angle: 45)
        #expect(abs(offset45.width - 10) < 0.0001)
        #expect(abs(offset45.height - 10) < 0.0001)

        // angle = -45, tan(-45) = -1
        let offsetMinus45 = LiquidGlassUtils.calculateRefractionOffset(depth: 10, angle: -45)
        #expect(abs(offsetMinus45.width - -10) < 0.0001)
        #expect(abs(offsetMinus45.height - -10) < 0.0001)

        // angle = 30, tan(30) = 0.57735...
        let offset30 = LiquidGlassUtils.calculateRefractionOffset(depth: 10, angle: 30)
        #expect(abs(offset30.width - 5.7735) < 0.001)
        #expect(abs(offset30.height - 5.7735) < 0.001)

        // depth = 0
        let offsetDepth0 = LiquidGlassUtils.calculateRefractionOffset(depth: 0, angle: 45)
        #expect(offsetDepth0.width == 0)
        #expect(offsetDepth0.height == 0)
    }
}

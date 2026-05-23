//
//  GalleryModelsTests.swift
//  LANImageUploaderTests
//

import Testing
@testable import LANImageUploader

struct GalleryModelsTests {

    @Test func testImageRotationNextClockwise() {
        #expect(ImageRotation.degrees0.nextClockwise == .degrees90)
        #expect(ImageRotation.degrees90.nextClockwise == .degrees180)
        #expect(ImageRotation.degrees180.nextClockwise == .degrees270)
        #expect(ImageRotation.degrees270.nextClockwise == .degrees0)
    }
}

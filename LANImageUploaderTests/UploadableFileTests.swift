//
//  UploadableFileTests.swift
//  LANImageUploaderTests
//

import Testing
import Foundation
@testable import LANImageUploader

struct UploadableFileTests {

    @Test func testFileExtension() {
        #expect(UploadFileKind.jpeg.fileExtension == "jpg")
        #expect(UploadFileKind.pdf.fileExtension == "pdf")
    }

    @Test func testDisplayName() {
        #expect(UploadFileKind.jpeg.displayName == "Image")
        #expect(UploadFileKind.pdf.displayName == "PDF")
    }

    @Test func testUploadableFileInit() {
        let id = UUID()
        let url = URL(fileURLWithPath: "/tmp/test.jpg")
        let file = UploadableFile(id: id, name: "Test Image", fileURL: url, kind: .jpeg)

        #expect(file.id == id)
        #expect(file.name == "Test Image")
        #expect(file.fileURL == url)
        #expect(file.kind == .jpeg)
    }
}

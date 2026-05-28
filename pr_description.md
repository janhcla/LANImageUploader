💡 **What:** Added comprehensive test suite for `FileActor` to improve test coverage.
🎯 **Why:** `FileActor` manages critical, low-level file system operations on a background thread. Adding proper testing ensures reliability across key operations such as file/directory creation, existence checks, copying, removing, and reading contents. The tests are written within `LANImageUploaderTests/FileServiceTests.swift` following the project's testing conventions.
📊 **Coverage:** Covered all methods of the actor:
- `testDocumentsDirectory`
- `testCreateDirectory`
- `testFileExists`
- `testCopyItem`
- `testRemoveItem`
- `testContentsOfDirectoryURL`
- `testContentsOfDirectoryPath`
- `testWriteData`

✨ **Result:** Improved test coverage for `FileActor`.

Note: Tests could not be run locally as the `xcodebuild` toolchain is not available in the current bash environment, per project guidelines. They will need to be executed on an environment with the proper tools.

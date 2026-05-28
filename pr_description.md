🎯 **What:** Removed a leftover debug print statement `print("Scene phase changed from \(oldPhase) to \(newPhase)")` from `LANImageUploaderApp.swift`.
💡 **Why:** Print statements are meant for debugging and should not be included in production code. Removing it cleans up the logs and improves code health.
✅ **Verification:** Verified the removal using `git diff` and `cat`. Swift building/testing toolchain is not available in the current environment, but the code change is a safe single-line deletion.
✨ **Result:** A cleaner and more maintainable `LANImageUploaderApp.swift` file.

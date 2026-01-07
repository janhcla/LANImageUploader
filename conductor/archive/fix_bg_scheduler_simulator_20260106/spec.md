# Spec: Fix Background Scheduler on Simulator

## Overview
When running on the iOS Simulator, `BGTaskScheduler` often returns `BGTaskSchedulerErrorDomain Code=1` (unavailable) when attempting to schedule background tasks. This is expected behavior for the simulator but causes confusing error logs. The user sees "Failed to schedule daily image save: Error Domain=BGTaskSchedulerErrorDomain Code=1 "(null)"".

## Objectives
- **Suppress Simulator Errors:** Prevent the `BGTaskScheduler.submit` error from logging aggressively when running on the simulator if the error code is `unavailable`.
- **Maintain Production Behavior:** Ensure that on physical devices, genuine scheduling errors are still logged.

## Functional Requirements
- Modify `scheduleDailyImageSave` in `LANImageUploaderApp.swift`:
    - Catch the error from `BGTaskScheduler.shared.submit`.
    - Check if the error code is `BGTaskScheduler.Error.Code.unavailable`.
    - If unavailable (and we are on simulator/debug), log a friendlier message or suppress it.
    - Otherwise, log the error as usual.

## Acceptance Criteria
- Running on Simulator does not produce the "Failed to schedule daily image save..." error log for the `unavailable` code.
- Other errors (e.g., `notPermitted`) are still logged.

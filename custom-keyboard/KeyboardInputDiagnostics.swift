import Foundation
import os.log

private let inputDiagnosticsLogger = OSLog(
  subsystem: "com.nijoow.keyboard", category: "input-diagnostics")

@MainActor
final class KeyboardInputDiagnostics {
  static let shared = KeyboardInputDiagnostics()

  #if DEBUG
    private var touchCount = 0
    private var inputActionCount = 0
    private var insertCallCount = 0
    private var insertedCharacterCount = 0
    private var deleteRequestCount = 0
    private var cursorMoveRequestCount = 0
    private var hapticCount = 0
    private var nextOperationSnapshot = 100
  #endif

  private init() {}

  func recordTouch() {
    #if DEBUG
      touchCount += 1
      if touchCount.isMultiple(of: 100) { logSnapshot() }
    #endif
  }

  func recordInputAction() {
    #if DEBUG
      inputActionCount += 1
    #endif
  }

  func recordInsertRequest(characterCount: Int) {
    #if DEBUG
      insertCallCount += 1
      insertedCharacterCount += max(characterCount, 0)
      logOperationSnapshotIfNeeded()
    #endif
  }

  func recordDeleteRequest() {
    #if DEBUG
      deleteRequestCount += 1
      logOperationSnapshotIfNeeded()
    #endif
  }

  func recordCursorMoveRequest() {
    #if DEBUG
      cursorMoveRequestCount += 1
      logOperationSnapshotIfNeeded()
    #endif
  }

  func recordHaptic() {
    #if DEBUG
      hapticCount += 1
    #endif
  }

  #if DEBUG
    private var documentOperationCount: Int {
      insertCallCount + deleteRequestCount + cursorMoveRequestCount
    }

    private func logOperationSnapshotIfNeeded() {
      guard documentOperationCount >= nextOperationSnapshot else { return }
      nextOperationSnapshot = ((documentOperationCount / 100) + 1) * 100
      logSnapshot()
    }

    private func logSnapshot() {
      os_log(
        "Input diagnostics touch=%{public}d action=%{public}d insertCalls=%{public}d insertedChars=%{public}d delete=%{public}d cursor=%{public}d haptic=%{public}d",
        log: inputDiagnosticsLogger,
        type: .debug,
        touchCount,
        inputActionCount,
        insertCallCount,
        insertedCharacterCount,
        deleteRequestCount,
        cursorMoveRequestCount,
        hapticCount
      )
    }
  #endif
}

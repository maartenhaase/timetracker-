import Foundation
import AppKit
import CoreGraphics

@MainActor
final class AppActivityMonitor: NSObject, ObservableObject {
    @Published var currentAppName: String = "Onbekend"
    @Published var currentBundleIdentifier: String = ""
    @Published var isUserActive: Bool = true
    @Published var idleSeconds: TimeInterval = 0

    var trackingEnabled: Bool = true
    var idleThreshold: TimeInterval = 120
    var onActivityEnded: ((String, String, Date, Date) -> Void)?

    private var timer: Timer?
    private var sessionAppName: String?
    private var sessionBundleIdentifier: String?
    private var sessionStart: Date?

    func start() {
        guard timer == nil else { return }
        poll()
        timer = Timer.scheduledTimer(
            timeInterval: 2.0,
            target: self,
            selector: #selector(timerFired),
            userInfo: nil,
            repeats: true
        )
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        finishCurrentSession(at: Date())
    }

    @objc private func timerFired() {
        poll()
    }

    func pollNow() {
        poll()
    }

    private func poll() {
        let now = Date()
        idleSeconds = currentIdleSeconds()
        let activeNow = idleSeconds < idleThreshold

        if isUserActive != activeNow {
            isUserActive = activeNow
        }

        guard trackingEnabled else {
            finishCurrentSession(at: now)
            updateFrontmostApp()
            return
        }

        guard activeNow else {
            // Stop at the last real input moment instead of counting the idle threshold.
            let lastInput = now.addingTimeInterval(-idleSeconds)
            finishCurrentSession(at: lastInput)
            updateFrontmostApp()
            return
        }

        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let name = app.localizedName ?? "Onbekende app"
        let bundle = app.bundleIdentifier ?? ""

        currentAppName = name
        currentBundleIdentifier = bundle

        if sessionAppName != name || sessionBundleIdentifier != bundle {
            finishCurrentSession(at: now)
            sessionAppName = name
            sessionBundleIdentifier = bundle
            sessionStart = now
        } else if sessionStart == nil {
            sessionAppName = name
            sessionBundleIdentifier = bundle
            sessionStart = now
        }
    }

    private func updateFrontmostApp() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        currentAppName = app.localizedName ?? "Onbekende app"
        currentBundleIdentifier = app.bundleIdentifier ?? ""
    }

    private func finishCurrentSession(at end: Date) {
        guard let name = sessionAppName,
              let bundle = sessionBundleIdentifier,
              let start = sessionStart else { return }

        let safeEnd = max(end, start)
        if safeEnd.timeIntervalSince(start) >= 2 {
            onActivityEnded?(name, bundle, start, safeEnd)
        }

        sessionAppName = nil
        sessionBundleIdentifier = nil
        sessionStart = nil
    }

    private func currentIdleSeconds() -> TimeInterval {
        let state = CGEventSourceStateID.combinedSessionState
        let eventTypes: [CGEventType] = [
            .keyDown,
            .leftMouseDown,
            .rightMouseDown,
            .otherMouseDown,
            .mouseMoved,
            .leftMouseDragged,
            .rightMouseDragged,
            .otherMouseDragged,
            .scrollWheel
        ]

        return eventTypes
            .map { CGEventSource.secondsSinceLastEventType(state, eventType: $0) }
            .min() ?? 0
    }
}

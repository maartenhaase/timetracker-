import Foundation
import AppKit
import ApplicationServices

@MainActor
final class FinalCutMonitor: ObservableObject {
    @Published var isFinalCutFrontmost = false
    @Published var detectedLabel: String = ""
    @Published var candidateLabels: [String] = []
    @Published var hasAccessibilityPermission = AXIsProcessTrusted()

    var onActivityStarted: ((String, Date) -> Void)?
    var onActivityEnded: ((String, Date, Date) -> Void)?
    var onDetectedLabelChanged: ((String) -> Void)?
    var onFrontmostChanged: ((Bool) -> Void)?

    private var timer: Timer?
    private var activeSessionLabel: String?
    private var activeSessionStart: Date?

    func start() {
        guard timer == nil else { return }
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        setFrontmost(false)
        finishActivityIfNeeded(at: Date())
    }

    func requestAccessibilityPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        hasAccessibilityPermission = AXIsProcessTrusted()
    }

    func scanNow() { poll() }

    private func poll() {
        hasAccessibilityPermission = AXIsProcessTrusted()
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier == "com.apple.FinalCut" else {
            setFrontmost(false)
            if !detectedLabel.isEmpty {
                detectedLabel = ""
                onDetectedLabelChanged?("")
            }
            candidateLabels = []
            finishActivityIfNeeded(at: Date())
            return
        }

        setFrontmost(true)
        let labels = hasAccessibilityPermission ? extractCandidateLabels(pid: app.processIdentifier) : []
        candidateLabels = labels

        let newLabel = chooseBestLabel(from: labels)
        if newLabel != detectedLabel {
            detectedLabel = newLabel
            onDetectedLabelChanged?(newLabel)
        }

        let sessionLabel = newLabel.isEmpty ? "Final Cut Pro" : newLabel
        if activeSessionLabel != sessionLabel {
            finishActivityIfNeeded(at: Date())
            activeSessionLabel = sessionLabel
            activeSessionStart = Date()
            if let activeSessionStart { onActivityStarted?(sessionLabel, activeSessionStart) }
        } else if activeSessionStart == nil {
            activeSessionLabel = sessionLabel
            activeSessionStart = Date()
            if let activeSessionStart { onActivityStarted?(sessionLabel, activeSessionStart) }
        }
    }

    private func setFrontmost(_ value: Bool) {
        guard isFinalCutFrontmost != value else { return }
        isFinalCutFrontmost = value
        onFrontmostChanged?(value)
    }

    private func finishActivityIfNeeded(at end: Date) {
        guard let label = activeSessionLabel, let start = activeSessionStart else { return }
        if end.timeIntervalSince(start) >= 3 { onActivityEnded?(label, start, end) }
        activeSessionLabel = nil
        activeSessionStart = nil
    }

    private func chooseBestLabel(from labels: [String]) -> String {
        let ignoredExact = Set([
            "final cut pro", "browser", "viewer", "timeline", "inspector",
            "effects", "transitions", "index", "libraries", "photos and audio",
            "titles and generators"
        ])
        let ignoredContains = [
            "button", "checkbox", "menu", "toolbar", "scroll area", "split group",
            "show or hide", "close", "minimize", "zoom", "search"
        ]
        let cleaned = labels
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 3 && $0.count <= 140 }
            .filter { value in
                let lower = value.lowercased()
                return !ignoredExact.contains(lower) && !ignoredContains.contains(where: lower.contains)
            }
        if let timelineLike = cleaned.first(where: { value in
            let lower = value.lowercased()
            return lower.contains("project") || lower.contains("event") || lower.contains("library")
        }) { return timelineLike }
        return cleaned.first ?? ""
    }

    private func extractCandidateLabels(pid: pid_t) -> [String] {
        let appElement = AXUIElementCreateApplication(pid)
        var results: [String] = []

        if let focusedWindow = copyElementAttribute(appElement, kAXFocusedWindowAttribute as CFString) {
            appendTextAttributes(from: focusedWindow, into: &results)
            walk(element: focusedWindow, depth: 0, maxDepth: 4, remaining: 100, results: &results)
        }
        if let focusedElement = copyElementAttribute(appElement, kAXFocusedUIElementAttribute as CFString) {
            appendTextAttributes(from: focusedElement, into: &results)
            walk(element: focusedElement, depth: 0, maxDepth: 3, remaining: 45, results: &results)
        }

        var seen = Set<String>()
        return results.filter { item in
            let normalized = item.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = normalized.lowercased()
            guard !normalized.isEmpty, !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }

    private func walk(element: AXUIElement, depth: Int, maxDepth: Int, remaining: Int, results: inout [String]) {
        guard depth <= maxDepth, remaining > 0, results.count < 100 else { return }
        appendTextAttributes(from: element, into: &results)
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
        guard err == .success, let children = value as? [AXUIElement] else { return }
        var left = remaining
        for child in children.prefix(25) {
            guard left > 0, results.count < 100 else { break }
            walk(element: child, depth: depth + 1, maxDepth: maxDepth, remaining: left - 1, results: &results)
            left -= 1
        }
    }

    private func appendTextAttributes(from element: AXUIElement, into results: inout [String]) {
        let attributes: [CFString] = [
            kAXTitleAttribute as CFString,
            kAXValueAttribute as CFString,
            kAXDescriptionAttribute as CFString,
            kAXHelpAttribute as CFString
        ]
        for attribute in attributes {
            if let text = copyStringAttribute(element, attribute) {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.count >= 2, trimmed.count <= 180 { results.append(trimmed) }
            }
        }
    }

    private func copyStringAttribute(_ element: AXUIElement, _ attribute: CFString) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return value as? String
    }

    private func copyElementAttribute(_ element: AXUIElement, _ attribute: CFString) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }
}

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

        // Looking at the tracker itself should not inflate automatic work activity.
        if bundle == "nl.maartenhaase.timetracker" {
            finishCurrentSession(at: now)
            return
        }

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


import EventKit

struct CalendarEventItem: Identifiable, Hashable {
    var id: String
    var title: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var calendarTitle: String
}

@MainActor
final class CalendarService: ObservableObject {
    @Published var authorizationStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    @Published var todayEvents: [CalendarEventItem] = []
    @Published var tomorrowEvents: [CalendarEventItem] = []

    private let eventStore = EKEventStore()

    var canReadCalendar: Bool {
        authorizationStatus == .fullAccess || authorizationStatus == .authorized
    }

    func requestAccess() {
        if #available(macOS 14.0, *) {
            Task {
                do {
                    let granted = try await eventStore.requestFullAccessToEvents()
                    authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                    if granted { refresh() }
                } catch {
                    authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                }
            }
        }
    }

    func refresh() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        guard canReadCalendar else {
            todayEvents = []
            tomorrowEvents = []
            return
        }

        todayEvents = events(for: Date())
        tomorrowEvents = events(for: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
    }

    private func events(for date: Date) -> [CalendarEventItem] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)

        return eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map {
                CalendarEventItem(
                    id: $0.eventIdentifier ?? UUID().uuidString,
                    title: $0.title?.isEmpty == false ? $0.title! : "Afspraak",
                    startDate: $0.startDate,
                    endDate: $0.endDate,
                    isAllDay: $0.isAllDay,
                    calendarTitle: $0.calendar.title
                )
            }
    }
}

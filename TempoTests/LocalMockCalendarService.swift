import Foundation

/// A fully local, no-network CalendarService for UI previews and offline development.
final class LocalMockCalendarService: CalendarService {
    var isAuthenticated: Bool = true

    private var events: [CalendarEvent] = []
    private var calendars: [CalendarListItem] = [
        CalendarListItem(id: "primary", summary: "Personal", primary: true),
        CalendarListItem(id: "work", summary: "Work Calendar", primary: false),
        CalendarListItem(id: "family", summary: "Family", primary: false)
    ]

    init() {
        seedEvents()
    }

    private func seedEvents() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Helper to make dates
        func date(dayOffset: Int, hour: Int, minute: Int = 0) -> Date {
            calendar.date(byAdding: DateComponents(day: dayOffset, hour: hour, minute: minute), to: today) ?? today
        }

        events = [
            CalendarEvent(id: "local-1", title: "Team Standup", startDate: date(dayOffset: 0, hour: 9), endDate: date(dayOffset: 0, hour: 9, minute: 30), calendarId: "work"),
            CalendarEvent(id: "local-2", title: "Lunch with Sarah", startDate: date(dayOffset: 0, hour: 12), endDate: date(dayOffset: 0, hour: 13), calendarId: "primary"),
            CalendarEvent(id: "local-3", title: "Project Review", startDate: date(dayOffset: 1, hour: 14), endDate: date(dayOffset: 1, hour: 15, minute: 30), calendarId: "work"),
            CalendarEvent(id: "local-4", title: "Gym", startDate: date(dayOffset: 1, hour: 7), endDate: date(dayOffset: 1, hour: 8), calendarId: "primary"),
            CalendarEvent(id: "local-5", title: "Conference Day 1", startDate: date(dayOffset: 3, hour: 9), endDate: date(dayOffset: 3, hour: 17), calendarId: "work"),
            CalendarEvent(id: "local-6", title: "Conference Day 2", startDate: date(dayOffset: 4, hour: 9), endDate: date(dayOffset: 4, hour: 17), calendarId: "work"),
            CalendarEvent(id: "local-7", title: "Family Dinner", startDate: date(dayOffset: 5, hour: 18, minute: 30), endDate: date(dayOffset: 5, hour: 21), calendarId: "family"),
            CalendarEvent(id: "local-8", title: "All Hands", startDate: date(dayOffset: 7, hour: 10), endDate: date(dayOffset: 7, hour: 11), calendarId: "work"),
        ]
    }

    func fetchCalendars() async throws -> [CalendarListItem] {
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s simulated delay
        return calendars
    }

    func fetchEvents(from startDate: Date, to endDate: Date, calendarId: String) async throws -> [CalendarEvent] {
        try await Task.sleep(nanoseconds: 150_000_000) // 0.15s simulated delay
        return events.filter { event in
            let matchCalendar = calendarId == "primary" || event.calendarId == calendarId
            let matchRange = event.startDate >= startDate && event.startDate <= endDate
            return matchCalendar && matchRange
        }.sorted { $0.startDate < $1.startDate }
    }

    func createEvent(title: String, startDate: Date, endDate: Date, calendarId: String) async throws -> CalendarEvent {
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2s simulated delay
        let event = CalendarEvent(
            id: "local-\(UUID().uuidString.prefix(8))",
            title: title,
            startDate: startDate,
            endDate: endDate,
            calendarId: calendarId
        )
        events.append(event)
        return event
    }

    func deleteEvent(id: String, calendarId: String) async throws {
        try await Task.sleep(nanoseconds: 100_000_000)
        events.removeAll { $0.id == id }
    }

    func patchEvent(_ update: CalendarEventUpdate, calendarId: String) async throws -> CalendarEvent {
        try await Task.sleep(nanoseconds: 200_000_000)
        guard let idx = events.firstIndex(where: { $0.id == update.id }) else {
            throw CalendarServiceError.eventNotFound
        }
        let old = events[idx]
        let updated = CalendarEvent(
            id: old.id,
            title: update.title ?? old.title,
            startDate: update.startDate ?? old.startDate,
            endDate: update.endDate ?? old.endDate,
            calendarId: old.calendarId
        )
        events[idx] = updated
        return updated
    }
}

// MARK: - Local Mock Data Tests

import XCTest

final class LocalMockCalendarServiceTests: XCTestCase {

    func testFetchCalendarsReturnsThree() async throws {
        let mock = LocalMockCalendarService()
        let calendars = try await mock.fetchCalendars()
        XCTAssertEqual(calendars.count, 3)
        XCTAssertTrue(calendars.contains { $0.id == \"primary\" && $0.primary })
    }

    func testFetchEventsFiltersByDateRange() async throws {
        let mock = LocalMockCalendarService()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        let events = try await mock.fetchEvents(from: today, to: tomorrow, calendarId: \"primary\")
        // Should include events on today and tomorrow in primary calendar
        XCTAssertTrue(events.allSatisfy { $0.calendarId == \"primary\" })
    }

    func testCreateEventAddsToList() async throws {
        let mock = LocalMockCalendarService()
        let before = try await mock.fetchEvents(from: Date.distantPast, to: Date.distantFuture, calendarId: \"primary\")
        let beforeCount = before.count

        _ = try await mock.createEvent(
            title: \"New Event\",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            calendarId: \"primary\"
        )

        let after = try await mock.fetchEvents(from: Date.distantPast, to: Date.distantFuture, calendarId: \"primary\")
        XCTAssertEqual(after.count, beforeCount + 1)
    }

    func testPatchEventUpdatesTitle() async throws {
        let mock = LocalMockCalendarService()
        let update = CalendarEventUpdate(id: \"local-1\", title: \"Updated Standup\")
        let result = try await mock.patchEvent(update, calendarId: \"work\")
        XCTAssertEqual(result.title, \"Updated Standup\")
    }

    func testPatchEventNotFoundThrows() async throws {
        let mock = LocalMockCalendarService()
        let update = CalendarEventUpdate(id: \"nonexistent\", title: \"Ghost\")
        do {
            _ = try await mock.patchEvent(update, calendarId: \"primary\")
            XCTFail(\"Should throw eventNotFound\")
        } catch let error as CalendarServiceError {
            if case .eventNotFound = error { } // Expected
            else { XCTFail(\"Wrong error: \\(error)\") }
        }
    }

    func testDeleteEventRemovesFromList() async throws {
        let mock = LocalMockCalendarService()
        let before = try await mock.fetchEvents(from: Date.distantPast, to: Date.distantFuture, calendarId: \"primary\")
        let beforeIds = Set(before.map { $0.id })

        try await mock.deleteEvent(id: \"local-2\", calendarId: \"primary\")

        let after = try await mock.fetchEvents(from: Date.distantPast, to: Date.distantFuture, calendarId: \"primary\")
        XCTAssertFalse(after.map { $0.id }.contains(\"local-2\"))
        XCTAssertEqual(before.count - 1, after.count)
    }
}

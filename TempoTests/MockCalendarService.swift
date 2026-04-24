import XCTest
@testable import Tempo

// MARK: - Mock CalendarService

final class MockCalendarService: CalendarService {
    var isAuthenticated: Bool = true

    var fetchCalendarsResult: Result<[CalendarListItem], Error> = .success([])
    var fetchEventsResult: Result<[CalendarEvent], Error> = .success([])
    var createEventResult: Result<CalendarEvent, Error> = .success(CalendarEvent(
        id: "mock-1", title: "Test Event", startDate: Date(), endDate: Date(), calendarId: "primary"
    ))
    var deleteEventResult: Result<Void, Error> = .success(())

    func fetchCalendars() async throws -> [CalendarListItem] {
        try fetchCalendarsResult.get()
    }

    func fetchEvents(from: Date, to: Date, calendarId: String) async throws -> [CalendarEvent] {
        try fetchEventsResult.get()
    }

    func createEvent(title: String, startDate: Date, endDate: Date, calendarId: String) async throws -> CalendarEvent {
        try createEventResult.get()
    }

    func deleteEvent(id: String, calendarId: String) async throws {
        try deleteEventResult.get()
    }
}

// MARK: - Tests

final class CalendarServiceTests: XCTestCase {

    func testCalendarServiceErrorDescriptions() {
        XCTAssertNotNil(CalendarServiceError.notAuthenticated.errorDescription)
        XCTAssertNotNil(CalendarServiceError.networkError(NSError(domain: "", code: 0)).errorDescription)
        XCTAssertNotNil(CalendarServiceError.parseError.errorDescription)
        XCTAssertNotNil(CalendarServiceError.calendarNotFound.errorDescription)
        XCTAssertNotNil(CalendarServiceError.eventNotFound.errorDescription)
    }

    func testMockFetchCalendarsSuccess() async throws {
        let mock = MockCalendarService()
        mock.fetchCalendarsResult = .success([
            CalendarListItem(id: "primary", summary: "Primary Calendar", primary: true)
        ])
        let calendars = try await mock.fetchCalendars()
        XCTAssertEqual(calendars.count, 1)
        XCTAssertEqual(calendars[0].id, "primary")
        XCTAssertTrue(calendars[0].primary)
    }

    func testMockFetchEventsSuccess() async throws {
        let mock = MockCalendarService()
        let now = Date()
        let event = CalendarEvent(id: "e1", title: "Team Sync", startDate: now, endDate: now.addingTimeInterval(3600), calendarId: "primary")
        mock.fetchEventsResult = .success([event])

        let events = try await mock.fetchEvents(from: now, to: now, calendarId: "primary")
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].title, "Team Sync")
    }

    func testMockCreateEventSuccess() async throws {
        let mock = MockCalendarService()
        let event = try await mock.createEvent(title: "New Event", startDate: Date(), endDate: Date(), calendarId: "primary")
        XCTAssertEqual(event.title, "Test Event") // From mock default
    }

    func testMockDeleteEventSuccess() async throws {
        let mock = MockCalendarService()
        try await mock.deleteEvent(id: "e1", calendarId: "primary")
    }

    func testMockFetchCalendarsFailure() async throws {
        let mock = MockCalendarService()
        mock.fetchCalendarsResult = .failure(CalendarServiceError.networkError(NSError(domain: "", code: -1)))
        do {
            _ = try await mock.fetchCalendars()
            XCTFail("Expected error")
        } catch let error as CalendarServiceError {
            if case .networkError = error { } // Expected
            else { XCTFail("Wrong error type") }
        }
    }

    func testMockFetchEventsFailure() async throws {
        let mock = MockCalendarService()
        mock.fetchEventsResult = .failure(CalendarServiceError.notAuthenticated)
        do {
            _ = try await mock.fetchEvents(from: Date(), to: Date(), calendarId: "primary")
            XCTFail("Expected error")
        } catch let error as CalendarServiceError {
            if case .notAuthenticated = error { } // Expected
            else { XCTFail("Wrong error type") }
        }
    }
}

// MARK: - CalendarEvent Tests

final class CalendarEventTests: XCTestCase {

    func testAllDayEventTrue() {
        var components = DateComponents()
        components.year = 2025
        components.month = 6
        components.day = 15
        components.hour = 0
        components.minute = 0
        let start = Calendar.current.date(from: components)!

        components.hour = 0
        components.minute = 0
        let end = Calendar.current.date(from: components)!.addingTimeInterval(-1) // midnight previous day

        // Actually let's test a same-day all-day scenario properly
        let allDayStart = Calendar.current.date(from: DateComponents(year: 2025, month: 6, day: 15))!
        let allDayEnd = Calendar.current.date(from: DateComponents(year: 2025, month: 6, day: 16))!
        let event = CalendarEvent(id: "1", title: "All Day", startDate: allDayStart, endDate: allDayEnd, calendarId: "primary")
        XCTAssertTrue(event.isAllDay)
    }

    func testAllDayEventFalse() {
        let start = Date()
        let end = start.addingTimeInterval(3600)
        let event = CalendarEvent(id: "2", title: "Timed", startDate: start, endDate: end, calendarId: "primary")
        XCTAssertFalse(event.isAllDay)
    }
}

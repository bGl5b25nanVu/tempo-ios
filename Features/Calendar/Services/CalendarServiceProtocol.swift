import Foundation

// MARK: - Models

struct CalendarEvent: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let calendarId: String

    var isAllDay: Bool {
        Calendar.current.isDate(startDate, inSameDayAs: endDate) && Calendar.current.component(.hour, from: endDate) == 0
    }
}

struct CalendarListItem: Identifiable, Codable, Equatable {
    let id: String
    let summary: String
    let primary: Bool
}

// MARK: - Errors

enum CalendarServiceError: Error, LocalizedError {
    case notAuthenticated
    case networkError(Error)
    case parseError
    case calendarNotFound
    case eventNotFound

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "User is not authenticated with Google."
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        case .parseError: return "Failed to parse calendar response."
        case .calendarNotFound: return "Calendar not found."
        case .eventNotFound: return "Event not found."
        }
    }
}

// MARK: - Protocol

/// Protocol defining the calendar service interface.
/// Implement this to provide a real Google Calendar backend or a mock for testing.
protocol CalendarService: AnyObject {
    /// Fetches the user's calendar list.
    func fetchCalendars() async throws -> [CalendarListItem]

    /// Fetches events from the primary calendar within a date range.
    /// - Parameters:
    ///   - startDate: Start of the range (inclusive).
    ///   - endDate: End of the range (inclusive).
    ///   - calendarId: The calendar ID (use "primary" for the user's main calendar).
    func fetchEvents(from startDate: Date, to endDate: Date, calendarId: String) async throws -> [CalendarEvent]

    /// Creates a new event.
    /// - Parameters:
    ///   - title: Event title.
    ///   - startDate: Event start.
    ///   - endDate: Event end.
    ///   - calendarId: Target calendar ID.
    func createEvent(title: String, startDate: Date, endDate: Date, calendarId: String) async throws -> CalendarEvent

    /// Deletes an event by ID.
    func deleteEvent(id: String, calendarId: String) async throws

    /// Patches (partially updates) an existing event.
    /// Only non-nil fields in `update` are applied.
    func patchEvent(_ update: CalendarEventUpdate, calendarId: String) async throws -> CalendarEvent

    /// Whether the service is currently authenticated.
    var isAuthenticated: Bool { get }
}

// MARK: - Event Update Payload

/// Fields that can be optionally updated on an existing event.
/// All fields are optional — only provided values are sent to the API.
struct CalendarEventUpdate: Codable, Equatable {
    var id: String
    var title: String?
    var startDate: Date?
    var endDate: Date?

    init(id: String, title: String? = nil, startDate: Date? = nil, endDate: Date? = nil) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
    }
}

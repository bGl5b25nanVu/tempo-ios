import Foundation

/// Google Calendar API v3 service implementation using native URLSession.
final class GoogleCalendarService: CalendarService {

    private let auth: GoogleCalendarAuth
    private let baseURL = "https://www.googleapis.com/calendar/v3"
    private let session: URLSession

    var isAuthenticated: Bool { auth.state.isSignedIn }

    init(auth: GoogleCalendarAuth = .shared) {
        self.auth = auth
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Private Helpers

    private func makeRequest(
        path: String,
        queryItems: [URLQueryItem] = [],
        method: String = "GET",
        body: Data? = nil
    ) async throws -> Data {
        guard let token = await auth.getValidAccessToken() else {
            throw CalendarServiceError.notAuthenticated
        }

        var components = URLComponents(string: "\(baseURL)\(path)")!
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = body
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CalendarServiceError.networkError(URLError(.badServerResponse))
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw CalendarServiceError.networkError(
                NSError(domain: "GoogleCalendarService",
                        code: httpResponse.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
            )
        }

        return data
    }

    // MARK: - CalendarService

    func fetchCalendars() async throws -> [CalendarListItem] {
        let data = try await makeRequest(
            path: "/users/me/calendarList",
            queryItems: [URLQueryItem(name: "maxResults", value: "100")]
        )

        struct Response: Decodable {
            let items: [CalendarEntry]?
        }
        struct CalendarEntry: Decodable {
            let id: String
            let summary: String?
            let primary: Bool?

            enum CodingKeys: String, CodingKey {
                case id, summary, primary
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                id = try container.decode(String.self, forKey: .id)
                summary = try container.decodeIfPresent(String.self, forKey: .summary)
                primary = try container.decodeIfPresent(Bool.self, forKey: .primary)
            }
        }

        let response = try JSONDecoder().decode(Response.self, from: data)
        return (response.items ?? []).map { entry in
            CalendarListItem(
                id: entry.id,
                summary: entry.summary ?? entry.id,
                primary: entry.primary ?? false
            )
        }
    }

    func fetchEvents(from startDate: Date, to endDate: Date, calendarId: String) async throws -> [CalendarEvent] {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        let queryItems = [
            URLQueryItem(name: "timeMin", value: isoFormatter.string(from: startDate)),
            URLQueryItem(name: "timeMax", value: isoFormatter.string(from: endDate)),
            URLQueryItem(name: "maxResults", value: "250"),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime")
        ]

        let data = try await makeRequest(
            path: "/calendars/\(calendarId)/events",
            queryItems: queryItems
        )

        struct EventsResponse: Decodable {
            let items: [EventEntry]?
        }
        struct EventEntry: Decodable {
            let id: String
            let summary: String?
            let start: EventDateTime?
            let end: EventDateTime?
        }
        struct EventDateTime: Decodable {
            let dateTime: String?   // ISO 8601 datetime for timed events
            let date: String?        // Date only for all-day events
            let timeZone: String?
        }

        let response = try JSONDecoder().decode(EventsResponse.self, from: data)
        return (response.items ?? []).compactMap { entry in
            guard let title = entry.summary else { return nil }

            let startStr = entry.start?.dateTime ?? entry.start?.date
            let endStr = entry.end?.dateTime ?? entry.end?.date
            guard let start = startStr, let end = endStr else { return nil }

            let startDate: Date
            let endDate: Date

            if entry.start?.dateTime != nil {
                // Timed event — parse ISO 8601
                startDate = isoFormatter.date(from: start) ?? Date(timeIntervalSince1970: 0)
                endDate = isoFormatter.date(from: end) ?? Date(timeIntervalSince1970: 0)
            } else {
                // All-day event — date only (YYYY-MM-DD)
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                dateFormatter.timeZone = TimeZone(identifier: "UTC")
                startDate = dateFormatter.date(from: start) ?? Date(timeIntervalSince1970: 0)
                endDate = dateFormatter.date(from: end) ?? Date(timeIntervalSince1970: 0)
            }

            return CalendarEvent(
                id: entry.id,
                title: title,
                startDate: startDate,
                endDate: endDate,
                calendarId: calendarId
            )
        }
    }

    func createEvent(title: String, startDate: Date, endDate: Date, calendarId: String) async throws -> CalendarEvent {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withTimeZoneDetail]

        let eventBody: [String: Any] = [
            "summary": title,
            "start": [
                "dateTime": isoFormatter.string(from: startDate),
                "timeZone": TimeZone.current.identifier
            ],
            "end": [
                "dateTime": isoFormatter.string(from: endDate),
                "timeZone": TimeZone.current.identifier
            ]
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: eventBody)

        let data = try await makeRequest(
            path: "/calendars/\(calendarId)/events",
            method: "POST",
            body: bodyData
        )

        struct EventEntry: Decodable {
            let id: String
            let summary: String?
        }

        let entry = try JSONDecoder().decode(EventEntry.self, from: data)
        return CalendarEvent(
            id: entry.id,
            title: entry.summary ?? title,
            startDate: startDate,
            endDate: endDate,
            calendarId: calendarId
        )
    }

    func deleteEvent(id: String, calendarId: String) async throws {
        _ = try await makeRequest(
            path: "/calendars/\(calendarId)/events/\(id)",
            method: "DELETE"
        )
    }
}

import Foundation
import SwiftUI

/// ViewModel that bridges CalendarView with the Google Calendar service.
@MainActor
final class CalendarViewModel: ObservableObject {
    @Published var events: [CalendarEvent] = []
    @Published var calendars: [CalendarListItem] = []
    @Published var selectedCalendarId: String = "primary"
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedDate: Date = Date()

    private let auth: GoogleCalendarAuth
    private let calendarService: CalendarService

    init(auth: GoogleCalendarAuth = .shared,
         calendarService: CalendarService = GoogleCalendarService()) {
        self.auth = auth
        self.calendarService = calendarService
    }

    var isAuthenticated: Bool { auth.state.isSignedIn }

    // MARK: - Load

    func loadEvents(for date: Date) async {
        guard calendarService.isAuthenticated else {
            errorMessage = "Not signed in."
            return
        }

        isLoading = true
        errorMessage = nil

        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

        do {
            events = try await calendarService.fetchEvents(
                from: startOfMonth,
                to: endOfMonth,
                calendarId: selectedCalendarId
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadCalendars() async {
        guard calendarService.isAuthenticated else { return }
        do {
            calendars = try await calendarService.fetchCalendars()
            if let primary = calendars.first(where: { $0.primary }) {
                selectedCalendarId = primary.id
            } else if let first = calendars.first {
                selectedCalendarId = first.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Auth

    func signIn(anchor: ASPresentationAnchor) async {
        await auth.signIn(anchor: anchor)
        if auth.state.isSignedIn {
            await loadCalendars()
            await loadEvents(for: selectedDate)
        }
    }

    func signOut() {
        auth.signOut()
        events = []
        calendars = []
    }
}

import SwiftUI

@main
struct TempoApp: App {
    init() {
        // Start listening for App Store transaction updates (purchases, renewals, refunds)
        TransactionListener.shared.startListening()
    }

    var body: some Scene {
        WindowGroup {
            CalendarView()
        }
    }
}
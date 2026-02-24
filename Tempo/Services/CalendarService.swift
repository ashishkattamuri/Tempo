import Foundation
import EventKit

protocol CalendarServiceProtocol {
    func requestAccess() async throws -> Bool
    func fetchCalendars() -> [EKCalendar]
    func fetchEvents(from calendars: [EKCalendar],
                     start: Date,
                     end: Date) -> [EKEvent]
}

final class CalendarService: CalendarServiceProtocol {
    
    private let eventStore = EKEventStore()
    
    func requestAccess() async throws -> Bool {
        return try await eventStore.requestFullAccessToEvents()
    }
    
    func fetchCalendars() -> [EKCalendar] {
        eventStore.calendars(for: .event)
    }
    
    func fetchEvents(from calendars: [EKCalendar],
                     start: Date,
                     end: Date) -> [EKEvent] {
        
        let predicate = eventStore.predicateForEvents(withStart: start,
                                                      end: end,
                                                      calendars: calendars)
        
        return eventStore.events(matching: predicate)
    }
}
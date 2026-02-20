import SwiftUI
import EventKit
import SwiftData

struct CalendarImportView: View {
    
    @Environment(\.modelContext) private var modelContext
    
    private let calendarService: CalendarServiceProtocol = CalendarService()
    
    @State private var calendars: [EKCalendar] = []
    @State private var selectedCalendars: Set<String> = []
    @State private var accessGranted = false
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        List {
            Section(header: Text("Permission")) {
                Button("Request Calendar Access") {
                    Task {
                        await requestAccess()
                    }
                }
            }
            
            if accessGranted {
                Section(header: Text("Select Calendars")) {
                    ForEach(calendars, id: \.calendarIdentifier) { calendar in
                        Toggle(
                            calendar.title,
                            isOn: Binding(
                                get: {
                                    selectedCalendars.contains(calendar.calendarIdentifier)
                                },
                                set: { value in
                                    if value {
                                        selectedCalendars.insert(calendar.calendarIdentifier)
                                    } else {
                                        selectedCalendars.remove(calendar.calendarIdentifier)
                                    }
                                }
                            )
                        )
                    }
                }
                
                Section {
                    Button {
                        importEvents()
                    } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Import Next 7 Days")
                        }
                    }
                    .disabled(selectedCalendars.isEmpty || isLoading)
                }
            }
        }
        .navigationTitle("Calendar Import")
        .alert("Calendar Import", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
}

// MARK: - Logic

private extension CalendarImportView {
    
    func requestAccess() async {
        do {
            accessGranted = try await calendarService.requestAccess()
            if accessGranted {
                calendars = calendarService.fetchCalendars()
            }
        } catch {
            alertMessage = "Failed to request calendar access."
            showAlert = true
        }
    }
    
    func importEvents() {
        guard accessGranted else { return }
        
        isLoading = true
        
        Task {
            let selected = calendars.filter {
                selectedCalendars.contains($0.calendarIdentifier)
            }
            
            let startDate = Date()
            let endDate = Calendar.current.date(byAdding: .day,
                                                value: 7,
                                                to: startDate) ?? startDate
            
            let events = calendarService.fetchEvents(
                from: selected,
                start: startDate,
                end: endDate
            )
            
            var importedCount = 0
            
            for event in events {
                
                let duration = Int(event.endDate.timeIntervalSince(event.startDate) / 60)
                
                let item = ScheduleItem(
                    title: event.title ?? "Untitled Event",
                    category: .nonNegotiable, startTime: event.startDate,
                    durationMinutes: max(duration, 1),
                    notes: "Imported from Apple Calendar"
                )
                
                modelContext.insert(item)
                importedCount += 1
            }
            
            do {
                try modelContext.save()
            } catch {
                print("Failed to save imported events:", error)
            }
            
            isLoading = false
            alertMessage = "Imported \(importedCount) events."
            showAlert = true
        }
    }
}

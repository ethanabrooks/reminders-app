import EventKit
import Foundation

final class RemindersService {
    private let store = EKEventStore()

    // MARK: - Permission Management

    func ensureAccess() async throws {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        if status == .authorized { return }

        if #available(iOS 17.0, *) {
            let granted = try await store.requestFullAccessToReminders()
            guard granted else {
                throw RemindersError.permissionDenied
            }
        } else {
            let granted = try await store.requestAccess(to: .reminder)
            guard granted else {
                throw RemindersError.permissionDenied
            }
        }
    }

    // MARK: - List Operations

    func reminderCalendars() -> [EKCalendar] {
        store.calendars(for: .reminder)
    }

    func listCalendarsDTO() -> [CalendarDTO] {
        reminderCalendars().map { calendar in
            CalendarDTO(
                id: calendar.calendarIdentifier,
                title: calendar.title
            )
        }
    }

    // MARK: - Task CRUD
    
    func createReminder(
        title: String,
        notes: String?,
        listId: String?,
        dueDateISO: String?,
        dueTimeISO: String?,
        priority: String?
    ) throws -> EKReminder {
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.notes = notes

        // Set calendar (list)
        if let id = listId, let cal = store.calendar(withIdentifier: id) {
            reminder.calendar = cal
        } else {
            reminder.calendar = store.defaultCalendarForNewReminders()
        }

        // Set due date and alarm
        var components: DateComponents?
        
        if let dateISO = dueDateISO {
            // Parse date-only string (YYYY-MM-DD)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            
            if let date = dateFormatter.date(from: dateISO) {
                components = Calendar.current.dateComponents(
                    [.year, .month, .day],
                    from: date
                )
            }
        } else if let timeISO = dueTimeISO {
            // If only time is provided, default to today's date
            components = Calendar.current.dateComponents(
                [.year, .month, .day],
                from: Date()
            )
        }
        
        // Add time components if provided
        if let timeISO = dueTimeISO, var comps = components {
            // Expected format: HH:mm:ss or HH:mm
            let parts = timeISO.split(separator: ":")
            if parts.count >= 2,
               let hour = Int(parts[0]),
               let minute = Int(parts[1]) {
                comps.hour = hour
                comps.minute = minute
                if parts.count > 2, let second = Int(parts[2]) {
                    comps.second = second
                }
                components = comps
            }
        }
        
        // Set the date components and alarm if we have valid components
        if let comps = components {
            reminder.dueDateComponents = comps
            
            if let finalDate = Calendar.current.date(from: comps) {
                reminder.addAlarm(EKAlarm(absoluteDate: finalDate))
            }
        }
        
        // Set priority
        if let priorityStr = priority {
            reminder.priority = priorityToInt(priorityStr)
        }

        try store.save(reminder, commit: true)
        return reminder
    }

    func listTasks(listId: String?, completed: Bool?) -> [EKReminder] {
        let calendars: [EKCalendar]
        if let id = listId, let cal = store.calendar(withIdentifier: id) {
            calendars = [cal]
        } else {
            calendars = store.calendars(for: .reminder)
        }

        let predicate = store.predicateForReminders(in: calendars)
        var results: [EKReminder] = []
        let semaphore = DispatchSemaphore(value: 0)

        store.fetchReminders(matching: predicate) { reminders in
            results = reminders?.filter { reminder in
                guard let completedFilter = completed else { return true }
                return completedFilter ? reminder.isCompleted : !reminder.isCompleted
            } ?? []
            semaphore.signal()
        }

        semaphore.wait()
        return results
    }

    func completeTask(taskId: String) throws -> EKReminder {
        guard let reminder = store.calendarItem(withIdentifier: taskId) as? EKReminder else {
            throw RemindersError.taskNotFound(taskId)
        }

        reminder.isCompleted = true
        reminder.completionDate = Date()
        try store.save(reminder, commit: true)
        return reminder
    }

    func updateTask(
        taskId: String,
        title: String?,
        notes: String?,
        dueDateISO: String?,
        dueTimeISO: String?,
        priority: String?
    ) throws -> EKReminder {
        guard let reminder = store.calendarItem(withIdentifier: taskId) as? EKReminder else {
            throw RemindersError.taskNotFound(taskId)
        }

        if let t = title { reminder.title = t }
        if let n = notes { reminder.notes = n }

        if let dateISO = dueDateISO {
            // Parse date-only string (YYYY-MM-DD)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            
            if let date = dateFormatter.date(from: dateISO) {
                // Start with just the date components from the new date
                var components = Calendar.current.dateComponents(
                    [.year, .month, .day],
                    from: date
                )
                
                // If a new time is provided, use it.
                if let timeISO = dueTimeISO {
                    let parts = timeISO.split(separator: ":")
                    if parts.count >= 2,
                       let hour = Int(parts[0]),
                       let minute = Int(parts[1]) {
                        components.hour = hour
                        components.minute = minute
                        if parts.count > 2, let second = Int(parts[2]) {
                            components.second = second
                        }
                    }
                } else {
                    // If no new time is provided, it becomes an all-day task (time is cleared)
                }
                
                reminder.dueDateComponents = components
                if let finalDate = Calendar.current.date(from: components) {
                    reminder.alarms = [EKAlarm(absoluteDate: finalDate)]
                }
            }
        } else if let timeISO = dueTimeISO {
            // Only time provided. We should probably attach this to today's date or the existing date?
            // But the schema says date defaults to today if omitted but time provided.
            // However, this is UPDATE.
            // If updating time only, we should likely keep the existing date.
            
            if var existingComps = reminder.dueDateComponents {
                // Update time on existing date
                let parts = timeISO.split(separator: ":")
                if parts.count >= 2,
                   let hour = Int(parts[0]),
                   let minute = Int(parts[1]) {
                    existingComps.hour = hour
                    existingComps.minute = minute
                    if parts.count > 2, let second = Int(parts[2]) {
                        existingComps.second = second
                    }
                    reminder.dueDateComponents = existingComps
                    if let finalDate = Calendar.current.date(from: existingComps) {
                        reminder.alarms = [EKAlarm(absoluteDate: finalDate)]
                    }
                }
            }
        }
        
        // Update priority if provided
        if let priorityStr = priority {
            reminder.priority = priorityToInt(priorityStr)
        }

        try store.save(reminder, commit: true)
        return reminder
    }

    func deleteTask(taskId: String) throws {
        guard let reminder = store.calendarItem(withIdentifier: taskId) as? EKReminder else {
            return // Already deleted or doesn't exist
        }

        try store.remove(reminder, commit: true)
    }

    // MARK: - Priority Helpers
    
    private func priorityToInt(_ priority: String) -> Int {
        switch priority.lowercased() {
        case "high":
            return 1
        case "medium":
            return 5
        case "low":
            return 9
        case "none", "":
            return 0
        default:
            return 0
        }
    }
    
    private func intToPriority(_ priority: Int) -> String {
        // EventKit priority: 0=none, 1=high, 5=medium, 9=low
        switch priority {
        case 1:
            return "high"
        case 5:
            return "medium"
        case 9:
            return "low"
        case 0:
            return "none"
        default:
            // Handle any unexpected values - treat as none
            print("⚠️ Unexpected priority value: \(priority), defaulting to 'none'")
            return "none"
        }
    }

    // MARK: - DTO Conversion

    func toDTO(_ reminder: EKReminder) -> ReminderDTO {
        var dueISO: String?
        if let comps = reminder.dueDateComponents,
           let date = Calendar.current.date(from: comps) {
            dueISO = ISO8601DateFormatter().string(from: date)
        }

        var completedISO: String?
        if let date = reminder.completionDate {
            completedISO = ISO8601DateFormatter().string(from: date)
        }

        let priorityString = intToPriority(reminder.priority)
        // Debug: log priority conversion
        if reminder.priority != 0 {
            print("📋 Task '\(reminder.title ?? "unknown")': EventKit priority=\(reminder.priority) -> '\(priorityString)'")
        }
        
        return ReminderDTO(
            id: reminder.calendarItemIdentifier,
            listId: reminder.calendar.calendarIdentifier,
            title: reminder.title ?? "",
            notes: reminder.notes ?? "",
            status: reminder.isCompleted ? "completed" : "needsAction",
            dueISO: dueISO,
            completedISO: completedISO,
            priority: priorityString,
            url: "gptreminders://task/\(reminder.calendarItemIdentifier)"
        )
    }
}

// MARK: - Errors

enum RemindersError: LocalizedError {
    case permissionDenied
    case taskNotFound(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Reminders permission denied"
        case .taskNotFound(let id):
            return "Task not found: \(id)"
        }
    }
}

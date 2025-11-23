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
        dueISO: String?
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
        if let iso = dueISO, let date = ISO8601DateFormatter().date(from: iso) {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: date
            )
            reminder.addAlarm(EKAlarm(absoluteDate: date))
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
        dueISO: String?
    ) throws -> EKReminder {
        guard let reminder = store.calendarItem(withIdentifier: taskId) as? EKReminder else {
            throw RemindersError.taskNotFound(taskId)
        }

        if let t = title { reminder.title = t }
        if let n = notes { reminder.notes = n }

        if let iso = dueISO {
            if let date = ISO8601DateFormatter().date(from: iso) {
                reminder.dueDateComponents = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: date
                )
                // Replace alarms for simplicity
                reminder.alarms = [EKAlarm(absoluteDate: date)]
            } else {
                reminder.dueDateComponents = nil
                reminder.alarms = []
            }
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

        return ReminderDTO(
            id: reminder.calendarItemIdentifier,
            listId: reminder.calendar.calendarIdentifier,
            title: reminder.title ?? "",
            notes: reminder.notes ?? "",
            status: reminder.isCompleted ? "completed" : "needsAction",
            dueISO: dueISO,
            completedISO: completedISO,
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

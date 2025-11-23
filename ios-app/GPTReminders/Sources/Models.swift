import Foundation

// MARK: - Command Enums

enum CommandKind: String, Codable {
    case listLists = "list_lists"
    case listTasks = "list_tasks"
    case createTask = "create_task"
    case updateTask = "update_task"
    case completeTask = "complete_task"
    case deleteTask = "delete_task"
}

// MARK: - Envelopes

struct CommandMetadata: Decodable {
    let id: String
    let kind: CommandKind
    // We don't decode payload here, we do it specifically later
}

struct CommandWithPayload<T: Decodable>: Decodable {
    let payload: T
}

// MARK: - Payloads

struct CreateTaskPayload: Decodable {
    let title: String
    let notes: String?
    let list_id: String?
    let due_iso: String?
}

struct UpdateTaskPayload: Decodable {
    let task_id: String
    let title: String?
    let notes: String?
    let due_iso: String?
}

struct TaskActionPayload: Decodable {
    let task_id: String
}

struct ListTasksPayload: Decodable {
    let list_id: String?
    let status: String?
}

// MARK: - DTOs

struct CalendarDTO: Codable {
    let id: String
    let title: String
}

struct ReminderDTO: Codable {
    let id: String
    let listId: String
    let title: String
    let notes: String
    let status: String
    let dueISO: String?
    let completedISO: String?
    let url: String
}

struct EmptyResult: Codable {
    let ok: Bool
}

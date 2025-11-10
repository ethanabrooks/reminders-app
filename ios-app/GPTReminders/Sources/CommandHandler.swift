import Foundation
import EventKit

/// Handles incoming commands from the server
final class CommandHandler {
    private let remindersService = RemindersService()
    private let jwtVerifier: JWTVerifier
    private let serverURL: URL

    init(publicKeyPEM: String, serverURL: URL) throws {
        self.jwtVerifier = try JWTVerifier(pemString: publicKeyPEM)
        self.serverURL = serverURL
    }

    // MARK: - Command Processing

    func processCommand(envelope: String) async throws -> Any {
        // Verify JWT signature
        let payload = try jwtVerifier.verify(token: envelope)

        guard let commandId = payload["id"] as? String,
              let kind = payload["kind"] as? String,
              let commandPayload = payload["payload"] as? [String: Any] else {
            throw CommandError.invalidPayload
        }

        print("📥 Processing command: \(kind) [\(commandId)]")

        // Ensure reminders access
        try await remindersService.ensureAccess()

        // Execute command
        let result: Any
        switch kind {
        case "list_lists":
            result = try handleListLists()

        case "list_tasks":
            result = try handleListTasks(payload: commandPayload)

        case "create_task":
            result = try handleCreateTask(payload: commandPayload)

        case "update_task":
            result = try handleUpdateTask(payload: commandPayload)

        case "complete_task":
            result = try handleCompleteTask(payload: commandPayload)

        case "delete_task":
            result = try handleDeleteTask(payload: commandPayload)

        default:
            throw CommandError.unknownOperation(kind)
        }

        // Send result to server
        try await sendResult(commandId: commandId, success: true, result: result)

        return result
    }

    // MARK: - Command Handlers

    private func handleListLists() throws -> [[String: Any]] {
        return remindersService.listCalendarsDTO()
    }

    private func handleListTasks(payload: [String: Any]) throws -> [[String: Any]] {
        let listId = payload["list_id"] as? String
        let statusStr = payload["status"] as? String
        let completed = statusStr == "completed" ? true : (statusStr == "needsAction" ? false : nil)

        let reminders = remindersService.listTasks(listId: listId, completed: completed)
        return reminders.map { remindersService.toDTO($0) }
    }

    private func handleCreateTask(payload: [String: Any]) throws -> [String: Any] {
        guard let title = payload["title"] as? String else {
            throw CommandError.missingParameter("title")
        }

        let notes = payload["notes"] as? String
        let listId = payload["list_id"] as? String
        let dueISO = payload["due_iso"] as? String

        let reminder = try remindersService.createReminder(
            title: title,
            notes: notes,
            listId: listId,
            dueISO: dueISO
        )

        return remindersService.toDTO(reminder)
    }

    private func handleUpdateTask(payload: [String: Any]) throws -> [String: Any] {
        guard let taskId = payload["task_id"] as? String else {
            throw CommandError.missingParameter("task_id")
        }

        let title = payload["title"] as? String
        let notes = payload["notes"] as? String
        let dueISO = payload["due_iso"] as? String

        let reminder = try remindersService.updateTask(
            taskId: taskId,
            title: title,
            notes: notes,
            dueISO: dueISO
        )

        return remindersService.toDTO(reminder)
    }

    private func handleCompleteTask(payload: [String: Any]) throws -> [String: Any] {
        guard let taskId = payload["task_id"] as? String else {
            throw CommandError.missingParameter("task_id")
        }

        let reminder = try remindersService.completeTask(taskId: taskId)
        return remindersService.toDTO(reminder)
    }

    private func handleDeleteTask(payload: [String: Any]) throws -> [String: String] {
        guard let taskId = payload["task_id"] as? String else {
            throw CommandError.missingParameter("task_id")
        }

        try remindersService.deleteTask(taskId: taskId)
        return ["ok": "true"]
    }

    // MARK: - Result Reporting

    private func sendResult(commandId: String, success: Bool, result: Any?, error: String? = nil) async throws {
        let url = serverURL.appendingPathComponent("/device/result")

        var requestBody: [String: Any] = [
            "commandId": commandId,
            "success": success,
            "timestamp": Int(Date().timeIntervalSince1970)
        ]

        if let result = result {
            requestBody["result"] = result
        }

        if let error = error {
            requestBody["error"] = error
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            print("⚠️ Failed to send result to server")
            return
        }

        print("✅ Result sent to server: \(commandId)")
    }
}

// MARK: - Errors

enum CommandError: LocalizedError {
    case invalidPayload
    case unknownOperation(String)
    case missingParameter(String)

    var errorDescription: String? {
        switch self {
        case .invalidPayload:
            return "Invalid command payload"
        case .unknownOperation(let op):
            return "Unknown operation: \(op)"
        case .missingParameter(let param):
            return "Missing required parameter: \(param)"
        }
    }
}

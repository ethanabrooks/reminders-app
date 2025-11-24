import EventKit
import Foundation

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
        // Verify JWT signature and get raw payload data
        let payloadData = try jwtVerifier.verify(token: envelope)

        // Decode metadata first to determine the operation kind
        let meta = try JSONDecoder().decode(CommandMetadata.self, from: payloadData)
        let commandId = meta.id

        print("📥 Processing command: \(meta.kind.rawValue) [\(commandId)]")

        // Ensure reminders access
        try await remindersService.ensureAccess()

        // Execute command and get result as an Encodable (converted to Any for transport)
        let resultAny: Any

        switch meta.kind {
        case .listLists:
            let res = remindersService.listCalendarsDTO()
            resultAny = try encodeToAny(res)

        case .listTasks:
            let cmd = try JSONDecoder().decode(
                CommandWithPayload<ListTasksPayload>.self, from: payloadData)
            let res = try handleListTasks(payload: cmd.payload)
            resultAny = try encodeToAny(res)

        case .createTask:
            let cmd = try JSONDecoder().decode(
                CommandWithPayload<CreateTaskPayload>.self, from: payloadData)
            let res = try handleCreateTask(payload: cmd.payload)
            resultAny = try encodeToAny(res)

        case .updateTask:
            let cmd = try JSONDecoder().decode(
                CommandWithPayload<UpdateTaskPayload>.self, from: payloadData)
            let res = try handleUpdateTask(payload: cmd.payload)
            resultAny = try encodeToAny(res)

        case .completeTask:
            let cmd = try JSONDecoder().decode(
                CommandWithPayload<TaskActionPayload>.self, from: payloadData)
            let res = try handleCompleteTask(payload: cmd.payload)
            resultAny = try encodeToAny(res)

        case .deleteTask:
            let cmd = try JSONDecoder().decode(
                CommandWithPayload<TaskActionPayload>.self, from: payloadData)
            let res = try handleDeleteTask(payload: cmd.payload)
            resultAny = try encodeToAny(res)
        }

        // Send result to server
        try await sendResult(commandId: commandId, success: true, result: resultAny)

        return resultAny
    }

    private func encodeToAny<T: Encodable>(_ value: T) throws -> Any {
        let data = try JSONEncoder().encode(value)
        return try JSONSerialization.jsonObject(with: data)
    }

    // MARK: - Command Handlers

    private func handleListTasks(payload: ListTasksPayload) throws -> [ReminderDTO] {
        let completed: Bool?
        if let s = payload.status {
            completed = (s == "completed") ? true : (s == "needsAction" ? false : nil)
        } else {
            completed = nil
        }

        let reminders = remindersService.listTasks(listId: payload.list_id, completed: completed)
        return reminders.map { remindersService.toDTO($0) }
    }

    private func handleCreateTask(payload: CreateTaskPayload) throws -> ReminderDTO {
        let reminder = try remindersService.createReminder(
            title: payload.title,
            notes: payload.notes,
            listId: payload.list_id,
            dueDateISO: payload.remind_me_date,
            dueTimeISO: payload.remind_me_time
        )
        return remindersService.toDTO(reminder)
    }

    private func handleUpdateTask(payload: UpdateTaskPayload) throws -> ReminderDTO {
        let reminder = try remindersService.updateTask(
            taskId: payload.task_id,
            title: payload.title,
            notes: payload.notes,
            dueDateISO: payload.remind_me_date,
            dueTimeISO: payload.remind_me_time
        )
        return remindersService.toDTO(reminder)
    }

    private func handleCompleteTask(payload: TaskActionPayload) throws -> ReminderDTO {
        let reminder = try remindersService.completeTask(taskId: payload.task_id)
        return remindersService.toDTO(reminder)
    }

    private func handleDeleteTask(payload: TaskActionPayload) throws -> EmptyResult {
        try remindersService.deleteTask(taskId: payload.task_id)
        return EmptyResult(ok: true)
    }

    // MARK: - Result Reporting

    private func sendResult(commandId: String, success: Bool, result: Any?, error: String? = nil)
        async throws {
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
            (200...299).contains(httpResponse.statusCode)
        else {
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

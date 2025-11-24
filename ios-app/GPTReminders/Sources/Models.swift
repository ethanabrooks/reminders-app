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
    let remind_me_date: String?
    let remind_me_time: String?
}

struct UpdateTaskPayload: Decodable {
    let task_id: String
    let title: String?
    let notes: String?
    let remind_me_date: String?
    let remind_me_time: String?
}

struct TaskActionPayload: Decodable {
    let task_id: String
}

struct ListTasksPayload: Decodable {
    let list_id: String?
    let status: String?
}

struct RenderTaskListPayload: Decodable {
    let tasks: [ReminderDTO]
}

// MARK: - DTOs

struct CalendarDTO: Codable {
    let id: String
    let title: String
}

struct ReminderDTO: Codable {
    let id: String?
    let listId: String?
    let title: String?
    let notes: String?
    let status: String?
    let dueISO: String?
    let completedISO: String?
    let url: String?
}

struct EmptyResult: Codable {
    let ok: Bool
}

// MARK: - OpenAI API Models

struct OpenAIChatRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let tools: [OpenAITool]?
    let tool_choice: String?
}

struct OpenAIMessage: Codable {
    let role: String
    let content: String?
    let tool_calls: [OpenAIToolCall]?
    let tool_call_id: String?
    
    // Helper initializers
    init(role: String, content: String?) {
        self.role = role
        self.content = content
        self.tool_calls = nil
        self.tool_call_id = nil
    }
    
    init(role: String, content: String?, tool_calls: [OpenAIToolCall]?) {
        self.role = role
        self.content = content
        self.tool_calls = tool_calls
        self.tool_call_id = nil
    }
    
    init(role: String, content: String?, tool_call_id: String) {
        self.role = role
        self.content = content
        self.tool_calls = nil
        self.tool_call_id = tool_call_id
    }
}

struct OpenAITool: Codable {
    let type: String
    let function: OpenAIFunctionDefinition
}

struct OpenAIFunctionDefinition: Codable {
    let name: String
    let description: String
    let parameters: [String: AnyCodable] // Simplification for dynamic JSON
}

struct OpenAIToolCall: Codable {
    let id: String
    let type: String
    let function: OpenAIFunctionCall
}

struct OpenAIFunctionCall: Codable {
    let name: String
    let arguments: String // JSON string
}

struct OpenAIChatResponse: Codable {
    let id: String
    let choices: [OpenAIChoice]
}

struct OpenAIChoice: Codable {
    let message: OpenAIMessage
    let finish_reason: String?
}

// Helper for AnyCodable since Swift Codable doesn't support [String: Any] directly
struct AnyCodable: Codable, ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByBooleanLiteral, ExpressibleByFloatLiteral, ExpressibleByDictionaryLiteral, ExpressibleByArrayLiteral {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    // Literal conformances
    init(stringLiteral value: String) { self.value = value }
    init(integerLiteral value: Int) { self.value = value }
    init(booleanLiteral value: Bool) { self.value = value }
    init(floatLiteral value: Double) { self.value = value }
    init(dictionaryLiteral elements: (String, AnyCodable)...) {
        var dict = [String: Any]()
        for (k, v) in elements { dict[k] = v.value }
        self.value = dict
    }
    init(arrayLiteral elements: AnyCodable...) {
        self.value = elements.map { $0.value }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            value = intVal
        } else if let doubleVal = try? container.decode(Double.self) {
            value = doubleVal
        } else if let stringVal = try? container.decode(String.self) {
            value = stringVal
        } else if let boolVal = try? container.decode(Bool.self) {
            value = boolVal
        } else if let arrayVal = try? container.decode([AnyCodable].self) {
            value = arrayVal.map { $0.value }
        } else if let dictVal = try? container.decode([String: AnyCodable].self) {
            var dict = [String: Any]()
            for (key, val) in dictVal {
                dict[key] = val.value
            }
            value = dict
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let intVal = value as? Int {
            try container.encode(intVal)
        } else if let doubleVal = value as? Double {
            try container.encode(doubleVal)
        } else if let stringVal = value as? String {
            try container.encode(stringVal)
        } else if let boolVal = value as? Bool {
            try container.encode(boolVal)
        } else if let arrayVal = value as? [Any] {
            try container.encode(arrayVal.map { AnyCodable($0) })
        } else if let dictVal = value as? [String: Any] {
            try container.encode(dictVal.mapValues { AnyCodable($0) })
        } else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable value cannot be encoded"))
        }
    }
}

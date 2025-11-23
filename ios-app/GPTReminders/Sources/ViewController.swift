import UIKit
import EventKit

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {
    private let remindersService = RemindersService()
    private var messages: [OpenAIMessage] = []
    private var apiKey: String {
        get { UserDefaults.standard.string(forKey: "openai_api_key") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "openai_api_key") }
    }

    // MARK: - UI Components

    private lazy var tableView: UITableView = {
        let tv = UITableView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.dataSource = self
        tv.delegate = self
        tv.register(ChatCell.self, forCellReuseIdentifier: "ChatCell")
        tv.separatorStyle = .none
        tv.keyboardDismissMode = .interactive
        return tv
    }()

    private lazy var inputContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemBackground
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowOffset = CGSize(width: 0, height: -2)
        view.layer.shadowRadius = 4
        return view
    }()

    private lazy var inputTextField: UITextField = {
        let tf = UITextField()
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.placeholder = "Ask me to create a reminder..."
        tf.borderStyle = .roundedRect
        tf.delegate = self
        return tf
    }()

    private lazy var sendButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setImage(UIImage(systemName: "arrow.up.circle.fill"), for: .normal)
        btn.contentVerticalAlignment = .fill
        btn.contentHorizontalAlignment = .fill
        btn.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var settingsButton: UIBarButtonItem = {
        UIBarButtonItem(
            image: UIImage(systemName: "gear"),
            style: .plain,
            target: self,
            action: #selector(settingsTapped)
        )
    }()
    
    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.text = "Checking permissions..."
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.sizeToFit()
        return label
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "GPT Reminders"
        navigationItem.rightBarButtonItem = settingsButton
        navigationItem.titleView = statusLabel

        setupLayout()
        checkPermissions()
        
        // Add initial welcome message
        addMessage(OpenAIMessage(role: "system", content: "Hello! I can help you manage your Apple Reminders. Just ask me to create, list, or complete tasks."))

        // Keyboard handling
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    private func setupLayout() {
        view.addSubview(tableView)
        view.addSubview(inputContainer)
        inputContainer.addSubview(inputTextField)
        inputContainer.addSubview(sendButton)

        NSLayoutConstraint.activate([
            inputContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            inputContainer.heightAnchor.constraint(equalToConstant: 60),

            inputTextField.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 16),
            inputTextField.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            inputTextField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -12),
            inputTextField.heightAnchor.constraint(equalToConstant: 40),

            sendButton.widthAnchor.constraint(equalToConstant: 40),
            sendButton.heightAnchor.constraint(equalToConstant: 40),
            sendButton.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            sendButton.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -16),

            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: inputContainer.topAnchor)
        ])
    }

    // MARK: - Permissions

    private func checkPermissions() {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        switch status {
        case .authorized, .fullAccess:
            statusLabel.text = "✅ Reminders Access Granted"
        case .notDetermined:
            statusLabel.text = "⏳ Requesting Access..."
            Task {
                try? await remindersService.ensureAccess()
                await MainActor.run { checkPermissions() }
            }
        default:
            statusLabel.text = "❌ Access Denied"
            addMessage(OpenAIMessage(role: "system", content: "Please enable Reminders access in Settings to use this app."))
        }
    }

    // MARK: - Actions

    @objc private func settingsTapped() {
        let alert = UIAlertController(title: "Settings", message: "Enter OpenAI API Key", preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "sk-..."
            tf.text = self.apiKey
            tf.isSecureTextEntry = true
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            if let key = alert.textFields?.first?.text {
                self.apiKey = key
            }
        })
        present(alert, animated: true)
    }

    @objc private func sendTapped() {
        guard let text = inputTextField.text, !text.isEmpty else { return }
        inputTextField.text = ""
        
        if apiKey.isEmpty {
            settingsTapped()
            return
        }

        let userMsg = OpenAIMessage(role: "user", content: text)
        addMessage(userMsg)
        
        Task {
            await callOpenAI()
        }
    }

    private func addMessage(_ msg: OpenAIMessage) {
        messages.append(msg)
        tableView.reloadData()
        scrollToBottom()
    }
    
    private func scrollToBottom() {
        guard !messages.isEmpty else { return }
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
    }

    // MARK: - OpenAI Logic

    private func callOpenAI() async {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else { return }
        
        // Filter out system messages (internal logs) for the API call context if needed, 
        // but here we keep them if they are just role="system"
        
        // Define tools matching the schema
        let tools = defineTools()
        
        let requestBody = OpenAIChatRequest(
            model: "gpt-4o", // or gpt-4-turbo
            messages: messages.filter { $0.role != "system" || $0.content?.starts(with: "Hello") == false }, // Send context
            tools: tools,
            tool_choice: "auto"
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                if let errStr = String(data: data, encoding: .utf8) {
                    print("OpenAI Error: \(errStr)")
                }
                addMessage(OpenAIMessage(role: "system", content: "Error calling OpenAI. Check API Key."))
                return
            }
            
            let result = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
            guard let choice = result.choices.first else { return }
            
            let msg = choice.message
            addMessage(msg)
            
            if let toolCalls = msg.tool_calls {
                for toolCall in toolCalls {
                    let result = try await executeToolCall(toolCall)
                    
                    // Add tool result to history
                    let toolMsg = OpenAIMessage(role: "tool", content: result, tool_call_id: toolCall.id)
                    addMessage(toolMsg)
                }
                
                // Call OpenAI again to get final response
                await callOpenAI()
            }
            
        } catch {
            print("Request error: \(error)")
            addMessage(OpenAIMessage(role: "system", content: "Request failed: \(error.localizedDescription)"))
        }
    }
    
    private func defineTools() -> [OpenAITool] {
        // We hardcode the schema here to match server/src/openai-schema.ts
        // For brevity, implementing a subset or full set manually
        return [
            OpenAITool(type: "function", function: OpenAIFunctionDefinition(
                name: "create_reminder_task",
                description: "Create a new reminder task",
                parameters: [
                    "type": AnyCodable("object"),
                    "properties": AnyCodable([
                        "title": ["type": "string", "description": "The title of the task"],
                        "notes": ["type": "string", "description": "Notes for the task"],
                        "due_iso": ["type": "string", "description": "ISO 8601 date string"]
                    ]),
                    "required": AnyCodable(["title"])
                ]
            )),
            OpenAITool(type: "function", function: OpenAIFunctionDefinition(
                name: "list_reminder_tasks",
                description: "List tasks",
                parameters: [
                    "type": AnyCodable("object"),
                    "properties": AnyCodable([
                        "status": ["type": "string", "enum": ["needsAction", "completed"]]
                    ])
                ]
            )),
             OpenAITool(type: "function", function: OpenAIFunctionDefinition(
                name: "complete_reminder_task",
                description: "Mark task as complete",
                parameters: [
                    "type": AnyCodable("object"),
                    "properties": AnyCodable([
                        "task_id": ["type": "string", "description": "ID of the task"]
                    ]),
                    "required": AnyCodable(["task_id"])
                ]
            ))
        ]
    }
    
    private func executeToolCall(_ toolCall: OpenAIToolCall) async throws -> String {
        print("🛠 Executing tool: \(toolCall.function.name)")
        guard let data = toolCall.function.arguments.data(using: .utf8) else { return "Invalid arguments" }
        
        // Helper to decode args
        func decode<T: Decodable>(_ type: T.Type) throws -> T {
            try JSONDecoder().decode(type, from: data)
        }
        
        do {
            switch toolCall.function.name {
            case "create_reminder_task":
                let args = try decode(CreateTaskPayload.self)
                let reminder = try remindersService.createReminder(
                    title: args.title,
                    notes: args.notes,
                    listId: args.list_id,
                    dueISO: args.due_iso
                )
                let dto = remindersService.toDTO(reminder)
                return toJson(dto)
                
            case "list_reminder_tasks":
                let args = try decode(ListTasksPayload.self)
                // Map 'status' string to bool
                let completed: Bool?
                if let s = args.status {
                    completed = (s == "completed")
                } else {
                    completed = nil
                }
                let reminders = remindersService.listTasks(listId: args.list_id, completed: completed)
                let dtos = reminders.map { remindersService.toDTO($0) }
                return toJson(dtos)
                
            case "complete_reminder_task":
                let args = try decode(TaskActionPayload.self)
                let reminder = try remindersService.completeTask(taskId: args.task_id)
                let dto = remindersService.toDTO(reminder)
                return toJson(dto)
                
            default:
                return "Unknown function: \(toolCall.function.name)"
            }
        } catch {
            return "Error executing tool: \(error.localizedDescription)"
        }
    }
    
    private func toJson<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }

    // MARK: - TableView

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ChatCell", for: indexPath) as! ChatCell
        let msg = messages[indexPath.row]
        cell.configure(with: msg)
        return cell
    }
    
    // MARK: - Keyboard
    
    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            // Adjust constraint if needed, or just rely on content inset
            let contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: keyboardSize.height - view.safeAreaInsets.bottom + 60, right: 0)
            tableView.contentInset = contentInsets
            tableView.scrollIndicatorInsets = contentInsets
            scrollToBottom()
        }
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        tableView.contentInset = .zero
        tableView.scrollIndicatorInsets = .zero
    }
}

// MARK: - Chat Cell

class ChatCell: UITableViewCell {
    private let bubbleView = UIView()
    private let messageLabel = UILabel()
    
    private var leadingConstraint: NSLayoutConstraint!
    private var trailingConstraint: NSLayoutConstraint!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setup() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.addSubview(bubbleView)
        bubbleView.addSubview(messageLabel)
        
        bubbleView.layer.cornerRadius = 12
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = .systemFont(ofSize: 16)
        
        NSLayoutConstraint.activate([
            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
            messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
            
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.75)
        ])
        
        leadingConstraint = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        trailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
    }
    
    func configure(with msg: OpenAIMessage) {
        messageLabel.font = .systemFont(ofSize: 16)
        
        if msg.role == "user" {
            bubbleView.backgroundColor = .systemBlue
            messageLabel.textColor = .white
            messageLabel.text = msg.content
            
            leadingConstraint.isActive = false
            trailingConstraint.isActive = true
        } else if msg.role == "tool" {
             bubbleView.backgroundColor = .systemGray5
             messageLabel.textColor = .secondaryLabel
             messageLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
             messageLabel.text = "⚙️ Tool Output: " + (msg.content ?? "")
            
            trailingConstraint.isActive = false
            leadingConstraint.isActive = true
        } else {
            // Assistant or System
            bubbleView.backgroundColor = .systemGray6
            messageLabel.textColor = .label
            messageLabel.text = msg.content
            
            if msg.content == nil && msg.tool_calls != nil {
                messageLabel.text = "🛠 calling tool..."
                messageLabel.font = .italicSystemFont(ofSize: 14)
            }
            
            trailingConstraint.isActive = false
            leadingConstraint.isActive = true
        }
    }
}

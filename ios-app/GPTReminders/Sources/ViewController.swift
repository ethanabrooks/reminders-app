import UIKit
import EventKit

class ViewController: UIViewController {
    private let remindersService = RemindersService()

    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.text = "GPT → Apple Reminders Bridge"
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var statusIcon: UILabel = {
        let label = UILabel()
        label.text = "⏳"
        label.font = .systemFont(ofSize: 72)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var detailLabel: UILabel = {
        let label = UILabel()
        label.text = "Checking permissions..."
        label.font = .systemFont(ofSize: 16)
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Grant Reminders Access", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
        return button
    }()

    private lazy var testButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Create Test Reminder", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(testButtonTapped), for: .touchUpInside)
        button.isHidden = true
        return button
    }()

    private lazy var activityLog: UITextView = {
        let textView = UITextView()
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.isEditable = false
        textView.backgroundColor = .systemGray6
        textView.layer.cornerRadius = 8
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.text = "Activity Log:\n"
        return textView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        setupUI()
        checkPermissions()
    }

    private func setupUI() {
        view.addSubview(statusIcon)
        view.addSubview(statusLabel)
        view.addSubview(detailLabel)
        view.addSubview(actionButton)
        view.addSubview(testButton)
        view.addSubview(activityLog)

        NSLayoutConstraint.activate([
            statusIcon.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusIcon.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),

            statusLabel.topAnchor.constraint(equalTo: statusIcon.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            detailLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),
            detailLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            detailLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            actionButton.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 40),
            actionButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            actionButton.widthAnchor.constraint(equalToConstant: 280),
            actionButton.heightAnchor.constraint(equalToConstant: 50),

            testButton.topAnchor.constraint(equalTo: actionButton.bottomAnchor, constant: 16),
            testButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            activityLog.topAnchor.constraint(equalTo: testButton.bottomAnchor, constant: 30),
            activityLog.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            activityLog.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            activityLog.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }

    private func checkPermissions() {
        let status = EKEventStore.authorizationStatus(for: .reminder)

        switch status {
        case .authorized, .fullAccess:
            updateUI(
                icon: "✅",
                detail: "Ready to receive commands from GPT",
                buttonTitle: "Refresh Status",
                showTest: true
            )
            log("✅ Reminders access granted")

        case .notDetermined:
            updateUI(
                icon: "⏳",
                detail: "Tap below to grant access to Reminders",
                buttonTitle: "Grant Reminders Access",
                showTest: false
            )

        case .denied, .restricted:
            updateUI(
                icon: "❌",
                detail: "Reminders access denied. Enable in Settings → Privacy → Reminders",
                buttonTitle: "Open Settings",
                showTest: false
            )
            log("❌ Reminders access denied")

        case .writeOnly:
            updateUI(
                icon: "⚠️",
                detail: "Limited access. Grant full access for best experience.",
                buttonTitle: "Grant Full Access",
                showTest: false
            )

        @unknown default:
            updateUI(
                icon: "❓",
                detail: "Unknown permission status",
                buttonTitle: "Check Permissions",
                showTest: false
            )
        }
    }

    private func updateUI(icon: String, detail: String, buttonTitle: String, showTest: Bool) {
        statusIcon.text = icon
        detailLabel.text = detail
        actionButton.setTitle(buttonTitle, for: .normal)
        testButton.isHidden = !showTest
    }

    @objc private func actionButtonTapped() {
        let status = EKEventStore.authorizationStatus(for: .reminder)

        if status == .denied || status == .restricted {
            // Open Settings
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } else {
            // Request permission
            Task {
                do {
                    try await remindersService.ensureAccess()
                    await MainActor.run {
                        checkPermissions()
                    }
                } catch {
                    await MainActor.run {
                        log("❌ Permission request failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    @objc private func testButtonTapped() {
        Task {
            do {
                let title = "Test from GPT Bridge @ \(Date().formatted(date: .omitted, time: .shortened))"
                let reminder = try remindersService.createReminder(
                    title: title,
                    notes: "Created by the GPT Reminders bridge app",
                    listId: nil,
                    dueISO: nil
                )

                await MainActor.run {
                    log("✅ Created reminder: \(reminder.title ?? "")")
                    showAlert(title: "Success", message: "Test reminder created!")
                }
            } catch {
                await MainActor.run {
                    log("❌ Failed to create reminder: \(error.localizedDescription)")
                    showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }

    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        activityLog.text += "[\(timestamp)] \(message)\n"

        // Auto-scroll to bottom
        let range = NSRange(location: activityLog.text.count - 1, length: 1)
        activityLog.scrollRangeToVisible(range)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

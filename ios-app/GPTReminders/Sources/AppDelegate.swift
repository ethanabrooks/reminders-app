import UIKit
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var commandHandler: CommandHandler?

    // Configuration - Replace with your server URL
    private let serverURL = URL(string: "http://192.168.0.228:3000")!

    private var publicKeyPEM: String {
        if let filepath = Bundle.main.path(forResource: "public", ofType: "pem"),
            let contents = try? String(contentsOfFile: filepath) {
            return contents
        }
        // Fallback or empty string (will cause CommandHandler to fail)
        print("❌ public.pem not found in Bundle! Please add public.pem to your Xcode project.")
        return ""
    }

    // MARK: - Application Lifecycle

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // 1. Initialize dependencies (Factory pattern)
        self.window = makeWindow()
        self.commandHandler = makeCommandHandler()

        // 2. Setup system services
        setupNotifications()
        
        #if targetEnvironment(simulator)
        print("📱 Running on Simulator: starting polling immediately")
        startPolling()
        #endif

        return true
    }

    // MARK: - Factory Methods (Composition Root)

    private func makeCommandHandler() -> CommandHandler? {
        do {
            return try CommandHandler(
                publicKeyPEM: publicKeyPEM,
                serverURL: serverURL
            )
        } catch {
            print("❌ Failed to initialize command handler: \(error)")
            return nil
        }
    }

    private func makeWindow() -> UIWindow {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = ViewController()
        window.makeKeyAndVisible()
        return window
    }

    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) {
            granted, _ in
            if granted {
                print("✅ Notification permission granted")
            }
        }
        
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    // MARK: - Polling Mode (Simulator Fallback)

    private func startPolling() {
        print("🔄 Starting polling loop...")
        Task {
            while true {
                try? await Task.sleep(nanoseconds: 2 * 1_000_000_000) // 2 seconds
                await pollForCommands()
            }
        }
    }

    private func pollForCommands() async {
        guard let userId = UIDevice.current.identifierForVendor?.uuidString else { return }
        let url = serverURL.appendingPathComponent("/device/commands/\(userId)")
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // Parse response: { "commands": [ { "id": "...", "envelope": "..." } ] }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let commands = json["commands"] as? [[String: Any]] else {
                return
            }
            
            for cmd in commands {
                if let envelope = cmd["envelope"] as? String {
                    print("📥 Received command via polling")
                    
                    if let handler = commandHandler {
                        do {
                            let result = try await handler.processCommand(envelope: envelope)
                            print("✅ Command processed: \(result)")
                        } catch {
                            print("❌ Command failed: \(error)")
                        }
                    }
                }
            }
        } catch {
            print("⚠️ Polling error: \(error.localizedDescription)")
        }
    }

    // MARK: - APNs Registration

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("📱 APNs Device Token: \(token)")

        Task {
            await registerDevice(apnsToken: token)
        }

        #if targetEnvironment(simulator)
        print("📱 Running on Simulator: forcing polling mode")
        startPolling()
        #endif
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ Failed to register for remote notifications: \(error)")
        print("⚠️ App will use polling mode instead")

        Task {
            await registerDevice(apnsToken: "simulator-polling-mode")
            // Start polling since push failed
            startPolling()
        }
    }

    // MARK: - Silent Push Handler

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("📥 Received remote notification")

        // 1. Extract payload
        guard let envelope = userInfo["envelope"] as? String else {
            print("⚠️ No envelope in notification")
            completionHandler(.noData)
            return
        }

        // 2. Resolve dependencies
        guard let handler = commandHandler else {
            print("❌ Command handler not initialized")
            completionHandler(.failed)
            return
        }

        // 3. Execute
        Task {
            do {
                let result = try await handler.processCommand(envelope: envelope)
                print("✅ Command processed successfully: \(result)")
                completionHandler(.newData)
            } catch {
                print("❌ Command processing failed: \(error)")
                completionHandler(.failed)
            }
        }
    }

    // MARK: - Server Communication

    private func registerDevice(apnsToken: String) async {
        // In production, use actual user ID from your auth system
        let userId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"

        let url = serverURL.appendingPathComponent("/device/register")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "userId": userId,
            "apnsToken": apnsToken
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode)
            else {
                print("❌ Failed to register device")
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("✅ Device registered: \(json)")
            }
        } catch {
            print("❌ Registration error: \(error)")
        }
    }

    // MARK: - Deep Link Handler

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        // Handle deep links: gptreminders://task/<id>
        guard url.scheme == "gptreminders" else { return false }

        if url.host == "task", url.pathComponents.count > 1 {
            let taskId = url.pathComponents[1]
            print("📱 Opening task: \(taskId)")
            // Navigate to task detail view
            return true
        }

        return false
    }
}

import UIKit
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var commandHandler: CommandHandler?

    // Configuration - Replace with your server URL
    private let serverURL = URL(string: "http://localhost:3000")!

    private var publicKeyPEM: String {
        if let filepath = Bundle.main.path(forResource: "public", ofType: "pem"),
           let contents = try? String(contentsOfFile: filepath) {
            return contents
        }
        // Fallback or empty string (will cause CommandHandler to fail)
        print("❌ public.pem not found in Bundle! Please add public.pem to your Xcode project.")
        return ""
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Initialize command handler
        do {
            commandHandler = try CommandHandler(
                publicKeyPEM: publicKeyPEM,
                serverURL: serverURL
            )
        } catch {
            print("❌ Failed to initialize command handler: \(error)")
        }

        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            if granted {
                print("✅ Notification permission granted")
            }
        }

        // Register for remote notifications (APNs)
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }

        // Setup UI
        setupRootViewController()

        return true
    }

    private func setupRootViewController() {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = ViewController()
        window?.makeKeyAndVisible()
    }

    // MARK: - APNs Registration

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("📱 APNs Device Token: \(token)")

        // Register with server
        Task {
            await registerDevice(apnsToken: token)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ Failed to register for remote notifications: \(error)")
        print("⚠️ App will use polling mode instead")

        // Still register with server using a dummy token for polling mode
        Task {
            await registerDevice(apnsToken: "simulator-polling-mode")
        }
    }

    // MARK: - Silent Push Handler

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("📥 Received remote notification")

        guard let envelope = userInfo["envelope"] as? String else {
            print("⚠️ No envelope in notification")
            completionHandler(.noData)
            return
        }

        guard let handler = commandHandler else {
            print("❌ Command handler not initialized")
            completionHandler(.failed)
            return
        }

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
                  (200...299).contains(httpResponse.statusCode) else {
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

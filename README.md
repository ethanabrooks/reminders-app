# GPT Reminders Bridge

A secure bridge connecting ChatGPT to Apple Reminders via a personal iOS app.

## Architecture

```mermaid
graph TD
    User[User] -->|Prompts| GPT[ChatGPT]
    GPT -->|1. Call Tool| Server[Node.js Server]
    Server -->|2. APNs Push| APNs[Apple Push Service]
    APNs -->|3. Wake App| iOS[iOS App]
    iOS -->|4. Query/Update| Reminders[Apple Reminders DB]
    iOS -->|5. Return Result| Server
    Server -->|6. Return JSON| GPT
    GPT -->|7. Answer User| User
```

## Directory Structure

- **[`server/`](server/README.md)**: Node.js backend that signs commands and handles APNs.
- **[`ios-app/`](ios-app/README.md)**: Swift iOS app that executes commands on the device.
- **[`scripts/`](scripts/README.md)**: Testing and utility scripts.

## Quick Start

1.  **Server Setup**:
    ```bash
    cd server
    npm install
    npm run gen-keys
    npm run dev
    ```
2.  **iOS Setup**:
    - Open `ios-app/GPTReminders.xcodeproj`
    - Add `server/keys/public.pem` to the app bundle.
    - Run on a physical device (Simulators don't support APNs).

## Security Model

```mermaid
sequenceDiagram
    participant Server
    participant iOS as iOS App
    participant Keychain as iOS Keychain

    Note over Server, iOS: 1. Command Signing
    Server->>Server: Create JSON Payload
    Server->>Server: Sign with PRIVATE Key (RS256)
    Server->>iOS: Send Signed JWT via APNs

    Note over iOS: 2. Verification
    iOS->>iOS: Intercept Silent Push
    iOS->>Keychain: Retrieve PUBLIC Key
    iOS->>iOS: Verify JWT Signature
    alt Signature Valid
        iOS->>iOS: Execute Command
    else Invalid
        iOS->>iOS: Drop Packet & Log Error
    end
```

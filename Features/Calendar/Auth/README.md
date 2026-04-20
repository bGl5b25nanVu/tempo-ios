# Google Calendar OAuth Setup

## 1. Google Cloud Console Configuration

1. Go to [Google Cloud Console](https://console.cloud.google.com/) and create a new project (or select an existing one).

2. **Enable the Google Calendar API:**
   - Navigate to **APIs & Services > Library**
   - Search for "Google Calendar API"
   - Click **Enable**

3. **Create OAuth 2.0 credentials (iOS):**
   - Navigate to **APIs & Services > Credentials**
   - Click **+ Create Credentials > OAuth client ID**
   - Application type: **iOS**
   - Bundle ID: `com.tempo.app`
   - App Store ID: (optional, leave blank if not published)
   - Click **Create**
   - Copy the **Client ID** (format: `xxx.apps.googleusercontent.com`)

4. **Configure the OAuth consent screen:**
   - Navigate to **APIs & Services > OAuth consent screen**
   - User type: **External**
   - Fill in app name, email, etc.
   - Add scopes: `../auth/calendar`, `../auth/calendar.events`
   - Add your test users (required for external unpublished apps)

## 2. Update Info.plist

Add the following to your app's `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.tempo.app</string>
    </array>
    <key>CFBundleURLName</key>
    <string>com.tempo.app</string>
  </dict>
</array>
```

## 3. Update Source Code

In `Features/Calendar/Auth/GoogleCalendarAuth.swift`, replace the placeholder:

```swift
static let clientID = "YOUR_CLIENT_ID.apps.googleusercontent.com"
```

with your actual OAuth client ID from step 3.

## 4. Configure URL Scheme (SceneDelegate)

In your app's SceneDelegate or App file, handle the OAuth callback:

```swift
import GoogleSignIn

// In SceneDelegate.scene(_:openURLContexts:)
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }
    _ = GoogleCalendarAuth.shared.handleURL(url)
}
```

Or in SwiftUI App:

```swift
import GoogleSignIn

@main
struct TempoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    _ = GoogleCalendarAuth.shared.handleURL(url)
                }
        }
    }
}
```

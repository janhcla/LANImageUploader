# LAN Image Uploader

LAN Image Uploader is a client-server application that allows you to capture images on your iPhone and upload them directly to a folder on your Windows computer over your local network. It consists of an iOS application and a .NET companion server application that runs on your Windows machine.

## Features

*   **iOS App**:
    *   Capture images using the camera.
    *   Upload images to the companion server.
    *   Securely pair with the server using a QR code.
    *   View a gallery of uploaded images.
*   **Companion Server (.NET)**:
    *   Lightweight, self-contained web server.
    *   Generates a unique API key for secure uploads.
    *   Provides a QR code for easy pairing with the iOS app.
    *   Saves uploaded images to a specified folder on your Windows machine.

## Requirements

*   **iOS App**:
    *   An iPhone running a recent version of iOS.
    *   Xcode for building and running the app on your device.
    *   Your iPhone must be on the same local network (Wi-Fi) as your Windows server.
*   **Companion Server (Windows)**:
    *   A Windows machine (can be a server or a desktop).
    *   .NET 8 SDK or later.
    *   A local network connection.

## How to Use

Follow these steps to get the system up and running.

### Step 1: Set up the Companion Server App (Windows)

1.  **Install .NET 8**: If you don't already have it, download and install the [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0) on your Windows machine.
2.  **Get the Server Code**: Clone or download this repository to your Windows machine. It is assumed that the companion app is in a `LANImageUploader-Companion-App` directory.
3.  **Run the Server**:
    *   Open a Command Prompt or PowerShell window.
    *   Navigate to the `LANImageUploader-Companion-App` directory.
    *   Run the command: `dotnet run`.
4.  **Server Information**:
    *   The server will start and listen on `https://<your-server-ip>:5001`.
    *   On the first run, it will generate an `apikey.txt` file in the same directory. This key is used to secure the connection.
    *   Uploaded images will be saved to `C:\Users\<YourUser>\Pictures\LANImageUploader`.
5.  **Get the QR Code**:
    *   On the Windows server machine, open a web browser and navigate to `https://localhost:5001/qrcode`.
    *   You will see a QR code. Keep this page open; you will need to scan it with the iOS app.

### Step 2: Set up the iOS App

1.  **Open the Project**: Open the `LANImageUploader.xcodeproj` file in Xcode on a macOS machine.
2.  **Connect Your iPhone**: Connect your iPhone to your Mac.
3.  **Build and Run**:
    *   Select your iPhone as the build target in Xcode.
    *   Click the "Run" button (or press `Cmd+R`). The app will be installed and launched on your iPhone.
4.  **Pair the App**:
    *   The app will launch to an onboarding screen.
    *   Tap the "Scan QR Code" button.
    *   Point your iPhone's camera at the QR code displayed in the browser on your Windows machine.
    *   The app will automatically configure itself with the server's address and API key.

### Step 3: Using the App

Once paired, you can use the app's main features:

*   **Camera**: Tap the camera tab to capture new images.
*   **Gallery**: View the images you've captured.
*   **Upload**: Select images from the gallery and tap the upload button to send them to your Windows server.

## Project Structure

*   `LANImageUploader/`: Contains the source code for the iOS application.
*   `LANImageUploader.xcodeproj`: The Xcode project file for the iOS app.
*   `README.md`: This file.

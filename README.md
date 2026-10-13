# Infinite Image Gallery App

## Project Overview

A Flutter application that displays images from the Unsplash API in a scrollable image gallery.

## Features

- Image gallery with pagination and infinite scrolling
- Search images
- View image details
- Add and remove favorite images
- Persist favorites locally
- Download images to the device
- Loading, error, and retry handling
- Responsive UI

## Prerequisites

- Flutter SDK
- Dart SDK
- Android Studio or Visual Studio Code
- An Unsplash API access key

## Setup Instructions

1. Clone this repository.
2. Open the project folder in a terminal.
3. Install dependencies:

   ```bash
   flutter pub get
   ```

4. Run the app with your Unsplash API access key:

   ```bash
   flutter run --dart-define=UNSPLASH_ACCESS_KEY=YOUR_ACCESS_KEY
   ```

Replace `YOUR_ACCESS_KEY` with your own Unsplash API access key.

Do not commit your API key to the repository.

## Architecture and State Management

The project is organized into separate files for models, screens, services, state management, and reusable widgets.

- **Models:** Represent photo data.
- **Services:** Handle Unsplash API requests.
- **Screens:** Display the gallery, photo details, and favorites.
- **State management:** Manages favorite items and their persistence.
- **Widgets:** Provide reusable UI components.

Favorites are stored locally using SharedPreferences. Image requests use the HTTP package.

## Assumptions and Limitations

- An internet connection is required to fetch images.
- A valid Unsplash API access key is required.
- API usage is subject to Unsplash rate limits.
- Image downloads depend on device permissions and platform support.

## Screenshots

Add 2–4 screenshots of the running application here.

## Build APK

To build a release APK, run:

```bash
flutter build apk --release --dart-define=UNSPLASH_ACCESS_KEY=YOUR_ACCESS_KEY
```

The APK is generated under:

`build/app/outputs/flutter-apk/app-release.apk`

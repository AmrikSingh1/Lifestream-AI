# LifeStream AI — Smart Blood & Donor Network

LifeStream AI is a cutting-edge Flutter application designed to bridge the gap between blood donors and recipients in real-time. Leveraging advanced geolocation and Google Gemini AI, it transforms the traditional blood donation process into a seamless, life-saving network.

## ✨ Key Features

### 🩸 For Donors
- **Availability Control**: Toggle your availability to appear on the recipient map.
- **Emergency Radar**: Real-time map visualization of urgent blood requests filtered by distance and urgency level (Critical, High, Medium).
- **Digital Donor Card**: Generate a secure QR-based donor profile.
- **Stats & Impact Tracker**: Track your donations and lives saved.

### 🏥 For Recipients
- **Real-Time Locator**: Find compatible blood donors within a 100km radius on an interactive map.
- **Emergency Requests**: Broadcast urgent blood needs instantly to nearby matching donors.
- **Direct Communication**: Connect with donors via call or WhatsApp directly from the app.

### 🤖 AI-Powered Intelligence (Powered by Gemini)
- **AI Health Coach (Donors)**: Interactive screening for donation eligibility and personalized dietary recommendations (hemoglobin boosters).
- **AI Health Assistant (Recipients)**: On-demand advice regarding compatibility, recovery care, and general wellness.
- **Demand Forecasting**: Predictive insights into upcoming blood shortages.

## 🛠️ Technology Stack

- **Core**: Flutter & Dart
- **State Management**: Flutter Riverpod with Code Generation (`riverpod_annotation`)
- **Backend**: Firebase (Authentication, Cloud Firestore, Storage, Messaging)
- **Navigation**: GoRouter
- **Maps & Geolocation**: Google Maps API, Geolocator
- **AI Integration**: `google_generative_ai` (Gemini 1.5 Flash & 3.1 Flash Lite)
- **UI/UX**: Glassmorphism, Shimmer Effects, Lottie Animations, Google Fonts

## 📁 Project Architecture

The application adheres to **Clean Architecture** principles separated by feature modules:

```
lib/
├── core/                  # Shared resources, themes, and global providers
│   ├── constants/         # Styling & Assets
│   ├── providers/         # Shared Riverpod states
│   ├── router/            # GoRouter navigation logic
│   └── services/          # Global business services
└── features/              # Feature-driven modules
    ├── auth/              # Sign In & Secure OTP Flows
    ├── donor/             # Donor specific views & AI Coach
    ├── recipient/         # Map locator & Emergency Broadcasts
    └── user_onboarding/   # Role-specific registration
```

## 🚀 Getting Started

### Prerequisites
- Flutter SDK installed.
- Firebase Project set up with Android/iOS apps configured.

### Setup
1. Clone the repository.
2. Configure your environment variables:
   Create a `.env` file in the root directory:
   ```env
   BREVO_API_KEY=your_api_key
   OTP_FROM_EMAIL=your_email@domain.com
   OTP_FROM_NAME="LifeStream AI"
   ```
3. Add your Firebase configuration (`google-services.json` for Android / `GoogleService-Info.plist` for iOS).
4. Ensure your Gemini API key is configured in `lib/features/donor/presentation/donor_dashboard_screen.dart` (or moved to secure storage).
5. Install dependencies & run code generation:
   ```bash
   flutter pub get
   flutter pub run build_runner build --delete-conflicting-outputs
   ```
6. Launch the app:
   ```bash
   flutter run
   ```

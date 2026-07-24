# 💰 Pocketify - Smart Expense Tracker

[![Flutter](https://img.shields.io/badge/Flutter->=3.10.0-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart->=3.0.0-0175C2?logo=dart)](https://dart.dev)
[![Hive](https://img.shields.io/badge/Database-Hive%20Local-FF6F00)](https://docs.hivedb.dev/)
[![Provider](https://img.shields.io/badge/State-Provider-42A5F5)](https://pub.dev/packages/provider)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Desktop-blue)](#)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](#)

**Pocketify** is a feature-rich, privacy-first, offline-ready smart expense tracker built with **Flutter**, **Hive**, and **Provider**. It helps users effortlessly log income/expenses, visualize spending patterns, set category budgets, track savings goals, auto-parse bank SMS notifications, and generate AI-driven financial insights.

---

## ✨ Key Features

### 📊 Smart Dashboard & Analytics
- **Visual Insights**: Interactive line charts, bar graphs, and pie charts powered by `fl_chart`.
- **Financial Overview**: Real-time calculation of total balance, monthly income, monthly expenses, and net savings.
- **Category Breakdown**: Granular view of spending distribution across customizable categories.

### 🤖 AI-Powered Financial Insights
- **Spending Habit Analysis**: Detects unusual spending spikes and recurring patterns.
- **Budget Warnings**: Proactive alerts when category spending approaches budget limits.
- **Savings Recommendations**: Actionable tips tailored to your income-to-expense ratio.

### 📲 Automatic SMS Expense Capture (Android Native)
- **Bank & UPI SMS Parsing**: Intercepts and parses transactional SMS messages (credits/debits) using native Android `MethodChannel`.
- **Zero Manual Effort**: Automatically suggests amount, payee/merchant, transaction date, and mode of payment.

### 💡 Category-Wise Budget Management
- **Monthly Budgets**: Set spending caps for specific categories (e.g., Food, Transportation, Entertainment).
- **Progress Indicators**: Color-coded status bars and percentage indicators to keep spending under control.

### 🎯 Savings Goals Tracker
- **Goal Setting**: Track targets for emergency funds, vacations, gadgets, or major purchases.
- **Progress Tracking**: Log contributions over time and monitor target completion dates.

### 📑 Reports & Data Export
- **PDF Export**: Generate formatted PDF financial statements for custom date ranges.
- **CSV Export**: Export transaction logs to CSV for Excel, Google Sheets, or tax filing.

### 🛡️ Privacy-First & Offline Storage
- **Hive NoSQL Engine**: Super-fast local key-value storage. All financial data stays strictly on your device.
- **Multi-User Profile Support**: Switch profiles or secure app data with PIN/Authentication locks.

### 🎨 Personalization & Theme Settings
- **Dark & Light Mode**: Seamless dark theme with custom accent colors.
- **Multi-Currency Support**: Choose preferred currency symbols (`₹`, `$`, `€`, `£`, etc.).

---

## 🛠️ Architecture & Tech Stack

- **Frontend Framework**: [Flutter](https://flutter.dev) (Material Design 3)
- **State Management**: [Provider](https://pub.dev/packages/provider) (`MultiProvider`, `ChangeNotifierProxyProvider`)
- **Database**: [Hive](https://pub.dev/packages/hive) & [hive_flutter](https://pub.dev/packages/hive_flutter)
- **Data Visualization**: [fl_chart](https://pub.dev/packages/fl_chart)
- **Document Exporting**: [pdf](https://pub.dev/packages/pdf), [printing](https://pub.dev/packages/printing), [csv](https://pub.dev/packages/csv)
- **Typography**: [google_fonts](https://pub.dev/packages/google_fonts)
- **Native Interop**: Kotlin / Android Platform Channel (`MethodChannel`) for SMS receiver

---

## 📁 Project Structure

```text
expense_tracker/
├── assets/
│   └── images/              # App logos, icons, and illustrations
├── android/                 # Native Android project configuration & SMS Receiver
├── ios/                     # Native iOS project configuration
├── lib/
│   ├── main.dart            # Entry point & Provider initialization
│   ├── models/              # Data models (Transaction, Budget, SavingsGoal, Category, UserProfile)
│   ├── providers/           # State management (Auth, Transaction, Budget, Category, Savings, Theme)
│   ├── screens/
│   │   ├── analytics/       # Reports and chart screens
│   │   ├── authentication/  # Login and PIN screen
│   │   ├── budget/          # Budget management screen
│   │   ├── calendar/        # Calendar view screen
│   │   ├── categories/      # Category configuration screen
│   │   ├── dashboard/       # Main navigation and overview screen
│   │   ├── expense_income/  # Add/edit transaction forms
│   │   ├── profile/         # User profile and settings screen
│   │   ├── reports/         # PDF and CSV export screen
│   │   ├── savings/         # Savings goals screen
│   │   └── splash/          # App splash screen
│   ├── services/            # Services (Hive Storage, AI Insights, SMS Parser, Report Generator)
│   ├── utils/               # App theme, formatters, and constants
│   └── widgets/             # Reusable UI components & custom cards
└── pubspec.yaml             # Dependencies and package configuration
```

---

## 🚀 Getting Started

### Prerequisites

Ensure you have the following installed on your machine:
- **Flutter SDK**: `>= 3.10.0` ([Installation Guide](https://docs.flutter.dev/get-started/install))
- **Dart SDK**: `>= 3.0.0`
- **Android Studio** or **VS Code** with Flutter extension
- **JDK 17** (for building Android app)

### Installation & Run

1. **Clone the Repository**
   ```bash
   git clone https://github.com/your-username/expense_tracker.git
   cd expense_tracker
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Generate Hive Adapters (If needed)**
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **Run the App**
   - On a connected physical Android/iOS device or Emulator:
   ```bash
   flutter run
   ```

---

## 📱 SMS Auto-Capture Permissions (Android)

To enable automatic SMS parsing on Android:
1. Grant **RECEIVE_SMS** and **READ_SMS** permissions when prompted on first launch.
2. Ensure battery optimization settings allow background receiver performance for real-time alerts.

---

## 📦 Building for Production

### Android APK
```bash
flutter build apk --release
```
The generated APK will be available at `build/app/outputs/flutter-apk/app-release.apk`.

### Android App Bundle (AAB)
```bash
flutter build appbundle --release
```

---

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](#) if you want to contribute.

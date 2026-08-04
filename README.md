# 💰 Pocketify - Smart Expense Tracker

[![Flutter](https://img.shields.io/badge/Flutter->=3.10.0-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart->=3.0.0-0175C2?logo=dart)](https://dart.dev)
[![Hive](https://img.shields.io/badge/Database-Hive%20NoSQL-FF6F00?logo=hive)](https://docs.hivedb.dev/)
[![Provider](https://img.shields.io/badge/State-Provider%20v6.1.2-42A5F5)](https://pub.dev/packages/provider)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Desktop-blue)](#)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**Pocketify** is an advanced, privacy-first, offline-ready smart expense tracker built with **Flutter**, **Hive**, and **Provider**. Designed to provide total financial visibility and control, Pocketify automatically captures financial SMS notifications, categorizes transactions using smart heuristics, provides AI-driven financial advisories, tracks budgets and savings goals, and generates formatted PDF/CSV financial statements—all while keeping your data 100% private and on your device.

---

## 📋 Table of Contents

- [✨ Key Features](#-key-features)
  - [📊 Smart Dashboard & Analytics](#-smart-dashboard--analytics)
  - [🤖 AI-Powered Financial Insights Engine](#-ai-powered-financial-insights-engine)
  - [📲 Automatic SMS Transaction Capture (Android Native)](#-automatic-sms-transaction-capture-android-native)
  - [💡 Smart Categorizer & Machine Heuristics](#-smart-categorizer--machine-heuristics)
  - [🎙️ Hands-Free Voice Input & OCR Receipt Scanning](#️-hands-free-voice-input--ocr-receipt-scanning)
  - [💡 Category Budget Capping & Overspend Alerts](#-category-budget-capping--overspend-alerts)
  - [🎯 Savings Goals & Milestone Tracker](#-savings-goals--milestone-tracker)
  - [💳 Virtual Credit Cards & Payment Method Manager](#-virtual-credit-cards--payment-method-manager)
  - [📑 Comprehensive Financial Reports & Multi-Format Exports](#-comprehensive-financial-reports--multi-format-exports)
  - [🛡️ Biometric Security & Privacy-First Architecture](#-biometric-security--privacy-first-architecture)
  - [🔔 Animated In-App Notification & Toast System](#-animated-in-app-notification--toast-system)
  - [🎨 Personalization, Dynamic Themes & Multi-Currency](#-personalization-dynamic-themes--multi-currency)
- [🛠️ Tech Stack & Architecture](#️-tech-stack--architecture)
- [📁 Project Folder Structure](#-project-folder-structure)
- [🗄️ Domain Models & Data Schema](#️-domain-models--data-schema)
- [🚀 Getting Started & Installation](#-getting-started--installation)
- [📱 Native Android SMS Integration Setup](#-native-android-sms-integration-setup)
- [📦 Production Build & Release](#-production-build--release)
- [🧪 Testing & Code Quality](#-testing--code-quality)
- [🔧 Troubleshooting & FAQ](#-troubleshooting--faq)
- [🗺️ Future Roadmap](#-future-roadmap)
- [📄 License & Contributing](#-license--contributing)

---

## ✨ Key Features

### 📊 Smart Dashboard & Analytics
- **Real-Time Net Worth & Financial Overview**: Live tracking of total net balance, monthly income, monthly expenses, net savings, and credit liabilities.
- **Interactive Visualizations (`fl_chart`)**: High-performance interactive charts including spending timeline line graphs, income vs. expense bar comparisons, and category distribution pie charts.
- **Deep-Dive Analytics View**: Filter transaction data by period (This Month, Last Month, Last 30 Days, Custom Range), track spending trends, top expense channels, and average transaction values.
- **Calendar Spending View**: Interactive daily calendar grid displaying income/expense markers and day-by-day financial log breakdown.
- **Advanced Ledger & Multi-Criteria Filtering**: Search transactions by title/notes, filter by type (Income vs. Expense), category, date ranges, and payment methods with multi-option sorting.

### 🤖 AI-Powered Financial Insights Engine
- **Automated Financial Health Score**: Algorithmic scoring (0–100) evaluating savings rate, budget compliance, debt ratio, emergency reserve buffer, and spending consistency.
- **Subscription & Recurring Payment Detector**: Scans transactions for recurring monthly subscriptions (Netflix, Spotify, Cloud Storage, Gym, software) to forecast upcoming recurring overheads.
- **Anomaly & Spending Spike Alerts**: Detects unusual transactions and unexpected spending spikes compared to historical category averages.
- **Predictive End-of-Month Forecast**: Predicts end-of-month spending based on current daily burn rate to prevent cash crunches before month-end.
- **Personalized Actionable Recommendations**: Context-aware advisory cards providing actionable financial advice (budget adjustments, savings contributions) with direct action routes.

### 📲 Automatic SMS Transaction Capture (Android Native)
- **Zero-Touch Expense Logging**: Native Kotlin `MethodChannel` (`com.pocketify.expensetracker/sms`) and `SmsReceiver` for real-time background SMS interception.
- **Comprehensive Bank & UPI Support**: Built-in regex parsers for major financial institutions and UPI apps (HDFC, SBI, ICICI, Axis, PNB, Kotak, Paytm, PhonePe, Google Pay, CRED, Amazon Pay, etc.).
- **Smart Entity Extraction**: Automatically extracts transaction amount, type (Debit vs. Credit), merchant/payee name, timestamp, last 4 digits of card/account, and payment mode.
- **Spam, OTP & Non-Financial Message Filter**: Multi-tier filter blocks OTPs, promotional alerts, balance inquiries, and marketing spam.

### 💡 Smart Categorizer & Machine Heuristics
- **Automatic Category Assignment**: Intelligent keyword matching assigns transactions to pre-defined categories (Food & Dining, Shopping, Bills & Utilities, Transportation, Entertainment, Health, Groceries, Travel, Investments, Income, etc.).
- **Self-Learning User Adjustments**: Smart heuristics adapt over time based on user edits and manual category overrides.

### 🎙️ Hands-Free Voice Input & OCR Receipt Scanning
- **Voice Transaction Logger**: Dictate expenses on the go with hands-free speech-to-text processing (`voice_service.dart`).
- **OCR Receipt Scanner**: Extract vendor, total amount, and line items directly from camera snapshots or gallery images (`ocr_service.dart`).

### 💡 Category Budget Capping & Overspend Alerts
- **Monthly Category Spending Caps**: Set strict monthly budget limits per category (e.g., $300/month for Dining).
- **Visual Progress Indicators**: Color-coded progress indicators (Green, Yellow, Red) reflect real-time budget utilization.
- **Proactive Over-Budget Warnings**: Local push notifications (`flutter_local_notifications`) notify users when reaching 80%, 90%, or 100% of category caps.
- **Budget Compliance Analytics**: Review overall monthly budget compliance rates in interactive reports.

### 🎯 Savings Goals & Milestone Tracker
- **Custom Savings Target Creation**: Define target goals for emergency funds, vacations, new gadgets, vehicles, or home down payments.
- **Contribution Logging**: Log periodic contributions with custom notes and track progress percentages against target deadlines.
- **Milestone & Celebration Triggers**: Visual milestone badges and celebratory animations upon completing goals.

### 💳 Virtual Credit Cards & Payment Method Manager
- **Virtual Credit Card & Utilization Tracker**: Manage multiple virtual credit cards, set individual credit limits, track spend vs. available limit, and view utilization progress bars (`credit_card_summary_widget.dart`).
- **Automated Card Matching**: Matches incoming SMS transactions with registered credit cards via last 4 account digits.
- **Multi-Payment Method Categorization**: Classify expenses by payment mode (UPI, Credit Card, Debit Card, Net Banking, Cash) to track liquidity across all financial channels.

### 📑 Comprehensive Financial Reports & Multi-Format Exports
- **Interactive Monthly Report Modal**: Multi-tab report viewer (`monthly_report_modal.dart`) featuring Overview, Categories, Daily Breakdown, Payment Methods, Budget Compliance, and Financial KPIs.
- **Branded PDF Export**: Generate polished monthly and annual financial statements with custom date ranges, branded headers, category summaries, and chart snapshots (`pdf`, `printing`).
- **CSV Data Export**: Export full transaction ledgers in CSV format compatible with Microsoft Excel, Google Sheets, or tax tools (`csv`).

### 🛡️ Biometric Security & Privacy-First Architecture
- **100% Local NoSQL Storage**: All financial records, profiles, and settings are saved locally using **Hive**. Zero data leaves your device.
- **Biometric Authentication**: Secure app access with Fingerprint scanner, Face ID, or system credentials (`biometric_service.dart`).
- **Custom 4-Digit Security PIN**: Protect app entry with a customizable 4-digit PIN lock screen (`auth_provider.dart`, `pin_lock_screen.dart`).
- **Multi-Tenant Local User Profiles**: Support for multiple local user profiles with personalized names, avatars, and settings (`user_profile_model.dart`).

### 🔔 Animated In-App Notification & Toast System
- **Custom Push Alerts & Toasts**: Non-intrusive animated in-app notifications (`transaction_notification.dart`) with action chips, timer auto-dismissal, and swipe actions.

### 🎨 Personalization, Dynamic Themes & Multi-Currency
- **Dark & Light Glassmorphism Themes**: Premium dark mode designed with glassmorphism and modern glow accents, alongside an accessible light mode (`app_theme.dart`).
- **Multi-Currency Support**: Switch between global currency symbols (`₹`, `$`, `€`, `£`, `¥`, `A$`, `C$`, etc.) with instant formatting updates.
- **Custom Category Manager**: Create, edit, and personalize transaction categories with custom Flutter icon selectors and color pickers.

---

## 🛠️ Tech Stack & Architecture

```mermaid
graph TD
    UI[UI Layer - Flutter Screens & Widgets] --> Provider[State Management - Provider]
    Provider --> Services[Service Layer - AI, SMS, Reports, Voice, OCR]
    Services --> Hive[Storage Layer - Hive NoSQL Local Storage]
    Native[Android Native SmsReceiver] -->|MethodChannel| Services
```

| Component | Technology | Description |
| :--- | :--- | :--- |
| **Framework** | [Flutter 3.10+](https://flutter.dev) | Cross-platform UI toolkit |
| **Language** | [Dart 3.0+](https://dart.dev) | Strongly typed Dart programming language |
| **State Management** | [Provider 6.1.2](https://pub.dev/packages/provider) | Dependency injection and reactive state propagation |
| **Local Persistence** | [Hive 2.2.3](https://pub.dev/packages/hive) & `hive_flutter` | Lightweight, fast key-value NoSQL database engine |
| **Data Visualization** | [fl_chart 0.69.0](https://pub.dev/packages/fl_chart) | Animated line, bar, and pie charts |
| **Document Exporting** | [pdf 3.10.8](https://pub.dev/packages/pdf), [printing](https://pub.dev/packages/printing), [csv](https://pub.dev/packages/csv) | Formatted PDF statement rendering and CSV output |
| **Native Interop** | Kotlin `MethodChannel` | Platform channel for Android SMS broadcast receiver |
| **Notifications** | [flutter_local_notifications 17.1.2](https://pub.dev/packages/flutter_local_notifications) | Local push notification alerts |
| **Media & Fonts** | [google_fonts](https://pub.dev/packages/google_fonts), [image_picker](https://pub.dev/packages/image_picker) | Typography and receipt image selection |

---

## 📁 Project Folder Structure

```text
expense_tracker/
├── android/                        # Native Android project configuration & SmsReceiver implementation
├── ios/                            # Native iOS project configuration
├── assets/                         # Static assets (App icons, illustrations, fallback images)
│   └── images/
├── lib/
│   ├── main.dart                   # Application entry point, Hive initialization, Provider tree setup
│   ├── models/                     # Hive TypeAdapter data models
│   │   ├── transaction_model.dart  # Transaction model (amount, type, category, date, payment method)
│   │   ├── category_model.dart     # Category model (name, icon, color, income/expense flag)
│   │   ├── budget_model.dart       # Budget cap model (category ID, spending limit, period)
│   │   ├── savings_goal_model.dart # Savings target model (title, target, current amount, deadline)
│   │   └── user_profile_model.dart # Local user profile model (name, email, pin, preferences)
│   ├── providers/                  # Application state management logic
│   │   ├── auth_provider.dart      # User authentication and PIN lock state
│   │   ├── transaction_provider.dart# Transaction CRUD, filtering, search, and calculations
│   │   ├── category_provider.dart  # Custom category management state
│   │   ├── budget_provider.dart    # Budget tracking, progress computation, overspend checks
│   │   ├── savings_provider.dart   # Savings goal progress and contribution logging
│   │   └── theme_currency_provider.dart # Dynamic theme toggling & currency selection state
│   ├── services/                   # Business logic services
│   │   ├── ai_insight_service.dart # Financial health, anomaly detection, AI recommendations
│   │   ├── sms_parser_service.dart # Regex engine for bank SMS entity extraction
│   │   ├── sms_auto_capture_service.dart # Service bridging native SMS calls to transaction logs
│   │   ├── smart_categorizer_service.dart # Keyword/heuristic auto-categorization engine
│   │   ├── report_service.dart     # PDF statement generation service
│   │   ├── monthly_report_service.dart # Monthly financial metrics aggregator
│   │   ├── local_storage_service.dart # Hive database open/close and CRUD helper wrapper
│   │   ├── voice_service.dart      # Voice input recognition wrapper
│   │   └── ocr_service.dart        # Image text extraction wrapper for receipts
│   ├── screens/                    # UI Application Screens
│   │   ├── analytics/              # Deep-dive analytics, interactive charts (`analytics_screen.dart`)
│   │   ├── authentication/         # Login & PIN lock screen (`login_screen.dart`, `pin_lock_screen.dart`)
│   │   ├── budget/                 # Budget management & add budget screen (`budget_screen.dart`)
│   │   ├── calendar/               # Calendar view screen (`calendar_screen.dart`)
│   │   ├── categories/             # Category manager screen (`category_screen.dart`)
│   │   ├── dashboard/              # Main navigation & summary screen (`dashboard_screen.dart`)
│   │   ├── expense_income/         # Add/Edit transaction form (`add_edit_transaction_screen.dart`)
│   │   ├── profile/                # Profile management & settings (`profile_screen.dart`)
│   │   ├── reports/                # Statement preview & exporter (`reports_screen.dart`)
│   │   ├── savings/                # Savings goals tracker (`savings_screen.dart`)
│   │   └── splash/                 # Animated startup splash screen (`splash_screen.dart`)
│   ├── utils/                      # Utilities, theme tokens, constants, date formatters
│   │   ├── app_theme.dart          # Dark/Light theme data definitions & palette
│   │   └── formatters.dart         # Currency, date, and percentage formatting helpers
│   └── widgets/                    # Reusable UI Components
│       ├── ai_insight_card.dart    # AI insight widget card
│       ├── balance_summary_card.dart # Header balance overview card
│       ├── credit_card_summary_widget.dart # Credit card style balance banner
│       ├── monthly_budget_card.dart# Budget progress bar tile
│       ├── transaction_notification.dart # Toast/Snackbar notification helper
│       └── transaction_tile.dart   # Standard transaction list item
└── pubspec.yaml                    # Dependencies, assets, and launcher icon configuration
```

---

## 🗄️ Domain Models & Data Schema

Hive HiveFields and Adapters manage the local NoSQL schema:

### 1. `TransactionModel` (`TypeId: 0`)
| Field | Type | Description |
| :--- | :--- | :--- |
| `id` | `String` | Unique transaction ID (UUID/Timestamp) |
| `title` | `String` | Transaction summary / Merchant name |
| `amount` | `double` | Transaction monetary value |
| `date` | `DateTime` | Date and time of transaction |
| `type` | `TransactionType` | Enum (`income`, `expense`) |
| `category` | `String` | Category name or ID |
| `paymentMethod`| `String` | Payment mode (UPI, Credit Card, Cash, Bank Transfer) |
| `notes` | `String?` | Optional user description or note |
| `isAutoCaptured`|`bool` | True if auto-captured from bank SMS |

### 2. `BudgetModel` (`TypeId: 1`)
| Field | Type | Description |
| :--- | :--- | :--- |
| `id` | `String` | Unique budget identifier |
| `categoryId` | `String` | Category identifier budget applies to |
| `amountLimit` | `double` | Maximum budget threshold per month |
| `startDate` | `DateTime` | Budget tracking start period |

### 3. `SavingsGoalModel` (`TypeId: 2`)
| Field | Type | Description |
| :--- | :--- | :--- |
| `id` | `String` | Unique goal identifier |
| `title` | `String` | Name of goal (e.g., Vacation Fund) |
| `targetAmount` | `double` | Total target savings amount |
| `currentAmount`| `double` | Saved amount accumulated to date |
| `targetDate` | `DateTime` | Deadline target completion date |
| `category` | `String` | Associated savings category |

### 4. `CategoryModel` (`TypeId: 3`) & `UserProfileModel` (`TypeId: 4`)
- `CategoryModel`: Maps icon code points, ARGB color codes, category labels, and type flags.
- `UserProfileModel`: Manages local authentication credentials, security PIN hashes, user name, profile picture path, and preferred currency symbol.

---

## 🚀 Getting Started & Installation

### Prerequisites
Before running the application, ensure your environment meets the following requirements:
- **Flutter SDK**: `>= 3.10.0` ([Download Flutter](https://docs.flutter.dev/get-started/install))
- **Dart SDK**: `>= 3.0.0`
- **Android SDK & Build Tools**: JDK 17, Android API level 33+ (for native SMS permission handling)
- **IDE**: Android Studio / VS Code with Flutter and Dart extensions installed

### Installation Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/expense_tracker.git
   cd expense_tracker
   ```

2. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Generate Hive Adapters (If modifying models)**
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **Run the Application**
   - Connect a physical Android/iOS device or start an emulator, then execute:
   ```bash
   flutter run
   ```

---

## 📱 Native Android SMS Integration Setup

To enable real-time SMS transaction auto-capture on Android physical devices:

1. **Permissions in `AndroidManifest.xml`**:
   The app requests `RECEIVE_SMS` and `READ_SMS` permissions. Ensure the following entries are present in `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <uses-permission android:name="android.permission.RECEIVE_SMS" />
   <uses-permission android:name="android.permission.READ_SMS" />
   <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
   ```

2. **Runtime Permission Approval**:
   When prompted on first app execution, tap **Allow** for SMS permission prompts.

3. **Battery Optimization Exclusion**:
   On devices running aggressive battery saver profiles (e.g., Xiaomi MIUI, Samsung OneUI, OnePlus OxygenOS), grant Pocketify background autostart permissions so `SmsReceiver` fires reliably when the app is minimized.

---

## 📦 Production Build & Release

### Build Android Release APK
```bash
flutter build apk --release
```
The output file will be generated at:
`build/app/outputs/flutter-apk/app-release.apk`

### Build Android App Bundle (AAB for Google Play Store)
```bash
flutter build appbundle --release
```
The output file will be generated at:
`build/app/outputs/bundle/release/app-release.aab`

### Build iOS Release App
```bash
flutter build ios --release
```

### Build Web Version
```bash
flutter build web --release
```

---

## 🧪 Testing & Code Quality

Execute the test suite and static code analyzer to ensure stability:

```bash
# Run all unit and widget tests
flutter test

# Run static code analysis and lint checking
flutter analyze
```

---

## 🔧 Troubleshooting & FAQ

<details>
<summary><b>1. Missing Hive Adapters / Build Runner Errors</b></summary>
<br>
If you encounter errors like <code>HiveError: Cannot find adapter for type...</code>, regenerate Hive adapters by running:
<pre><code>flutter pub run build_runner build --delete-conflicting-outputs</code></pre>
</details>

<details>
<summary><b>2. SMS Auto-Capture is not triggering on Android Emulator</b></summary>
<br>
SMS auto-capture requires real SMS broadcasts. To test on Android Emulator:
<ol>
  <li>Open Emulator extended controls (<code>...</code> button).</li>
  <li>Navigate to <b>Phone</b> menu -> <b>SMS message</b> tab.</li>
  <li>Send a sample message such as: <i>"Rs 450.00 debited from a/c XX1234 on 28-JUL-26 at STARBUCKS via UPI."</i></li>
</ol>
</details>

<details>
<summary><b>3. PDF Export fails on Web</b></summary>
<br>
File system saving differs on Web browsers. Pocketify automatically uses browser blob downloads when running on web builds.
</details>

---

## 🗺️ Future Roadmap

- [ ] **Cloud Encrypted Backup**: Optional user-controlled Google Drive & iCloud sync for cross-device backup.
- [ ] **Account Aggregator API**: Direct bank balance sync via open banking protocols.
- [ ] **Multi-Currency Auto Conversion**: Live exchange rate updates for multi-currency transactions.
- [ ] **WearOS & WatchOS Companion**: Quick expense logging widget for smartwatches.

---

## 📄 License & Contributing

Distributed under the **MIT License**. See `LICENSE` for more information.

### Contributing
Contributions are welcome! Follow these steps to contribute:
1. Fork the Project.
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`).
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`).
4. Push to the Branch (`git checkout push origin feature/AmazingFeature`).
5. Open a Pull Request.

---

<p align="center">
  Built with ❤️ using <b>Flutter</b> and <b>Dart</b>
</p>

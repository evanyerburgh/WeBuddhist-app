# WeBuddhist App

A modern Flutter app for learning, sharing, and live collaboration.

## 🚀 Project Goal
WeBuddhist App is designed to help users learn, live, and share knowledge interactively. It features a beautiful UI, supports both light and dark themes, and is built with best Flutter practices.

## 🛠 Features
- Light and Dark theme support with toggle
- Modern Flutter architecture
- Easy to customize and extend

## 📦 Getting Started

### 1. Clone the Repository
```sh
git clone https://github.com/your-username/flutter_pecha.git
cd flutter_pecha
```

### 2. Install Dependencies
```sh
flutter pub get
```

### 3. Environment Setup
Create environment files from the template:
```sh
cp .env.example .env.dev
cp .env.example .env.staging
cp .env.example .env.prod
```
Edit each file with the appropriate values for that environment.

### 4. Run the App

**Android**
```sh
flutter run --flavor dev -t lib/main_dev.dart
flutter run --flavor staging -t lib/main_staging.dart
flutter run --flavor prod -t lib/main_prod.dart
```

Build APK:
```sh
flutter build apk --flavor dev -t lib/main_dev.dart
flutter build apk --flavor staging -t lib/main_staging.dart
flutter build apk --flavor prod -t lib/main_prod.dart
```

Build App Bundle:
```sh
flutter build appbundle --flavor prod -t lib/main_prod.dart
```

**iOS**
```sh
flutter run --flavor dev -t lib/main_dev.dart
flutter run --flavor staging -t lib/main_staging.dart
flutter run --flavor prod -t lib/main_prod.dart
```

Build IPA:
```sh
flutter build ios --flavor prod -t lib/main_prod.dart
```

> **Note:**
> - For iOS, ensure you have Xcode installed and have granted the necessary permissions (see [Flutter macOS setup](https://docs.flutter.dev/get-started/install/macos)).
> - For Android, ensure Android Studio and an emulator/device are set up.

### 5. Adding Localizations

The app uses Flutter's built-in internationalization (l10n) with ARB files for translations.

**Localization files location:**
`lib/core/l10n/`

**To add a new translation string:**

1. Add the key to all ARB files (`app_en.arb`, `app_bo.arb`, `app_zh.arb`):

```json
// app_en.arb
"my_new_key": "My English text",

// app_bo.arb
"my_new_key": "My Tibetan text",

// app_zh.arb
"my_new_key": "My Chinese text",
```

2. Generate localization files:
```sh
flutter gen-l10n
```

3. Use in your widget:
```dart
import 'package:flutter_pecha/core/extensions/context_ext.dart';

// Access translation via context.l10n
Text(context.l10n.my_new_key)
```

**For translations with parameters:**

```json
// app_en.arb
"greeting": "Hello {name}",
"@greeting": {
  "placeholders": {
    "name": {"type": "String"}
  }
}
```

Usage:
```dart
Text(context.l10n.greeting('John'))
```

## ⚙️ Project Structure

This project follows **Clean Architecture** principles with clear separation of concerns across three main layers.

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                           │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  UI Components (Screens, Widgets)                       │   │
│  │  State Management (Riverpod Notifiers/Providers)        │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              ↓                                  │
└─────────────────────────────────────────────────────────────────┘
                              ↓ depends on
┌─────────────────────────────────────────────────────────────────┐
│                      DOMAIN LAYER                               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Entities (Business Objects)                            │   │
│  │  Use Cases (Business Logic)                             │   │
│  │  Repository Interfaces (Contracts)                      │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              ↓                                  │
└─────────────────────────────────────────────────────────────────┘
                              ↓ depends on
┌─────────────────────────────────────────────────────────────────┐
│                       DATA LAYER                                │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Repository Implementations                             │   │
│  │  Data Sources (API, Local Storage)                      │   │
│  │  Models (DTOs for serialization)                        │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              ↓ depends on
┌─────────────────────────────────────────────────────────────────┐
│                    EXTERNAL SERVICES                            │
│         (Auth0, Firebase, HTTP, Storage, etc.)                 │
└─────────────────────────────────────────────────────────────────┘
```

### Folder Structure

```
lib/
├── core/                    # Shared infrastructure & utilities
│   ├── config/              # App configuration
│   ├── di/                  # Dependency injection
│   ├── error/               # Error handling (Failures)
│   ├── network/             # Network utilities
│   ├── services/            # External service integrations
│   ├── storage/             # Local storage utilities
│   └── theme/               # App theming
│
├── features/                # Feature-based modules
│   └── auth/                # ← Authentication feature example
│       ├── domain/          # Business logic (no dependencies)
│       ├── data/            # Data implementation
│       └── presentation/    # UI & state management
│
└── shared/                  # Cross-cutting concerns
    ├── data/                # Shared data layer utilities
    ├── domain/              # Shared domain logic
    ├── presentation/        # Shared UI components
    └── widgets/             # Reusable widgets
```

### Auth Flow Example

Here's how authentication follows clean architecture through all layers:

#### 1. Domain Layer (`features/auth/domain/`)
*Pure business logic with no framework dependencies*

```
domain/
├── entities/
│   └── user.dart                    # User business entity
├── repositories/
│   └── auth_repository.dart         # Repository interface (contract)
└── usecases/
    ├── login_usecase.dart           # Login business logic
    ├── get_current_user_usecase.dart
    └── logout_usecase.dart
```

**Key points:**
- `User` entity: Pure Dart class with business properties
- `AuthRepository`: Abstract interface defining data operations
- `LoginUseCase`: Orchestrates login logic, returns `Either<Failure, User>`

#### 2. Data Layer (`features/auth/data/`)
*Implements domain contracts, handles external dependencies*

```
data/
├── models/
│   └── user_model.dart              # DTO for JSON serialization
├── datasources/
│   └── auth_remote_datasource.dart  # API/Service calls
└── repositories/
    └── auth_repository_impl.dart    # Implements AuthRepository
```

**Key points:**
- `UserModel`: Handles JSON ↔ Dart conversion
- `AuthRemoteDataSource`: Makes actual API calls
- `AuthRepositoryImpl`: Implements domain interface, uses datasource

#### 3. Presentation Layer (`features/auth/presentation/`)
*UI and state management*

```
presentation/
├── providers/
│   ├── auth_notifier.dart           # State management
│   ├── auth_providers.dart          # DI setup
│   └── use_case_providers.dart      # Use case providers
├── screens/
│   └── login_page.dart              # Login UI
└── widgets/
    └── login_form.dart              # Reusable form widget
```

**Key points:**
- `AuthNotifier`: Manages auth state, calls use cases
- `authProviders`: Wire up dependencies using Riverpod
- `LoginPage`: UI that consumes state via providers

### Data Flow Example: Login

```
User clicks login button
        ↓
LoginPage (Presentation)
        ↓
AuthNotifier.login() (Presentation)
        ↓
LoginUseCase.call() (Domain)
        ↓
AuthRepository.login() (Domain interface)
        ↓
AuthRepositoryImpl.login() (Data implementation)
        ↓
AuthRemoteDataSource.login() (Data)
        ↓
External Auth Service
        ↓
Returns Either<Failure, User>
        ↓
User entity flows back up through layers
        ↓
AuthNotifier updates state
        ↓
UI rebuilds with new state
```

### Key Principles

| Layer | Responsibility | Dependencies |
|-------|---------------|--------------|
| **Domain** | Business rules & logic | None (pure Dart) |
| **Data** | Data sources & persistence | Domain, external services |
| **Presentation** | UI & state management | Domain (via use cases) |

### Benefits

- **Testable**: Each layer can be unit tested independently
- **Maintainable**: Changes in one layer don't break others
- **Scalable**: Easy to add new features following same pattern
- **Flexible**: Swap implementations (e.g., change API) without affecting business logic

## 🤝 Contributing
Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change.

## 📄 License
[MIT](LICENSE)





**Table of Contents Screen**
- Browse through organized text content lists with ease
- View all available versions of each text in one convenient location

**Reader Screen**
- Immersive reading experience with optimized formatting


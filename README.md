# TVET Document Management System

A production-ready MVP for a Technical and Vocational Education and Training (TVET) office. It generates standardized documents (Certificate of Appearance, Internal Communication, External Communication) from user-supplied Word templates, assigns auto-incrementing document codes, and stores an audit trail.

---

## System Architecture

```
┌─────────────────────────────┐
│     Flutter Web/Desktop/App │
│  (Material 3, Provider, Dio)│
└──────────────┬──────────────┘
               │ REST / JSON
┌──────────────▼──────────────┐
│  Laravel 11 + PHP + Eloquent│
│  Auth, Documents, Codes     │
└──────────────┬──────────────┘
               │
┌──────────────▼──────────────┐
│  PostgreSQL                 │
│  Templates & generated docs │
└─────────────────────────────┘
```

- **Frontend:** Flutter cross-platform app (mobile + desktop + web).
- **Backend:** Laravel 11 + PHP + Eloquent + PostgreSQL.
- **Templates:** `.docx` files with `PhpOffice/PhpWord TemplateProcessor` placeholders (e.g. `${name}`, `${code}`).
- **Document codes:** Per-type yearly sequence (`<PREFIX>-<YYYY>-<NNNN>`).
- **Storage:** Local filesystem in `backend/storage` (abstracted; swap for S3 later).

---

## File Structure

```
tvet system/
├── README.md
├── docker-compose.yml
├── backend-laravel/          # Laravel 11 API (PostgreSQL)
│   ├── .env.example
│   ├── composer.json
│   ├── artisan
│   ├── public/index.php
│   ├── bootstrap/app.php
│   ├── routes/
│   │   ├── api.php
│   │   └── web.php
│   ├── app/
│   │   ├── Models/
│   │   ├── Http/Controllers/Api/
│   │   └── Http/Middleware/ApiAuth.php
│   ├── database/
│   │   ├── migrations/
│   │   └── seeders/
│   └── storage/
│       ├── app/templates/    # uploaded .docx templates
│       └── app/generated/    # generated .docx files
└── frontend/                 # Flutter app
    ├── pubspec.yaml
    └── lib/
        ├── main.dart
        ├── main_shell.dart
        ├── core/
        │   ├── api_client.dart
        │   ├── auth_provider.dart
        │   ├── app_theme.dart
        │   └── constants.dart
        └── shared/presentation/
            ├── screens/
            └── widgets/
```

---

## Database Schema (Laravel Migrations)

Tables:

- `users` — authentication and roles
- `offices` — office metadata and default coordinator
- `document_types` — COA, IC, EC definitions with active template
- `document_templates` — uploaded `.docx` templates
- `document_records` — generated document audit trail
- `document_sequences` — per-type/year code counters
- `settings` — app-wide settings (e.g. `DEFAULT_COORDINATOR_NAME`)

See `backend-laravel/database/migrations/2024_01_01_000000_create_tvet_tables.php` for the full schema.

---

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/auth/login` | Login (JWT) |
| GET | `/api/v1/auth/me` | Current user |
| GET | `/api/v1/offices` | List offices |
| GET | `/api/v1/document-types` | List document types |
| GET | `/api/v1/document-types/:slug` | Single type |
| GET | `/api/v1/document-types/:slug/next-code` | Preview next code |
| POST | `/api/v1/templates` | Upload a `.docx` template for a type |
| GET | `/api/v1/templates?typeId=...` | List templates |
| POST | `/api/v1/documents/:documentTypeSlug/generate` | Generate a document |
| GET | `/api/v1/documents` | List generated documents |
| GET | `/api/v1/documents/:id` | Get record |
| GET | `/api/v1/documents/:id/download` | Download generated `.docx` |
| GET | `/api/v1/settings/:key` | Get app setting (e.g. default coordinator) |

---

## UI Architecture

- `MaterialApp` with a `NavigationDrawer` / `NavigationRail` per platform.
- One module per document type with its own route, repository, provider and form.
- Shared widgets for the navigation drawer, code preview, document list, and async buttons.
- `Provider` handles local state and API calls through `ApiClient`.

---

## Quick Start

1. `docker-compose up -d` (PostgreSQL).
2. Set up the Laravel backend:

```bash
cd "backend-laravel"
copy .env.example .env
composer install
php artisan key:generate
php artisan migrate
php artisan db:seed
php artisan serve --port=3001
```

3. Run the Flutter frontend:

```bash
cd "frontend"
flutter create .
flutter pub get
flutter run
```

Use the login `coordinator@tvet.gov` / `password` for the seeded coordinator.

The Laravel app runs on `http://localhost:3001`, matching the Flutter `apiBaseUrl`.

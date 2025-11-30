# LedgerZero

**A Sovereign Personal Finance Application**

## Overview

LedgerZero is a cross-platform personal finance application built with Flutter that implements zero-based envelope budgeting without subscriptions or server-side dependencies. It operates on a "Local-First" architecture, ensuring complete data privacy and operational sovereignty.

## Core Value Propositions

### 1. Economic Sovereignty
- **One-time purchase model**: $49.99-$79.99 lifetime license
- Free trial with limited functionality (100 transactions or 3 accounts)
- No recurring subscription fees
- Major version upgrades available at discounted price for existing users

### 2. Data Sovereignty
- All data stored locally on device in encrypted SQLite database
- User's financial data never touches developer servers
- Synchronization via user's own cloud storage (iCloud Drive, Google Drive, Dropbox)
- "Bring Your Own Cloud" (BYOC) architecture

### 3. Operational Sovereignty
- Fully functional offline - no internet connection required
- Instant performance with zero latency
- No dependency on external services or APIs
- Works in airplane mode, poor signal areas, or completely disconnected

### 4. Methodological Sovereignty
- Strict envelope method / zero-based budgeting implementation
- Manual control over all categorization
- Deterministic, rule-based automation (no AI guessing)
- User maintains complete agency over their financial ledger

## Target User: "The Architect"

**Demographics:**
- Age: 25-45
- Financially literate
- Tech-savvy (engineering, tech, administration backgrounds)

**Psychographics:**
- Values privacy and data ownership
- Prefers ownership over rental models
- Uses password managers and ad-blockers
- Dislikes subscription fatigue

**Pain Points:**
- Frustrated by YNAB's price increases ($109/year)
- Concerned about Mint selling user data
- Finds Excel/Sheets too cumbersome on mobile
- Finds open-source alternatives too complex or poorly designed

**Willingness to Pay:**
- High - regularly purchases premium apps ($50+ for quality software)
- Views one-time purchase as bargain vs. subscription models

## Technical Architecture

### Framework: Flutter
- **Cross-platform**: Single codebase for iOS, Android, macOS, Windows, Linux
- **Performance**: 60/120 FPS with Impeller rendering engine
- **Native feel**: Platform-specific UI/UX patterns
- **95% code sharing** across all platforms
- **FFI support**: Direct C/C++ library integration

### Database: Drift + SQLite

**Why Drift?**
- Type-safe Dart DSL that compiles to SQL
- ACID compliance for financial data integrity
- Reactive streams for real-time UI updates
- Compile-time schema error detection
- Superior relational query performance

**Core Entities:**
- Accounts
- Categories & Category Groups
- Transactions
- Budget Allocations
- Payees

**Data Relationships:**
- Transaction → Account (Many-to-One)
- Transaction → Category (Many-to-One)
- Transaction → Payee (Many-to-One)
- Category → CategoryGroup (Many-to-One)
- Budget → Category + Month (Composite Key)

### Security: SQLCipher Encryption

**Encryption at Rest:**
- SQLCipher integration via `sqlcipher_flutter_libs`
- AES-256 encryption of entire database
- Encryption key derived from master password or biometrics
- Key storage in hardware-backed secure storage:
  - iOS: Keychain
  - Android: Keystore
- Uses `flutter_secure_storage` for key management

**Security Guarantees:**
- Stolen device protection - data inaccessible without key
- No plain-text file system storage
- Device-specific encryption prevents database file copying

### Synchronization: File-Based Delta Log System

**Architecture:**
- No central server required
- Leverages user's existing cloud storage
- Delta-based sync (not full database sync)
- Conflict-resistant design

**Delta Log Process:**
1. User creates/modifies data on Device A
2. Change committed to local SQLite database
3. Delta JSON file generated with change metadata
4. Delta uploaded to user's cloud folder (`/LedgerZero/Sync/`)
5. Device B watches folder, downloads new deltas
6. Device B replays deltas to local database

**Delta File Format:**
```json
{
  "timestamp": "2025-01-15T14:23:45.123Z",
  "deviceUUID": "abc-123-def-456",
  "sequence": 1,
  "action": "INSERT",
  "table": "transactions",
  "data": {
    "id": "tx_001",
    "amount": -45.50,
    "date": "2025-01-15",
    "payee": "Mario's Restaurant",
    "category_id": "cat_dining_out",
    "account_id": "acc_checking"
  }
}
```

**Cloud Provider Integration:**
- **Google Drive**: `googleapis` package with `drive.file` scope (app-created files only)
- **iCloud Drive**: `icloud_storage` package
- **Dropbox**: Future consideration

**Conflict Resolution:**
- Last-Writer-Wins based on UTC timestamp
- High-precision timestamps minimize collisions
- Financial data is additive (low conflict probability)
- Manual resolution UI for rare conflicts

**Zero Developer Cost:**
- User pays for their own cloud storage
- No bandwidth costs for developer
- Scales infinitely without infrastructure costs

## Core Features

### 1. Natural Language Transaction Entry

**User Experience:**
```
User types: "Dinner 45.50 at Mario's next friday"
```

**Technical Processing:**
1. **Temporal parsing** via `chrono_dart`: "next friday" → DateTime
2. **Amount extraction**: Regex finds "45.50"
3. **Entity recognition**: 
   - "Dinner" fuzzy-matches to "Dining Out" category
   - "Mario's" identified as new or existing payee
4. **Result**: Full transaction object presented for one-tap confirmation

**Implementation Stack:**
- `chrono_dart` for date/time parsing
- Custom regex for amount extraction: `(?:\$)?\d+(?:\.\d{1,2})?`
- Local fuzzy matching against existing categories/payees
- 100% offline processing

### 2. CSV Import & Reconciliation

**Features:**
- Bank statement CSV import
- Intelligent column mapping (one-time setup per bank)
- Saved "Import Profiles" for repeat imports
- Automatic deduplication using hash(Date + Amount + Payee)
- Transaction matching and reconciliation tools

**Migration Support:**
- YNAB export format parser
- Mint export format parser
- Generic CSV with configurable mapping

### 3. Envelope Budgeting Logic

**Core Concepts:**
- **To Be Budgeted (TBB)**: Income minus allocated amounts
- **Category Budgets**: Monthly allocation per category
- **Available**: Budget + Previous Overspending - Spending
- **Envelope Metaphor**: Money assigned to specific purposes

**Calculations:**
- Real-time budget availability updates
- Overspending rollover handling
- Month-to-month carry-forward logic
- Goal tracking and funding recommendations

### 4. Multi-Account Support

**Account Types:**
- Checking
- Savings
- Credit Card
- Cash
- Investment (tracking only)
- Loan/Debt (negative starting balance)

**Features:**
- Account-specific transaction filtering
- Transfer handling between accounts
- Balance reconciliation tools
- Net worth calculation across all accounts

### 5. Reporting & Analytics

**Built-in Reports:**
- Spending by Category (monthly, yearly)
- Income vs. Expense trends
- Net Worth over time
- Category budget vs. actual comparison
- Payee spending analysis

**Export Capabilities:**
- CSV export of transactions
- Filtered date range exports
- Category-specific exports
- Full database backup

### 6. Advanced Features

**Scheduled Transactions:**
- Recurring income/bills
- One-time future transactions
- Auto-entry on due date

**Goals:**
- Target balance by date
- Monthly funding target
- Debt payoff calculators

**Widgets (iOS/Android):**
- Quick budget overview on home screen
- Rapid transaction entry widget
- Category balance at-a-glance

## Technology Stack

### Core Dependencies

```yaml
dependencies:
  flutter: sdk: flutter
  
  # Database & Persistence
  drift: ^2.18.0
  sqlite3_flutter_libs: ^0.5.24
  sqlcipher_flutter_libs: ^0.6.1
  flutter_secure_storage: ^9.2.2
  
  # Cloud Sync
  googleapis: ^13.2.0
  googleapis_auth: ^1.6.0
  icloud_storage: ^1.0.0  # Or equivalent
  
  # Natural Language Processing
  chrono_dart: ^2.0.1
  
  # UI & State Management
  riverpod: ^2.5.1  # Or provider/bloc
  go_router: ^14.2.7
  
  # Utilities
  intl: ^0.19.0  # Internationalization & date formatting
  uuid: ^4.5.0
  csv: ^6.0.0
  path_provider: ^2.1.4
  shared_preferences: ^2.3.2
  
  # Platform Integration
  local_auth: ^2.3.0  # Biometric authentication
  package_info_plus: ^8.0.2
  device_info_plus: ^10.1.2
```

### Development Dependencies

```yaml
dev_dependencies:
  flutter_test: sdk: flutter
  drift_dev: ^2.18.0
  build_runner: ^2.4.12
  flutter_lints: ^4.0.0
  mockito: ^5.4.4
  integration_test: sdk: flutter
```

## Internationalization Setup (Crucial for Europe/Germany)

### Add Localization Packages
- Run `flutter pub add flutter_localizations intl`.
- Enable `generate: true` in your `pubspec.yaml`.

### Configure L10n
- Create a file `l10n.yaml` in root.
- Set `template-arb-file: app_en.arb`.
- Set `output-localization-file: app_localizations.dart`.

### Create Language Files
- Create `lib/l10n/app_en.arb` (English) and `lib/l10n/app_de.arb` (German).

### Rule
Never hardcode text like `Text("Budget")` in widgets. Always use `Text(AppLocalizations.of(context)!.budget)`.

### Why
It allows you to switch languages instantly and handles date formats automatically.

## Database Schema

### Tables

**accounts**
- id (TEXT, PRIMARY KEY)
- name (TEXT, NOT NULL)
- type (TEXT, NOT NULL) // checking, savings, credit, cash
- currency (TEXT, DEFAULT 'USD')
- starting_balance (REAL, DEFAULT 0)
- current_balance (REAL, DEFAULT 0)
- is_closed (INTEGER, DEFAULT 0)
- created_at (TEXT)
- updated_at (TEXT)

**categories**
- id (TEXT, PRIMARY KEY)
- name (TEXT, NOT NULL)
- category_group_id (TEXT, FOREIGN KEY)
- is_hidden (INTEGER, DEFAULT 0)
- sort_order (INTEGER)
- created_at (TEXT)

**category_groups**
- id (TEXT, PRIMARY KEY)
- name (TEXT, NOT NULL)
- sort_order (INTEGER)
- created_at (TEXT)

**transactions**
- id (TEXT, PRIMARY KEY)
- account_id (TEXT, FOREIGN KEY, NOT NULL)
- date (TEXT, NOT NULL)
- amount (REAL, NOT NULL) // Negative for outflows, positive for inflows
- payee_id (TEXT, FOREIGN KEY)
- category_id (TEXT, FOREIGN KEY)
- memo (TEXT)
- cleared (INTEGER, DEFAULT 0) // 0=uncleared, 1=cleared, 2=reconciled
- approved (INTEGER, DEFAULT 1)
- transfer_account_id (TEXT, FOREIGN KEY) // For transfers
- transfer_transaction_id (TEXT) // Link to counterpart transaction
- created_at (TEXT)
- updated_at (TEXT)

**payees**
- id (TEXT, PRIMARY KEY)
- name (TEXT, NOT NULL)
- auto_category_id (TEXT, FOREIGN KEY) // Default category for this payee
- created_at (TEXT)

**budgets**
- id (TEXT, PRIMARY KEY)
- category_id (TEXT, FOREIGN KEY)
- month (TEXT, NOT NULL) // Format: YYYY-MM
- budgeted (REAL, DEFAULT 0)
- activity (REAL, DEFAULT 0) // Sum of transactions in month
- available (REAL, DEFAULT 0) // Calculated: budgeted - activity + carry-over
- created_at (TEXT)
- updated_at (TEXT)
- UNIQUE(category_id, month)

**scheduled_transactions**
- id (TEXT, PRIMARY KEY)
- account_id (TEXT, FOREIGN KEY)
- payee_id (TEXT, FOREIGN KEY)
- category_id (TEXT, FOREIGN KEY)
- amount (REAL)
- frequency (TEXT) // daily, weekly, monthly, yearly
- next_date (TEXT)
- end_date (TEXT)
- auto_approve (INTEGER, DEFAULT 0)
- created_at (TEXT)

**sync_log**
- id (TEXT, PRIMARY KEY)
- delta_filename (TEXT, UNIQUE)
- action (TEXT) // INSERT, UPDATE, DELETE
- table_name (TEXT)
- record_id (TEXT)
- applied_at (TEXT)
- device_uuid (TEXT)

### Indexes

```sql
CREATE INDEX idx_transactions_account ON transactions(account_id);
CREATE INDEX idx_transactions_date ON transactions(date);
CREATE INDEX idx_transactions_category ON transactions(category_id);
CREATE INDEX idx_budgets_month ON budgets(month);
CREATE INDEX idx_sync_log_applied ON sync_log(applied_at);
```

## Development Phases

### Phase 1: MVP - Local-Only Budgeting (Months 1-3)
**Goal**: Functional single-device budgeting app

**Deliverables:**
- Complete Drift database schema
- Accounts CRUD
- Categories & Category Groups management
- Manual transaction entry form
- Envelope budgeting logic (TBB calculation)
- Basic transaction list views
- Category spending reports
- Dark mode UI

**Success Criteria:**
- User can create accounts
- User can budget money to categories
- User can record transactions
- Math is 100% accurate
- App runs smoothly at 60 FPS

### Phase 2: Synchronization (Months 4-5)
**Goal**: Multi-device support via cloud sync

**Deliverables:**
- Google Drive integration
- iCloud Drive integration
- Delta log generation system
- Delta log replay system
- Conflict detection & resolution UI
- Offline queue management
- Sync status indicators

**Success Criteria:**
- Changes on Device A appear on Device B within 5 minutes
- Offline changes sync when connectivity restored
- No data loss during sync conflicts
- "Airplane mode for a week" scenario handled gracefully

### Phase 3: Polish & Intelligence (Months 6-7)
**Goal**: Premium UX justifying $50 price point

**Deliverables:**
- Natural language transaction input (chrono_dart)
- CSV import with bank mapping
- YNAB migration tool
- Mint migration tool
- Custom app icons
- Haptic feedback
- iOS widgets
- Onboarding tutorial
- In-app help system

**Success Criteria:**
- Natural language parsing >85% accuracy
- CSV import successful for top 10 banks
- User can migrate from YNAB/Mint in <10 minutes
- App feels "premium" in user testing

## File Structure

```
ledger_zero/
├── lib/
│   ├── main.dart
│   ├── app/
│   │   ├── app.dart
│   │   └── theme.dart
│   ├── core/
│   │   ├── constants/
│   │   ├── utils/
│   │   └── extensions/
│   ├── data/
│   │   ├── database/
│   │   │   ├── database.dart (Drift)
│   │   │   ├── tables/
│   │   │   └── daos/
│   │   ├── models/
│   │   └── repositories/
│   ├── domain/
│   │   ├── entities/
│   │   ├── repositories/
│   │   └── usecases/
│   ├── presentation/
│   │   ├── screens/
│   │   │   ├── accounts/
│   │   │   ├── budget/
│   │   │   ├── transactions/
│   │   │   ├── reports/
│   │   │   └── settings/
│   │   ├── widgets/
│   │   └── providers/
│   └── services/
│       ├── sync/
│       │   ├── google_drive_sync.dart
│       │   ├── icloud_sync.dart
│       │   └── delta_manager.dart
│       ├── nlp/
│       │   └── transaction_parser.dart
│       ├── csv/
│       │   └── csv_importer.dart
│       └── encryption/
│           └── security_manager.dart
├── test/
├── integration_test/
└── pubspec.yaml
```

## Design Principles

### User Interface
- **Minimalist**: No clutter, focus on the task
- **Dark Mode First**: Primary design in dark theme
- **Native Feel**: Platform-specific patterns (Cupertino on iOS, Material on Android)
- **Instant Feedback**: No loading spinners for local operations
- **One-Tap Actions**: Minimize friction in common tasks

### User Experience
- **Privacy by Default**: No analytics, no tracking, no telemetry
- **Offline Always**: Never assume internet connectivity
- **Trust Through Transparency**: Show exactly what's happening during sync
- **Respect User Intelligence**: Don't oversimplify or patronize
- **Progressive Disclosure**: Advanced features available but not in your face

### Code Quality
- **Type Safety**: Leverage Dart's strong typing
- **Immutability**: Prefer immutable data structures
- **Testability**: Write unit tests for all business logic
- **Documentation**: Comment complex algorithms and business rules
- **Performance**: Profile and optimize hot paths

## Marketing Strategy

### App Store Optimization (ASO)

**Keywords:**
- Primary: "Offline budget", "No subscription finance", "Envelope budgeting"
- Secondary: "YNAB alternative", "Mint replacement", "Privacy budget tracker"
- Long-tail: "Expense tracker one time purchase", "Local budget app"

**App Store Description Structure:**
1. Lead with "No Subscription" and "One-Time Purchase"
2. Emphasize privacy and local data storage
3. Highlight offline functionality
4. Feature comparison vs. YNAB/Mint
5. List key features
6. Technical security details

**Screenshots Strategy:**
- Screenshot 1: Transaction entry with "Offline" badge
- Screenshot 2: Budget overview in dark mode
- Screenshot 3: "Your data stays on YOUR device" visual
- Screenshot 4: Sync settings showing iCloud/Drive options
- Screenshot 5: Reports/analytics
- Screenshot 6: Pricing comparison vs. subscriptions

### Community Marketing

**Reddit Strategy:**
- **r/ynab**: "I built the YNAB alternative I wanted" (founder story)
- **r/flutterdev**: Technical deep-dives, "Building in public" updates
- **r/privacy**: "Local-first financial sovereignty" angle
- **r/PersonalFinance**: "How I built a private budget tracker"

**Content Calendar:**
- Month 1: Project announcement, gather feedback
- Month 2: Architecture deep-dive
- Month 3: MVP beta access
- Month 4: Sync implementation post
- Month 5: Security & encryption writeup
- Month 6: Launch post

**Hacker News Strategy:**
- Title: "Show HN: LedgerZero – One-time purchase budget app with local-first architecture"
- Post when US-friendly time zone (morning PST)
- Engage authentically in comments

### Pricing Psychology

**Trial Strategy:**
- Generous free tier (100 transactions, 3 accounts)
- No time limit on trial
- Clear upgrade prompt when limit reached
- "Try before you buy" builds trust

**Pricing Tiers:**
- Standard: $49.99 (iOS/Android)
- Professional: $79.99 (includes Desktop apps)
- Family: $99.99 (5 devices, shared sync folder)

**Launch Pricing:**
- First 1000 customers: $39.99 (early bird)
- Creates urgency and rewards early adopters
- Generates word-of-mouth from price-conscious users

## Competitive Comparison

| Feature | LedgerZero | YNAB | Mint | Excel | Actual Budget |
|---------|-----------|------|------|-------|---------------|
| **Pricing** | $50 once | $109/year | Free (ad-supported) | Included with Office | Free (self-host) |
| **Privacy** | ⭐⭐⭐⭐⭐ Local + Own Cloud | ⭐⭐ Third Party Cloud | ⭐ Sells Data | ⭐⭐⭐ Microsoft/Google | ⭐⭐⭐⭐⭐ Self-hosted |
| **Mobile UX** | ⭐⭐⭐⭐⭐ Native | ⭐⭐⭐ Web wrapper | ⭐⭐⭐ Native | ⭐ Terrible | ⭐⭐⭐ PWA |
| **Offline** | ⭐⭐⭐⭐⭐ Full | ⭐ Requires connection | ❌ Cloud-only | ⭐⭐⭐⭐ Local file | ⭐⭐⭐ Limited |
| **Setup** | ⭐⭐⭐⭐⭐ Install & Go | ⭐⭐⭐ Account required | ⭐⭐⭐ Account required | ⭐ Complex | ⭐⭐ Technical setup |
| **Bank Sync** | Manual/CSV | Auto (Plaid) | Auto | Manual | Auto (GoCardless) |
| **Longevity** | ⭐⭐⭐⭐⭐ Forever | ⭐ Until sub ends | ⭐ Shut down 2023 | ⭐⭐⭐⭐⭐ Forever | ⭐⭐⭐ Depends on maintainer |

## Success Metrics

### Year 1 Goals
- **Revenue**: $250,000 gross ($212,500 net after app store fees)
- **Sales**: 5,000 lifetime licenses
- **Reviews**: 4.5+ star average with 500+ reviews
- **Support**: <5% refund rate
- **Retention**: 80% of users still active after 6 months

### Key Performance Indicators (KPIs)
- **Conversion Rate**: 10% of trial users to paid (target)
- **App Store Ranking**: Top 50 in Finance category
- **Crash Rate**: <0.1%
- **Load Time**: <1 second from tap to usable
- **Sync Success Rate**: >99.5%

## Risk Mitigation

### Technical Risks
- **Sync conflicts**: Mitigated by delta log design and timestamp-based resolution
- **Data corruption**: Mitigated by SQLite's ACID guarantees and backup exports
- **Platform API changes**: Mitigated by stable APIs (SQLite, native file systems)
- **Performance on older devices**: Mitigated by Flutter's efficiency and local-first design

### Business Risks
- **Low sales volume**: Mitigated by surgical marketing to frustrated YNAB/Mint users
- **Price resistance**: Mitigated by clear value proposition and trial period
- **Feature requests**: Mitigated by "finished product" philosophy and clear scope
- **Piracy**: Mitigated by low price point and in-app license verification

### Legal Risks
- **Financial advice regulations**: Mitigated by "tool not advisor" positioning
- **Data breach liability**: Eliminated by local-first architecture (no user data on servers)
- **GDPR compliance**: Automatically compliant (user controls all data)

## Future Expansion

### Version 2.0 Features (Year 2-3)
- Desktop apps (macOS, Windows, Linux)
- Advanced reporting with charts
- Budget templates and sharing
- Multi-currency support
- Investment tracking
- Custom fields and tags
- API for power users

### Ecosystem Expansion
- **LedgerZero Health**: Same architecture for nutrition/fitness tracking
- **LedgerZero Docs**: Local-first document management
- **Sovereign Suite**: Bundle of privacy-respecting tools

## Support Strategy

### Documentation
- Comprehensive in-app help
- Video tutorials (hosted on YouTube)
- FAQ on website
- Community forum (Discourse self-hosted)

### Support Channels
- Email support (primary)
- GitHub Issues (bug reports)
- Reddit community (peer support)
- No phone support (keeps costs low)

### Updates
- Bug fixes: Free, released as needed
- Minor features: Free for 2 years post-purchase
- Major versions: Paid upgrade at 50% discount for existing users

## Open Source Considerations

**Current Stance:** Closed source, proprietary

**Reasoning:**
- One-time purchase model requires protecting IP
- Prevents copycat apps that undercut pricing
- Allows sustainable solo/small team development

**Future Possibility:**
- After reaching revenue sustainability, consider:
  - Open-sourcing sync protocol (benefits ecosystem)
  - Open-sourcing encryption layer (community audit)
  - Dual licensing (source-available for audit, commercial use requires license)

## Conclusion

LedgerZero represents a strategic opportunity to capture a disenfranchised market segment that is actively seeking alternatives to subscription-based financial tools. By leveraging modern cross-platform development tools (Flutter), proven local database technology (SQLite/Drift), and user-owned cloud infrastructure, the application delivers a premium experience without recurring costs for either the user or the developer.

The technical architecture is sound, the market demand is validated through extensive user research, and the business model is sustainable. This is not a nostalgic return to the past, but a forward-looking product that respects user sovereignty while delivering modern features and performance.

**The path forward is clear: Build the tool that users are begging for, price it fairly, and let the quality speak for itself.**

---

## Contact & Resources

- **Website**: [Coming Soon]
- **GitHub**: [Private Repository]
- **Email**: support@ledgerzero.app
- **Reddit**: u/ledgerzero_dev
- **License**: Proprietary (One-time purchase)

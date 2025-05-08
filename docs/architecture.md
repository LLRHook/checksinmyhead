## The Architecture ##

# Checkmate Architecture

## Overview

Checkmate implements a privacy-focused receipt splitting app with a modular, maintainable architecture. This document outlines the architectural decisions, data flow patterns, and component organization that powers Checkmate's zero-cloud-storage approach to bill splitting.

## Core Architectural Principles

1. **Privacy by Design**: All data remains on-device with no external dependencies for core functionality
2. **Modular Component Structure**: Clear separation of concerns with specialized components
3. **Unidirectional Data Flow**: Predictable state management using Provider pattern
4. **Persistence without Cloud**: Local-only storage using SQLite via Drift
5. **Adaptive UI**: Support for both light and dark themes with consistent experience

## System Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                        Presentation Layer                         │
├──────────────────────────────────────────────────────────────────┤
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐      │
│  │  Screens  │  │  Widgets  │  │  Dialogs  │  │ Bottom    │      │
│  │           │  │           │  │           │  │ Sheets    │      │
│  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘      │
│        │              │              │              │            │
│        └──────────────┼──────────────┼──────────────┘            │
│                       │              │                           │
│  ┌─────────────────┐  │              │  ┌─────────────────────┐  │
│  │ Animation       │  │              │  │ Theme               │  │
│  │ Controllers     │<─┘              └─>│ Management          │  │
│  └─────────────────┘                    └─────────────────────┘  │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│                       State Management                            │
├──────────────────────────────────────────────────────────────────┤
│  ┌───────────────┐   ┌───────────────┐   ┌───────────────────┐   │
│  │ Model         │   │ Provider      │   │ State             │   │
│  │ Classes       │<──┤ Definitions   │<──┤ Controllers       │   │
│  └───────┬───────┘   └───────────────┘   └───────────────────┘   │
│          │                                                        │
│          ▼                                                        │
│  ┌───────────────┐   ┌───────────────┐   ┌───────────────────┐   │
│  │ Calculation   │   │ Utility       │   │ Helper            │   │
│  │ Logic         │<──┤ Functions     │<──┤ Classes           │   │
│  └───────────────┘   └───────────────┘   └───────────────────┘   │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│                        Data Layer                                 │
├──────────────────────────────────────────────────────────────────┤
│  ┌───────────────┐   ┌───────────────┐   ┌───────────────────┐   │
│  │ Database      │   │ Data Models   │   │ Database Access   │   │
│  │ Definition    │<──┤ (Tables)      │<──┤ Objects           │   │
│  └───────┬───────┘   └───────────────┘   └───────────────────┘   │
│          │                                                        │
│          ▼                                                        │
│  ┌───────────────┐   ┌───────────────┐                           │
│  │ Drift ORM     │-->│ SQLite        │                           │
│  │ Wrapper       │   │ Database      │                           │
│  └───────────────┘   └───────────────┘                           │
└──────────────────────────────────────────────────────────────────┘
```

## Module Structure

Checkmate is organized into the following core modules:

### Core Data Models

```
lib/models/
├── person.dart           # Person model with name and color
├── bill_item.dart        # Bill item with assignments to people
└── ...
```

The data models form the foundation of the application. Key models include:

- **Person**: Represents a participant in the bill splitting with a name and color
- **BillItem**: Represents a single item from a receipt with price and assignments

### Screens

```
lib/screens/
├── landing_screen.dart            # Main entry point
├── splash_screen.dart             # Startup screen with animations
├── settings/                      # App settings module
├── quick_split/                   # Bill splitting flow
│   ├── participant_selection/     # Adding people to the bill
│   ├── bill_entry/                # Entering bill details
│   ├── item_assignment/           # Assigning items to people
│   └── bill_summary/              # Final bill breakdown
└── recent_bills/                  # Bill history access
```

The screens implement the primary user flows with a focus on responsive, intuitive UI. The application follows a logical progression through the bill-splitting process:

1. **Participant Selection**: Choose who's splitting the bill
2. **Bill Entry**: Add bill details (subtotal, tax, etc.)  
3. **Item Assignment**: Allocate items to participants
4. **Bill Summary**: View final breakdown and share

### Database Layer

```
lib/database/
├── database.dart         # Database definition with Drift ORM
└── database_provider.dart # Singleton access point
```

The database layer handles all persistence requirements using:

- **Drift ORM**: Type-safe database access
- **SQLite**: On-device storage with no cloud dependencies
- **Single Instance Pattern**: Database provider ensures consistent access

## Data Flow Patterns

### Unidirectional Data Flow

Checkmate implements a unidirectional data flow pattern:

```
┌──────────────┐       ┌──────────────┐       ┌──────────────┐
│              │       │              │       │              │
│    Models    │──────>│  Providers   │──────>│    Widgets   │
│              │       │              │       │              │
└──────────────┘       └──────────────┘       └──────────────┘
       ▲                                             │
       │                                             │
       │                                             │
       └─────────────────────────────────────────────┘
                        Actions
```

This pattern ensures:

1. Models store the core business logic and data
2. Providers expose models to the UI and handle state changes
3. Widgets render UI based on provided state and dispatch actions
4. Actions update models, which update providers, which update widgets

### Recent Bills Management

The recent bills flow demonstrates the complete data cycle in Checkmate:

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│              │    │              │    │              │    │              │
│ Bill Summary │───>│ Database     │<───│ Recent Bills │───>│ Bill Details │
│ Screen       │    │ (SQLite)     │    │ Screen       │    │ Screen       │
│              │    │              │    │              │    │              │
└──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘
```

This demonstrates how:

1. Bill Summary saves completed bills to the database (limited to 30 most recent)
2. Recent Bills Screen retrieves and displays saved bills
3. Bill Details Screen allows viewing and sharing of past bills

## Privacy Architecture

A key architectural focus is ensuring zero cloud dependency while maintaining full functionality:

```
┌────────────────────────────────────────────────────────────────────┐
│                                                                    │
│                         User's Device                              │
│                                                                    │
│  ┌────────────────┐   ┌────────────────┐   ┌────────────────┐     │
│  │                │   │                │   │                │     │
│  │ App UI         │◄─►│ App Logic      │◄─►│ Local Storage │     │
│  │                │   │                │   │                │     │
│  └────────────────┘   └────────────────┘   └────────────────┘     │
│          ▲                                                         │
│          │                                                         │
└──────────┼─────────────────────────────────────────────────────────┘
           │
           │  Sharing Only (Optional)
           ▼
┌────────────────────────────────────────────────────────────────────┐
│                                                                    │
│                    External Systems                                │
│                                                                    │
│  ┌────────────────┐                                               │
│  │                │                                               │
│  │ Share Sheet    │  No persistent data stored externally         │
│  │ (Text Only)    │                                               │
│  │                │                                               │
│  └────────────────┘                                               │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

Key privacy features:

1. **No Account Requirements**: No login, registration, or user accounts
2. **No Cloud Storage**: All data stays on device
3. **No Contact Access**: Participants are entered manually, not pulled from contacts
4. **Minimal Permissions**: No unnecessary system access required
5. **Share Controls**: User-configurable sharing with only text data leaving the app

## Key Component Details

### 1. Database Schema

```
┌─────────────────┐       ┌─────────────────┐
│     People      │       │  RecentBills    │
├─────────────────┤       ├─────────────────┤
│ id              │       │ id              │
│ name            │       │ participants    │ 
│ colorValue      │       │ participantCount│
│ lastUsed        │       │ total           │
└─────────────────┘       │ date            │
                          │ subtotal        │
┌─────────────────┐       │ tax             │
│  TutorialStates │       │ tipAmount       │
├─────────────────┤       │ tipPercentage   │
│ id              │       │ items           │
│ tutorialKey     │       │ colorValue      │
│ hasBeenSeen     │       │ createdAt       │
│ lastShownDate   │       └─────────────────┘
└─────────────────┘
                          ┌─────────────────┐
                          │ UserPreferences │
                          ├─────────────────┤ 
                          │ id              │
                          │ includeItemsIn- │
                          │   Share         │
                          │ includePersonI- │
                          │   temsInShare   │
                          │ hideBreakdownI- │
                          │   nShare        │
                          │ updatedAt       │
                          └─────────────────┘
```

The database schema ensures:

- **Efficient Storage**: Only storing essential information
- **Privacy Protection**: No personally identifiable information beyond names entered by user
- **User Preference Persistence**: Remembers user's sharing preferences
- **Recent Usage Tracking**: Maintains list of recently used participants

### 2. Item Assignment Logic

The bill item assignment process follows this flow:

```
┌────────────────┐     ┌────────────────┐     ┌────────────────┐
│                │     │                │     │                │
│ Equal Split    │────>│ Custom Split   │────>│ Final          │
│ (Default)      │     │ (Optional)     │     │ Assignment     │
│                │     │                │     │                │
└────────────────┘     └────────────────┘     └────────────────┘
                                                      │
┌────────────────┐     ┌────────────────┐            │
│                │     │                │            │
│ Tax & Tip      │<────│ Assignment     │<───────────┘
│ Distribution   │     │ Validation     │
│                │     │                │
└────────────────┘     └────────────────┘
```

This ensures:
- **Flexible Splitting**: Items can be split evenly or with custom ratios
- **Proportional Distribution**: Tax and tip allocated based on item costs
- **Complete Assignment**: Validation ensures all items are fully assigned

### 3. UI Component Architecture

The UI components are organized in a hierarchical structure:

```
┌──────────────────────────────┐
│        Screen Container      │
├──────────────────────────────┤
│                              │
│  ┌────────────────────────┐  │
│  │     Section Cards      │  │
│  ├────────────────────────┤  │
│  │                        │  │
│  │  ┌──────────────────┐  │  │
│  │  │  Atomic Elements │  │  │
│  │  │  (Input, Avatar) │  │  │
│  │  └──────────────────┘  │  │
│  │                        │  │
│  └────────────────────────┘  │
│                              │
└──────────────────────────────┘
```

This pattern:
- **Promotes Reusability**: Common elements are abstracted into reusable widgets
- **Maintains Consistency**: Interface elements share common styling and behavior
- **Simplifies Testing**: Components can be tested in isolation
- **Enhances Readability**: Clear separation between UI sections

## Animation Architecture

Checkmate employs a structured approach to animations for enhanced user experience:

```
┌────────────────┐     ┌────────────────┐     ┌────────────────┐
│                │     │                │     │                │
│ Animation      │────>│ Tween          │────>│ Widget         │
│ Controllers    │     │ Animations     │     │ Builders       │
│                │     │                │     │                │
└────────────────┘     └────────────────┘     └────────────────┘
```

Key animation features:
- **Entrance/Exit Animations**: Smooth transitions between screens
- **Micro-interactions**: Subtle feedback for user actions
- **Loading States**: Animated indicators during data operations
- **Staggered Animations**: Sequenced entrance of UI elements

## Settings Flow Architecture

The settings system uses a layered approach for user preferences:

```
┌────────────────┐     ┌────────────────┐     ┌────────────────┐
│                │     │                │     │                │
│ Settings UI    │────>│ Settings       │────>│ SharedPrefs    │
│ Components     │     │ Manager        │     │ / SQLite       │
│                │     │                │     │                │
└────────────────┘     └────────────────┘     └────────────────┘
```

This ensures:
- **Centralized Settings Logic**: Settings manager acts as a façade for persistence
- **Consistent Storage**: Both simple preferences and complex data stored appropriately
- **UI Independence**: Settings UI doesn't need to know storage implementation

## Conclusion

Checkmate's architecture demonstrates how a privacy-first approach can be implemented without sacrificing functionality or user experience. The careful separation of concerns, modular design, and thoughtful data flow patterns ensure the application remains maintainable while adhering to core privacy principles.

The architecture balances several key considerations:
- **User Experience**: Smooth, intuitive interfaces with appropriate animations
- **Development Efficiency**: Reusable components and clear patterns
- **Data Privacy**: Zero cloud dependency with complete functionality
- **Maintainability**: Modular design with clear separation of concerns

This architectural approach allows Checkmate to stand out in the receipt-splitting landscape as a truly privacy-focused solution that doesn't compromise on features or usability.
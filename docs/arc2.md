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

```mermaid
flowchart TD
    subgraph "Presentation Layer"
        UI[UI Components]
        Screens[Screens]
        Widgets[Widgets]
        Dialogs[Dialogs]
        Animation[Animation Controllers]
        Theme[Theme Management]
        
        Screens --- UI
        Widgets --- UI
        Dialogs --- UI
        Animation --- UI
        Theme --- UI
    end
    
    subgraph "State Management Layer"
        Providers[Provider Definitions]
        Models[Model Classes]
        State[State Controllers]
        Logic[Calculation Logic]
        Utils[Utility Functions]
        Helpers[Helper Classes]
        
        Providers --- Models
        State --- Providers
        Logic --- Models
        Utils --- Logic
        Helpers --- Utils
    end
    
    subgraph "Data Layer"
        Database[Database Definition]
        Tables[Data Models/Tables]
        Access[Database Access Objects]
        ORM[Drift ORM Wrapper]
        SQLite[(SQLite Database)]
        
        Database --- Tables
        Access --- Database
        ORM --- Database
        ORM --- SQLite
    end
    
    UI <--> Providers
    Providers <--> Database
    
    classDef presentation fill:#FFB6C1,stroke:#333,stroke-width:2px
    classDef stateManagement fill:#98FB98,stroke:#333,stroke-width:2px
    classDef dataLayer fill:#6495ED,stroke:#333,stroke-width:2px
    
    class UI,Screens,Widgets,Dialogs,Animation,Theme presentation
    class Providers,Models,State,Logic,Utils,Helpers stateManagement
    class Database,Tables,Access,ORM,SQLite dataLayer
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

## User Flow and Screen Navigation

The diagram below illustrates the app's screen flow and user journey:

```mermaid
flowchart TD
    Splash[SplashScreen] --> |First Launch| Settings[SettingsScreen]
    Splash --> |Returning User| Landing[LandingScreen]
    
    Landing --> |Quick Split| Participants[ParticipantSelectionSheet]
    Landing --> |History| RecentBills[RecentBillsScreen]
    Landing --> |Settings| Settings
    
    Participants --> |Continue| BillEntry[BillEntryScreen]
    BillEntry --> |Continue| ItemAssignment[ItemAssignmentScreen]
    ItemAssignment --> |Continue| BillSummary[BillSummaryScreen]
    
    RecentBills --> |View Bill| BillDetails[BillDetailsScreen]
    BillSummary --> |Save| RecentBills
    
    BillSummary --> |Share| ShareSystem[System Share Sheet]
    BillDetails --> |Share| ShareSystem
    
    subgraph "Database Interactions"
        BillSummary -.-> |Save Bill| DB[(Local SQLite DB)]
        RecentBills -.-> |Load Bills| DB
        Participants -.-> |Load/Save Recent People| DB
        Settings -.-> |Save Preferences| DB
    end
    
    style Splash fill:#6495ED,stroke:#333,stroke-width:2px
    style Landing fill:#6495ED,stroke:#333,stroke-width:2px
    style RecentBills fill:#98FB98,stroke:#333,stroke-width:2px
    style BillDetails fill:#98FB98,stroke:#333,stroke-width:2px
    style Participants fill:#FFB6C1,stroke:#333,stroke-width:2px
    style BillEntry fill:#FFB6C1,stroke:#333,stroke-width:2px
    style ItemAssignment fill:#FFB6C1,stroke:#333,stroke-width:2px
    style BillSummary fill:#FFB6C1,stroke:#333,stroke-width:2px
    style Settings fill:#FFFACD,stroke:#333,stroke-width:2px
    style DB fill:#E6E6FA,stroke:#333,stroke-width:2px
    style ShareSystem fill:#D3D3D3,stroke:#333,stroke-width:2px
```

## Data Flow Patterns

### Unidirectional Data Flow

Checkmate implements a unidirectional data flow pattern as shown below:

```mermaid
flowchart TD
    subgraph "UI Layer"
        UI_Components[UI Components]
        Screens[Screens]
        BottomSheets[Bottom Sheets]
    end
    
    subgraph "State Management"
        Providers[Provider Models]
        ChangeNotifiers[ChangeNotifier Classes]
    end
    
    subgraph "Data Models"
        Person[Person Model]
        BillItem[Bill Item Model]
        BillData[Bill Data Model]
    end
    
    subgraph "Persistence"
        DB[Drift/SQLite Database]
        SharedPrefs[Shared Preferences]
    end
    
    UI_Components <-->|Widget events| Screens
    Screens <-->|Shows| BottomSheets
    
    Screens -->|Updates| Providers
    Providers -->|Notifies| Screens
    BottomSheets -->|Updates| Providers
    
    Providers -->|Manages| ChangeNotifiers
    ChangeNotifiers -->|Uses| Data Models
    
    Person <-->|Referenced by| BillItem
    BillItem <-->|Contained in| BillData
    
    Providers -->|Persists| DB
    DB -->|Loads| Providers
    Providers -->|Stores settings| SharedPrefs
    SharedPrefs -->|Loads settings| Providers
    
    style UI_Components fill:#FFB6C1,stroke:#333,stroke-width:2px
    style Screens fill:#FFB6C1,stroke:#333,stroke-width:2px
    style BottomSheets fill:#FFB6C1,stroke:#333,stroke-width:2px
    
    style Providers fill:#98FB98,stroke:#333,stroke-width:2px
    style ChangeNotifiers fill:#98FB98,stroke:#333,stroke-width:2px
    
    style Person fill:#FFFACD,stroke:#333,stroke-width:2px
    style BillItem fill:#FFFACD,stroke:#333,stroke-width:2px
    style BillData fill:#FFFACD,stroke:#333,stroke-width:2px
    
    style DB fill:#6495ED,stroke:#333,stroke-width:2px
    style SharedPrefs fill:#6495ED,stroke:#333,stroke-width:2px
```

This pattern ensures:

1. Models store the core business logic and data
2. Providers expose models to the UI and handle state changes
3. Widgets render UI based on provided state and dispatch actions
4. Actions update models, which update providers, which update widgets

### Recent Bills Management

The recent bills flow demonstrates the complete data cycle in Checkmate:

1. Bill Summary saves completed bills to the database (limited to 30 most recent)
2. Recent Bills Screen retrieves and displays saved bills
3. Bill Details Screen allows viewing and sharing of past bills

## Core Domain Model

The following UML diagram shows the relationships between key classes in Checkmate:

```mermaid
classDiagram
    class Person {
        +String name
        +Color color
        +bool operator==()
        +int hashCode
    }

    class BillItem {
        +String name
        +double price
        +Map~Person, double~ assignments
        +double amountForPerson(Person)
        +BillItem copyWith()
    }

    class AppDatabase {
        +int schemaVersion
        +Person peopleDataToPerson(PeopleData)
        +Future~List~Person~~ getRecentPeople()
        +Future~void~ addPersonToRecent(Person)
        +Future~void~ addPeopleToRecent(List~Person~)
        +Future~bool~ hasTutorialBeenSeen(String)
        +Future~void~ markTutorialAsSeen(String)
        +Future~ShareOptions~ getShareOptions()
        +Future~void~ saveShareOptions(ShareOptions)
        +Future~void~ saveBill()
        +Future~List~RecentBill~~ getRecentBills()
        +Future~void~ deleteBill(int)
        +Future~void~ clearAllBills()
    }

    class DatabaseProvider {
        -DatabaseProvider _instance
        +AppDatabase database
        +AppDatabase get db
        -DatabaseProvider _internal()
    }

    class ShareOptions {
        +bool includeItemsInShare
        +bool includePersonItemsInShare
        +bool hideBreakdownInShare
    }

    DatabaseProvider --* AppDatabase : contains
    BillItem --o Person : references
    AppDatabase ..> Person : creates
    AppDatabase ..> ShareOptions : manages
```

## Database Schema

The database schema consists of four main tables:

```mermaid
erDiagram
    People {
        int id PK
        string name
        int colorValue
        datetime lastUsed
    }
    
    TutorialStates {
        int id PK
        string tutorialKey UK
        boolean hasBeenSeen
        datetime lastShownDate
    }
    
    UserPreferences {
        int id PK
        boolean includeItemsInShare
        boolean includePersonItemsInShare
        boolean hideBreakdownInShare
        datetime updatedAt
    }
    
    RecentBills {
        int id PK
        string participants
        int participantCount
        real total
        string date
        real subtotal
        real tax
        real tipAmount
        real tipPercentage
        string items
        int colorValue
        datetime createdAt
    }
```

The database schema ensures:

- **Efficient Storage**: Only storing essential information
- **Privacy Protection**: No personally identifiable information beyond names entered by the user
- **User Preference Persistence**: Remembers user's sharing preferences
- **Recent Usage Tracking**: Maintains list of recently used participants

## Privacy Architecture

A key architectural focus is ensuring zero cloud dependency while maintaining full functionality:

```mermaid
flowchart TD
    subgraph "User Device"
        UI[User Interface]
        Logic[Business Logic]
        DB[(Local SQLite Database)]
        SharedPrefs[(SharedPreferences)]
        
        UI <--> Logic
        Logic <--> DB
        Logic <--> SharedPrefs
    end
    
    subgraph "External Systems"
        ShareSheet[System Share Sheet]
        User1[Friend's Device]
        User2[Friend's Device]
    end
    
    UI -->|Text-only Sharing| ShareSheet
    ShareSheet -->|Plain Text| User1
    ShareSheet -->|Plain Text| User2
    
    %% Show what doesn't happen - crossed out connections
    classDef noCloud stroke-dasharray: 5 5, stroke:#FF0000, stroke-width:2px
    
    NoCloud[(Cloud Storage)]:::noCloud
    NoAPI[External APIs]:::noCloud
    
    UI -.-x NoCloud
    UI -.-x NoAPI
    DB -.-x NoCloud
    Logic -.-x NoAPI
    
    %% Styling
    style UI fill:#FFB6C1,stroke:#333,stroke-width:2px
    style Logic fill:#98FB98,stroke:#333,stroke-width:2px
    style DB fill:#6495ED,stroke:#333,stroke-width:2px
    style SharedPrefs fill:#6495ED,stroke:#333,stroke-width:2px
    style ShareSheet fill:#FFFACD,stroke:#333,stroke-width:2px
    style User1 fill:#D3D3D3,stroke:#333,stroke-width:2px
    style User2 fill:#D3D3D3,stroke:#333,stroke-width:2px
    style NoCloud fill:#FFFFFF,stroke:#FF0000,stroke-width:2px
    style NoAPI fill:#FFFFFF,stroke:#FF0000,stroke-width:2px
```

Key privacy features:

1. **No Account Requirements**: No login, registration, or user accounts
2. **No Cloud Storage**: All data stays on device
3. **No Contact Access**: Participants are entered manually, not pulled from contacts
4. **Minimal Permissions**: No unnecessary system access required
5. **Share Controls**: User-configurable sharing with only text data leaving the app

## Component Hierarchy

The UI components for the bill splitting flow are organized in a hierarchical structure:

```mermaid
graph TD
    subgraph "Bill Splitting Flow"
        ParticipantSelection[Participant Selection] --> AddPersonField[Add Person Field]
        ParticipantSelection --> RecentPeopleSection[Recent People Section]
        ParticipantSelection --> CurrentParticipantsSection[Current Participants Section]
        
        BillEntry[Bill Entry] --> ParticipantAvatars[Participant Avatars]
        BillEntry --> BillTotalSection[Bill Total Section]
        BillEntry --> TipOptionsSection[Tip Options Section]
        BillEntry --> ItemsSection[Items Section]
        BillEntry --> BillSummarySection[Bill Summary Section]
        
        ItemAssignment[Item Assignment] --> UnassignedAmountBanner[Unassigned Amount Banner]
        ItemAssignment --> AssignmentAppBar[Assignment App Bar]
        ItemAssignment --> ItemCard[Item Card]
        ItemAssignment --> AssignmentBottomBar[Assignment Bottom Bar]
        ItemAssignment --> CustomSplitDialog[Custom Split Dialog]
        
        BillSummary[Bill Summary] --> BillTotalCard[Bill Total Card]
        BillSummary --> PersonCard[Person Card]
        BillSummary --> BottomBar[Bottom Bar]
        BillSummary --> ShareOptionsSheet[Share Options Sheet]
    end
    
    classDef screen fill:#FFB6C1,stroke:#333,stroke-width:2px
    classDef component fill:#98FB98,stroke:#333,stroke-width:2px
    
    class ParticipantSelection,BillEntry,ItemAssignment,BillSummary screen
    class AddPersonField,RecentPeopleSection,CurrentParticipantsSection,ParticipantAvatars,BillTotalSection,TipOptionsSection,ItemsSection,BillSummarySection,UnassignedAmountBanner,AssignmentAppBar,ItemCard,AssignmentBottomBar,CustomSplitDialog,BillTotalCard,PersonCard,BottomBar,ShareOptionsSheet component
```

This pattern:
- **Promotes Reusability**: Common elements are abstracted into reusable widgets
- **Maintains Consistency**: Interface elements share common styling and behavior
- **Simplifies Testing**: Components can be tested in isolation
- **Enhances Readability**: Clear separation between UI sections

## Animation Architecture

Checkmate employs a structured approach to animations for enhanced user experience:

- **Entrance/Exit Animations**: Smooth transitions between screens
- **Micro-interactions**: Subtle feedback for user actions
- **Loading States**: Animated indicators during data operations
- **Staggered Animations**: Sequenced entrance of UI elements

## Item Assignment Logic

The bill item assignment process follows this flow:

1. **Equal Split (Default)**: Items are initially assigned evenly among selected participants
2. **Custom Split (Optional)**: Users can specify custom percentages for divisions
3. **Final Assignment**: Assignments are validated to ensure 100% allocation
4. **Assignment Validation**: Ensures no items are left unassigned before proceeding
5. **Tax & Tip Distribution**: Tax and tip are allocated proportionally to item costs

This ensures:
- **Flexible Splitting**: Items can be split evenly or with custom ratios
- **Proportional Distribution**: Tax and tip allocated based on item costs
- **Complete Assignment**: Validation ensures all items are fully assigned

## Settings Flow Architecture

The settings system uses a layered approach for user preferences:

1. **Settings UI Components**: User-facing interface for configuration
2. **Settings Manager**: Mediates between UI and storage systems
3. **Storage (SharedPrefs/SQLite)**: Persists settings locally on device

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
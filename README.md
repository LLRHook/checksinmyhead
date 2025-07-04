# Spliq

**Privacy-first receipt splitting made simple**
- [Watch a Demo](https://youtube.com/shorts/T1GHR6JgOX8?feature=share)

## Documentation

### Core Documentation
- [Technical Overview](docs/technical-overview.md) - Architecture and key innovations
- [Market Analysis](docs/market-analysis.md) - Origin story and competitive landscape
- [Privacy: A Core Value](docs/privacy.md) - Privacy-first approach and implementation
- [User Experience](docs/user-experience.md) - Insights and lessons from building Spliq
- [Sample Data](docs/sample-data.md) - Real example of bill splitting in action
- [Scaling Considerations](docs/scaling-considerations.md) - Future architectural evolution

### Development
- [Contributing Guide](docs/contribution.md) - How to get involved in the project
- [Code of Conduct](docs/CODE_OF_CONDUCT.md) - Community guidelines

## Project Overview

Spliq is a Flutter-based iOS application designed for seamless receipt splitting without compromising user privacy. Our core value proposition is built around **zero data collection** - setting us apart from competitors that collect and store user data in the cloud.

### Key Features

- **Zero Data Collection**: No user data stored on any cloud service
- **No Permissions Required**: Works without accessing contacts or personal data
- **Intuitive UI**: Beautiful, seamless user experience
- **Flexible Splitting**: Supports custom split ratios (20/20/60, 10/10/10/70, etc.)
- **Local Storage**: Securely saves the last 30 bills on-device using SQLite
- **Customizable Receipts**: Configurable text receipts that can be shared instantly
- **Last Dined With**: Remembers the last 12 people you've dined with for quick selection

### User Flow

1. **Participant Selection**: Choose who's splitting the bill
2. **Item Entry**: Add items manually or via OCR (future integration)
3. **Item Assignment**: Assign items to participants
4. **Split Configuration**: Apply custom split ratios as needed
5. **Summary & Sharing**: View bill breakdown and share via messaging platforms
6. **History**: Access past bills stored locally on your device

## Technical Architecture

### Repository Structure

```
repo-root/
│
├── mobile/                # Flutter application
│   ├── lib/               # Main application code
│   ├── ios/               # iOS-specific code
│   ├── pubspec.yaml       # Flutter dependencies
│   └── README.md          # Development setup instructions
│
├── docs/                  # Project documentation
└── README.md              # Project overview
```

### Design Principles

#### 1. Privacy by Design

The cornerstone of Spliq is its privacy-first approach. Unlike competitors that collect user data for various purposes, Spliq operates entirely on-device:

- No cloud storage of personal information
- No user account requirements
- No contact access permissions
- No tracking or analytics that identify users

#### 2. Frontend-Only Architecture

The application is built as a standalone frontend solution:

- Flutter framework for the core application
- Local SQLite database for bill history storage
- Future OCR integration planned via Google Vision API (using the `google_vision` package)

#### 3. Cross-Platform Support

While currently focused on iOS deployment:

- Built with Flutter to enable future cross-platform compatibility
- Codebase structured to support Android with minimal modifications
- Open-source approach allows forking for other platform adaptations

#### 4. Modular Codebase

The project follows best practices for maintainability and extensibility:

- Separation of concerns through modular architecture
- Clean interfaces between system components
- Comprehensive testing framework
- Consistent code style and documentation

## Development Setup

To set up the development environment and run the project locally:

1. Clone the repository
2. Follow the detailed instructions in [mobile/README.md](mobile/README.md)
3. Use Flutter commands to build and run the application

## Future Roadmap

- OCR Integration: Add receipt scanning via Google Vision API
- Enhanced Splitting Logic: Support more complex division scenarios
- Dining Groups: Save frequently used groups of people for quick selection
- UI Refinements: Ongoing improvements to user experience
- Android Release: Expansion to additional platforms

## Contributing

Spliq is open-source and welcomes contributions. See our [contribution guidelines](docs/contribution.md) for more information on how to get involved.

## License

This project is licensed under GNU GPL - see the [LICENSE](LICENSE) file for details.
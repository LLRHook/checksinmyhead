# ChecksInMyHead Setup

## Project Overview

ChecksInMyHead is a Flutter-based application designed for smart receipt splitting. The project focuses on providing a seamless user experience for managing expenses and splitting bills among participants.

### Development Architecture

The project is structured as follows:

```
repo-root/
│
├── frontend/ # Flutter application
│ ├── lib/ # Main application code
│ ├── ios/ # iOS-specific code
│ ├── android/ # Android-specific code
│ ├── pubspec.yaml # Flutter dependencies
│ └── README.md # Frontend setup instructions
│
├── docs/ # Diagrams and architecture notes
├── sample-data/receipts/ # Example receipts for testing
├── tests/ # Unit tests for the application
├── .pre-commit-config.yaml # Pre-commit hooks configuration
└── README.md # This file
```

### Design Decisions

1. **Frontend-Only Architecture**:  
   The project is now entirely frontend-focused, leveraging Flutter for cross-platform development. Backend functionality (e.g., OCR, parsing) can be integrated via APIs or third-party services in the future.

2. **Cross-Platform Support**:  
   The Flutter framework ensures compatibility with both iOS and Android devices, providing a consistent user experience across platforms.

3. **Modular Codebase**:  
   The `lib/` directory in the frontend contains modularized code for screens, widgets, and utilities, making it easier to maintain and extend.

4. **Pre-commit Hooks**:  
   Pre-commit hooks are configured to enforce code quality and consistency across the project.

## Setup Instructions

To set up the project, follow the instructions in the [frontend/README.md](frontend/README.md).
# The Genesis of Checkmate

## Origin Story

Checkmate was born from a real-world problem encountered during a group trip to Utah. Our team of seven friends chose to simplify restaurant experiences by having one person pay the entire bill—reducing confusion for restaurant staff and streamlining the dining experience (until, ironically, our designated payer forgot his card at a restaurant).

Throughout the trip, we accumulated numerous receipts that needed reconciliation. We believed that tax and tip should be split proportionally based on what each person ordered, so our "bill master" would diligently calculate everyone's share each evening using Excel. After full days of hiking 20+ miles, managing three meals' worth of receipts became an increasingly tedious task.

This pain point sparked a realization: we could apply our computer science expertise to solve this common problem. The core mission became clear—eliminate repetitive manual calculations through an elegant algorithmic approach wrapped in an intuitive interface. Before diving into development, we conducted market research to understand existing solutions.

## Competitive Landscape Analysis

Our App Store research revealed two primary competitors in the receipt-splitting space:

### Tab: "The Simple Bill Splitter"

**Core Functionality:**
- OCR technology for receipt scanning (server-side processing)
- Item claiming via tap interface
- Real-time collaboration allowing users to join bills on separate devices
- Proportional tax and tip allocation
- Special "birthday mode" feature

**Key Limitations:**
1. **Privacy Concerns:** Collects extensive user data including usage patterns, contact information, device identifiers, and diagnostic data
2. **Account Requirement:** Saved bills functionality locked behind mandatory user accounts
3. **Limited OCR Flexibility:** No ability to edit items if OCR misinterprets the receipt
4. **Dated User Experience:** Interface feels cluttered and lacks modern design principles

### Plates by Splitwise

**Core Functionality:**
- Color-coded plate system for up to 10 participants
- Item assignment with custom ratio splitting options
- Tax entry and tip selection via slider (0-30%)
- Final cost calculation per participant

**Key Limitations:**
1. **Usability Issues:** Color-coded system becomes confusing with larger groups
2. **Arbitrary Limitations:** 10-person maximum seems unnecessarily restrictive
3. **Inflexible Tipping:** No custom tip amount option beyond percentage slider
4. **Unintuitive Item Splitting:** "Break and drag" operation creates confusion
5. **No Historical Record:** Lacks bill history and sharing capabilities
6. **No Longer Supported:** Last update 2 years ago to support iPhone X

## Market Opportunity

Through analyzing these competitors, we identified several opportunities for Checkmate to excel:

**Privacy-First Approach:**
- Eliminate unnecessary data collection
- Function without cloud storage or user accounts
- Provide full utility with zero privacy compromises

**Enhanced User Experience:**
- Create a modern, intuitive interface with visual feedback and microinteractions
- Implement flexible naming instead of color-coding
- Remove arbitrary limitations on group size

**Technical Improvements:**
- Offer manual override options for item entry
- Create intuitive splitting mechanisms
- Provide flexible tip and tax handling options
- Store recent bills locally for reference

**Quality-of-Life Features:**
- Easy sharing of final calculations
- Remembering frequent dining companions
- Clean visualization of who ordered what
- Support for special scenarios (birthdays, business meals, etc.)

Checkmate's vision emerged from this analysis: create a privacy-focused, intuitive receipt-splitting utility that addresses the shortcomings of existing solutions while introducing thoughtful innovations that enhance the user experience.
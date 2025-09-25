# Origin Story & Market Analysis

## Origin Story

Billington started with a real problem we faced during a group trip to Utah. Our group of seven friends decided to simplify restaurant visits by having just one person pay the entire bill—making things easier for restaurant staff and streamlining our dining experience.

Throughout the trip, we collected a stack of receipts that needed to be sorted out. We all agreed that tax and tip should be split proportionally based on what each person ordered, so our "bill master" would calculate everyone's share each evening using Excel. After full days of hiking 20+ miles, dealing with three meals' worth of receipts became increasingly tedious.

This frustration sparked an idea: we could use our computer science background to solve this common problem. Our mission became clear—eliminate those repetitive manual calculations with a smart algorithmic approach wrapped in an easy-to-use interface. Before starting development, we looked at what solutions already existed.

## Competitive Landscape Analysis

Our App Store research showed two main competitors in the receipt-splitting space:

### Tab: "The Simple Bill Splitter"

**Core Functionality:**
- OCR technology for scanning receipts (processed on their servers)
- Simple tap interface for claiming items
- Real-time collaboration so users can join bills on different devices
- Proportional tax and tip allocation
- Special "birthday mode" feature

**Key Limitations:**
1. **Privacy Issues:** Collects lots of user data including usage patterns, contact information, device IDs, and diagnostic data
2. **Forced Accounts:** You can't save bills without creating an account
3. **Inflexible OCR:** No way to edit items if the scanner misreads the receipt
4. **Outdated Experience:** Interface feels cluttered and doesn't follow modern design principles

**Key Issues:**
- Requires multiple permissions for full functionality
- Interface could be more modern

### Plates by Splitwise

**Core Functionality:**
- Color-coded plate system for up to 10 people
- Item assignment with custom ratio splitting options
- Tax entry and tip selection via slider (0-30%)
- Final cost calculation for each person

**Key Limitations:**
1. **Usability Problems:** The color-coded system gets confusing with larger groups
2. **Arbitrary Limits:** 10-person maximum seems unnecessary
3. **Restrictive Tipping:** No option for custom tip amounts beyond the percentage slider
4. **Confusing Item Splitting:** The "break and drag" operation isn't intuitive
5. **No History:** Doesn't save past bills or offer sharing options
6. **Abandoned App:** Last updated 2 years ago just to support iPhone X

**Technical Issues:**
- Not optimized for newer iOS features
- Some deprecated API usage

## Market Opportunity

By analyzing these competitors, we saw several opportunities for Billington to do better:

**Privacy-First Approach:**
- Skip unnecessary data collection
- Work without cloud storage or user accounts
- Provide full functionality with zero privacy compromises

**Better User Experience:**
- Create a modern, intuitive interface with visual feedback
- Use flexible naming instead of confusing color-codes
- Remove arbitrary limits on group size

**Technical Improvements:**
- Offer manual override options when entering items
- Create intuitive splitting mechanisms
- Provide flexible tip and tax handling
- Store recent bills locally for reference

**Quality-of-Life Features:**
- Easy sharing of final calculations
- Remember frequent dining companions
- Clearly show who ordered what
- Support special scenarios (birthdays, business meals, etc.)

## Engineering Approach

From a technical standpoint, we identified several areas where we could excel:

**Performance Goals:**
- Fast startup time
- Smooth animations
- Minimal memory usage
- Zero network dependency for core functionality

**Algorithm Approach:**
- O(n*m) complexity for bill splitting calculations
- Proper percentage calculations to avoid floating-point errors
- Fair rounding algorithm to ensure cents add up correctly

**Architecture Benefits:**
- Pure frontend solution eliminates server costs
- Local-only data means no privacy concerns
- Modular design allows rapid feature development
- Flutter framework enables future cross-platform support

Billington's vision came from this analysis: create a privacy-focused, intuitive receipt-splitting tool that fixes the problems with existing solutions while introducing thoughtful innovations that make the experience better for everyone. The combination of technical excellence and user-centered design would set us apart in a market ready for disruption.
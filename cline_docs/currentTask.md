# Current Task

## Objective
- Refactor `OpenCone/Features/Documents/DocumentsView.swift` and `OpenCone/Features/Documents/DocumentDetailsView.swift` to eliminate redundant helper functions for displaying document information (icon, color, file size).

## Context
- Both `DocumentsView.swift` (within its `DocumentRow` sub-view) and `DocumentDetailsView.swift` contained duplicated private helper functions (`iconForDocument`, `colorForDocument`, `formattedFileSize`).
- This redundancy made the code harder to maintain and less consistent.

## Changes Implemented
- Created `OpenCone/Features/Documents/DocumentModel+ViewHelpers.swift` containing an extension on `DocumentModel`.
- Added computed properties (`viewIconName`, `viewIconColor`, `formattedFileSize`) to the `DocumentModel` extension to provide view-specific display logic.
- Refactored `DocumentsView.swift` (specifically `DocumentRow`) to remove the duplicated helper functions and use the new extension properties.
- Refactored `DocumentDetailsView.swift` to remove the duplicated helper functions and use the new extension properties.
- Resolved potential build issues related to target membership for the new and modified files.

## Next Steps
- **Update Codebase Summary:** Update `codebaseSummary.md` to mention the new `DocumentModel+ViewHelpers.swift` file and the refactoring of the document views.
- **Testing:** Build and run the application in Xcode to ensure the Documents feature (both the list and detail views) still displays correctly after the refactoring.

# Add DocumentModel+ViewHelpers.swift to Target

The new file `DocumentModel+ViewHelpers.swift` needs to be included in the main application target for the code to compile correctly.

**Steps:**

1.  Open the `OpenCone.xcodeproj` project in Xcode.
2.  In the Project Navigator (left sidebar), find the `OpenCone/Features/Documents` group.
3.  Select the newly added file: `DocumentModel+ViewHelpers.swift`.
4.  Open the Inspectors panel on the right side of the Xcode window (if it's hidden, click the top-right button that looks like a square with a line down the middle, or press Option+Command+0).
5.  In the Inspectors panel, select the "File Inspector" tab (the first icon, looks like a document).
6.  Look for the "Target Membership" section.
7.  Ensure the checkbox next to the "OpenCone" target (the one with the app icon) is **checked**. If it's unchecked, check it.
8.  Try building the project again in Xcode (Cmd+B). The "Cannot find type 'DocumentModel'" error should be resolved.

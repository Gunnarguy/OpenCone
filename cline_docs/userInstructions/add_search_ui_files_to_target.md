# Add Search UI files to Xcode Target

Follow these steps to ensure newly added Search UI files are included in your app target. If files are not in the target, the project may fail to build or new UI won’t appear.

1) Open the Xcode project
   - Double click OpenCone/OpenCone.xcodeproj
   - Or from terminal: open OpenCone/OpenCone.xcodeproj

2) Locate the new files in the Project Navigator
   - OpenCone/Features/Search/Models/ChatModels.swift
   - OpenCone/Features/Search/Components/TypingBubble.swift

3) Verify Target Membership
   - Click each file in the navigator
   - Open the File Inspector (⌥⌘1 or View > Inspectors > File Inspector)
   - In the “Target Membership” section, ensure the checkbox next to the app target (e.g., “OpenCone”) is checked
   - If unchecked, check it to add the file to the build

4) Clean and Build
   - Product > Clean Build Folder… (hold Option key) → Clean
   - Product > Build (⌘B)
   - Fix any missing imports by ensuring the files are in the same module (they are under the OpenCone target)

5) Run
   - Select your scheme (iOS Simulator or macOS App)
   - Run (⌘R)

Troubleshooting
- If you see “Cannot find type ChatMessage” or similar:
  - Ensure ChatModels.swift is in the same target
  - Clean build folder and re-build
- If TypingBubble isn’t rendering:
  - Ensure TypingBubble.swift is in the app target
  - Confirm ChatBubble conditionally renders TypingBubble when message.status == .streaming and text.isEmpty
- If Stop button is not visible:
  - Make sure you are streaming (isSending true)
  - Confirm SearchView passes onStop to ChatInputBar:
    ChatInputBar(..., onStop: { viewModel.cancelActiveSearch() })

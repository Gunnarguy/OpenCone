# Contributing to OpenCone

This guide outlines our development workflow, coding standards, branch conventions, and testing expectations. Whether you are an engineer or an autonomous coding agent, please follow these guidelines to keep the codebase clean and secure.

---

## 1. Project Status

OpenCone is a portfolio-grade iOS/AI demonstration app showcasing on-device RAG. While we welcome community contributions, our priority is maintaining consistency in architecture patterns, security boundaries, and logging practices.

---

## 2. Development Prerequisites

To compile and contribute to OpenCone, your workstation must have:
- **Operating System**: macOS Sonoma (14.0+) or Sequoia (15.0+)
- **IDE**: Xcode 16.0 or newer
- **Languages**: Swift 5.10+
- **Runtimes**: Python 3.x (required to execute the local secret scanner)
- **Dependencies**: All packages are integrated via Swift Package Manager.

---

## 3. Local Workspace Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/Gunnarguy/OpenCone.git
   cd OpenCone
   ```
2. **Open the project**:
   ```bash
   open OpenCone.xcodeproj
   ```
3. **Configure Environment Variables**:
   In Xcode, open the Scheme editor (**Product > Scheme > Edit Scheme...**). Under **Run > Arguments > Environment Variables**, you may add temporary keys (`OPENAI_API_KEY`, `PINECONE_API_KEY`, `PINECONE_PROJECT_ID`) for local debugging. These keys are blocked from shipping in Release configurations by a runtime check.

---

## 4. Branch Workflow & Git Conventions

- **Main Branch**: All active releases and validated code reside on `main`.
- **Feature Branches**: Make edits inside branches named `feature/description` or `fix/description`.
- **Commit Style**: Use descriptive imperative titles:
  ```
  feat: Add circuit breaker status indicators to SearchView
  fix: Resolve memory leak in Vision OCR extraction loops
  docs: Update security guidelines with Keychain details
  ```

---

## 5. Coding Conventions

- **MVVM-S Architecture**: Never call service API integrations directly from SwiftUI views. Views observe ViewModels, and ViewModels route actions to Services.
- **Swift Concurrency**: Dispatch complex processing tasks (text extraction, network HTTP connections) onto background threads. UI mutations must run on the main thread (utilizing `@MainActor` or `await MainActor.run { ... }`).
- **No Bundle Secrets**: Never check hardcoded API keys or sensitive placeholders into source files. Route all secure storage to `SecureSettingsStore`.
- **Structured Logging**: Use `Logger.shared.log(level:message:context:)` for all diagnostics. Never use print statements (`print()`) in production-ready files.

---

## 6. Testing & Quality Assurance

All contributions must pass automated tests:
1. **Unit Tests**: Run tests via Xcode (**Cmd+U**) or using:
   ```bash
   xcodebuild test -project OpenCone.xcodeproj -scheme OpenCone -destination "platform=iOS Simulator,name=iPhone 16" -quiet
   ```
2. **Preflight Script**: Ensure the local validation script returns success before submitting pull requests:
   ```bash
   scripts/preflight_check.sh
   ```

---

## 7. AI-Agent Contribution Rules

When contributing as an AI agent or copilot sub-agent:
- **Directives First**: Always review [ROADMAP.md](ROADMAP.md) and [ARCHITECTURE.md](ARCHITECTURE.md) before making edits.
- **Zero Markdown Sprawl**: Do not create temporary design files (like `plan.md` or `notes.md`) inside the repository directories. Document decisions in code comments or update existing documents directly.
- **Verification**: Run `scripts/preflight_check.sh` and update the task checkboxes in `ROADMAP.md` immediately upon completing your task.

---

## 8. Pull Request Checklist

When submitting a Pull Request, verify:
- [ ] Code compiles with zero warnings or errors.
- [ ] `scripts/preflight_check.sh` runs successfully.
- [ ] No secret patterns are detected by `secret_scan.py`.
- [ ] All new ViewModels and Services are properly documented.
- [ ] Changes to Settings or Metadata filters include matching unit tests in `OpenConeTests`.

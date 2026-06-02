# Folder Tree Expand/Collapse Reactivity Fix — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix expand/collapse functionality in the sidebar folder tree by making `FolderTreeNode` observable, so SwiftUI re-renders when state changes.

**Architecture:** Two minimal changes: (1) Make `FolderTreeNode` an `@MainActor @ObservableObject` with `@Published var isExpanded`, (2) Change `FolderTreeItemView` to use `@ObservedObject` instead of `let` for the node. No logic changes—the toggle/expand/collapse methods already work, they just weren't triggering UI updates.

**Tech Stack:** SwiftUI, Swift concurrency (@MainActor), ObservableObject pattern

---

## File Structure

**Files to modify:**
- `Sources/MacDown/Models/FolderTreeNode.swift` — Add @MainActor, ObservableObject, @Published annotation
- `Sources/MacDown/Views/FolderTreeItemView.swift` — Change property from `let node` to `@ObservedObject var node`

**Files to verify (no changes needed):**
- `Sources/MacDown/Models/FolderManager.swift` — Logic unchanged
- `Tests/MacDownTests/Models/FolderManagerTests.swift` — Tests pass unchanged

---

## Tasks

### Task 1: Make FolderTreeNode Observable

**Files:**
- Modify: `Sources/MacDown/Models/FolderTreeNode.swift`

- [ ] **Step 1: Open FolderTreeNode.swift**

```bash
cd /home/devcontainer/GitHub/macdown
cat Sources/MacDown/Models/FolderTreeNode.swift
```

Current state: Regular class with `var isExpanded: Bool = false`

- [ ] **Step 2: Add @MainActor and conform to ObservableObject**

Edit the class declaration from:
```swift
final class FolderTreeNode: Identifiable {
```

To:
```swift
@MainActor
final class FolderTreeNode: Identifiable, ObservableObject {
```

- [ ] **Step 3: Mark isExpanded as @Published**

Edit the property from:
```swift
var isExpanded: Bool = false
```

To:
```swift
@Published var isExpanded: Bool = false
```

**Full file should look like:**
```swift
import Foundation

@MainActor
final class FolderTreeNode: Identifiable, ObservableObject {
    let id: UUID = UUID()
    let name: String
    let url: URL
    let isFolder: Bool
    var children: [FolderTreeNode] = []
    @Published var isExpanded: Bool = false
    let parentFolderPath: String

    init(
        name: String,
        url: URL,
        isFolder: Bool,
        parentFolderPath: String
    ) {
        self.name = name
        self.url = url
        self.isFolder = isFolder
        self.parentFolderPath = parentFolderPath
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add Sources/MacDown/Models/FolderTreeNode.swift
git commit -m "feat: make FolderTreeNode observable for SwiftUI reactivity

Add @MainActor and ObservableObject conformance to FolderTreeNode.
Mark isExpanded as @Published so SwiftUI observes state changes.
This enables expand/collapse chevron and Expand/Collapse All buttons
to properly update the UI.

Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>"
```

---

### Task 2: Update FolderTreeItemView to Observe Node

**Files:**
- Modify: `Sources/MacDown/Views/FolderTreeItemView.swift`

- [ ] **Step 1: Open FolderTreeItemView.swift**

```bash
cat Sources/MacDown/Views/FolderTreeItemView.swift
```

Current state: Uses `let node: FolderTreeNode`

- [ ] **Step 2: Change node property to use @ObservedObject**

Edit the property declaration from:
```swift
let node: FolderTreeNode
```

To:
```swift
@ObservedObject var node: FolderTreeNode
```

**The struct properties should now be:**
```swift
struct FolderTreeItemView: View {
    @ObservedObject var node: FolderTreeNode
    @EnvironmentObject var folderManager: FolderManager
    @EnvironmentObject var store: DocumentStore
```

**All other code in the file remains unchanged.** The view body, folderRow, fileRow, and helper functions stay the same.

- [ ] **Step 3: Verify file compiles**

```bash
swift build 2>&1 | head -50
```

Expected: No errors related to FolderTreeItemView

- [ ] **Step 4: Commit**

```bash
git add Sources/MacDown/Views/FolderTreeItemView.swift
git commit -m "feat: observe FolderTreeNode changes in FolderTreeItemView

Change node property from 'let' to '@ObservedObject var' so the view
subscribes to isExpanded changes. This makes the chevron update and
children show/hide when expand/collapse is triggered.

Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>"
```

---

### Task 3: Run Existing Tests

**Files:**
- Test: `Tests/MacDownTests/Models/FolderManagerTests.swift` (no changes)

- [ ] **Step 1: Run FolderManager tests**

```bash
swift test FolderManagerTests 2>&1
```

Expected output: All 5 tests pass
- `testImportFolderNoDuplicates` ✓
- `testRemoveFolder` ✓
- `testClear` ✓
- `testToggleFolderExpansion` ✓
- (any others defined)

If any test fails, it indicates a problem with the changes. Since we only changed @Published and observability, the logic is untouched and tests should pass.

- [ ] **Step 2: Run all tests to ensure no regressions**

```bash
swift test 2>&1
```

Expected: All tests pass (no new failures introduced)

---

### Task 4: Manual Verification

**Manual testing — no code changes, just verification of behavior**

- [ ] **Step 1: Start the app**

```bash
cd /home/devcontainer/GitHub/macdown
swift run MacDown &
```

Wait for the app window to appear.

- [ ] **Step 2: Import a test folder with nested structure**

Use the File menu or drag-drop to import a folder with:
- A root folder (e.g., `Documents/TestFolder`)
- At least one subfolder (e.g., `TestFolder/src`)
- At least one file in root (e.g., `TestFolder/README.md`)
- At least one file in subfolder (e.g., `TestFolder/src/main.md`)

- [ ] **Step 3: Verify chevron toggles on click**

**Test:** Click the chevron (▶) next to a subfolder
- **Expected:** Chevron rotates to ▼, folder children appear
- **Test:** Click the chevron again (▼)
- **Expected:** Chevron rotates back to ▶, children disappear
- **Repeat:** Test at least 2 different subfolders to ensure it works at multiple levels

- [ ] **Step 4: Verify root folder can collapse**

**Test:** Click the chevron (▼) next to the root folder
- **Expected:** Chevron changes to ▶, all children disappear
- **Test:** Click it again
- **Expected:** Chevron changes back to ▼, children reappear

- [ ] **Step 5: Verify Expand All button**

**Test:** Click "Expandir tudo" button in FoldersSection
- **Expected:** All chevrons become ▼, all folders open, all files visible

- [ ] **Step 6: Verify Collapse All button**

**Test:** Click "Contrair tudo" button in FoldersSection
- **Expected:** All chevrons become ▶ (except root stays ▼), subfolders collapse

- [ ] **Step 7: Kill app and document results**

```bash
killall MacDown
```

If all 6 verification steps pass, the fix is complete and working.

---

## Summary

**Total changes:** 2 files, ~3 lines added/modified each
**Complexity:** Low (property attributes only, no logic changes)
**Testing:** Existing tests pass unchanged + manual UI verification
**Risk:** Minimal (isolated to data model + one view)

**Verification checklist:**
- ✓ FolderTreeNode compiles with @MainActor @ObservableObject
- ✓ FolderTreeItemView compiles with @ObservedObject
- ✓ All existing FolderManagerTests pass
- ✓ Manual: Chevron toggles on single and nested folders
- ✓ Manual: Root folder can collapse/expand
- ✓ Manual: Expand All / Collapse All buttons work

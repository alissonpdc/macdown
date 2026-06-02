# Folder Tree Expand/Collapse Reactivity Fix

**Date:** 2026-06-02  
**Feature:** 4.1 - Pasta expandível/retrátil com navegação por árvore  
**Status:** Design approved, ready for implementation

---

## Problem Statement

The folder tree in the sidebar displays but expand/collapse functionality is broken:

1. **Chevron doesn't change state** — clicking a chevron (▶ or ▼) doesn't toggle the icon
2. **Children don't show/hide** — expanding a folder doesn't reveal its contents
3. **Expand/Collapse All buttons don't work** — the FoldersSection buttons have no effect
4. **Root folder can't be collapsed** — the root shows ▼ but clicking doesn't collapse it

### Root Cause

`FolderTreeNode` is a regular class that mutates its `isExpanded` property, but **SwiftUI is not notified of the change** because:
- `FolderTreeNode` does not conform to `ObservableObject`
- `isExpanded` is not marked `@Published`
- Changes to `isExpanded` don't trigger view re-renders

The logic in `FolderManager` (toggle, expand all, collapse all) works correctly—tests pass. The problem is purely reactivity between the data model and the UI layer.

---

## Solution: Make FolderTreeNode Observable

Convert `FolderTreeNode` to an `@MainActor` `ObservableObject` so SwiftUI observes changes to `isExpanded`.

### Changes Required

#### 1. FolderTreeNode.swift

**Before:**
```swift
final class FolderTreeNode: Identifiable {
    let id: UUID = UUID()
    let name: String
    let url: URL
    let isFolder: Bool
    var children: [FolderTreeNode] = []
    var isExpanded: Bool = false
    let parentFolderPath: String
    // ... init ...
}
```

**After:**
```swift
@MainActor
final class FolderTreeNode: Identifiable, ObservableObject {
    let id: UUID = UUID()
    let name: String
    let url: URL
    let isFolder: Bool
    var children: [FolderTreeNode] = []
    @Published var isExpanded: Bool = false
    let parentFolderPath: String
    // ... init ...
}
```

**Rationale:**
- `@MainActor` ensures all mutations happen on the main thread (SwiftUI requirement)
- `ObservableObject` lets SwiftUI observe property changes
- `@Published var isExpanded` triggers view updates when toggled

#### 2. FolderTreeItemView.swift

**Before:**
```swift
struct FolderTreeItemView: View {
    let node: FolderTreeNode
    @EnvironmentObject var folderManager: FolderManager
    @EnvironmentObject var store: DocumentStore
    // ... rest of view ...
}
```

**After:**
```swift
struct FolderTreeItemView: View {
    @ObservedObject var node: FolderTreeNode
    @EnvironmentObject var folderManager: FolderManager
    @EnvironmentObject var store: DocumentStore
    // ... rest of view ...
}
```

**Rationale:**
- `@ObservedObject` makes the view subscribe to the node's `@Published` changes
- Ensures the view re-renders when `isExpanded` changes
- Existing tap gesture and rendering logic requires no changes

#### 3. FolderManager.swift

**No changes required.**

The existing methods (`toggleFolderExpansion`, `expandAll`, `collapseAll`, etc.) already mutate `node.isExpanded` correctly. With `@Published`, these mutations now automatically trigger view updates.

#### 4. Tests

**No changes required.**

All existing tests in `FolderManagerTests.swift` pass and will continue to pass. The tests verify the toggle/expand/collapse logic, which is unchanged.

---

## Expected Behavior After Fix

### Expand/Collapse chevron
- **Single click on folder row** → toggles between ▶ and ▼
- **Folder children appear/disappear** as the chevron changes
- **Applies to all folders** (root, nested, any level)

### Expand/Collapse All buttons
- **"Expandir tudo" button** → all folders open (all chevrons show ▼)
- **"Contrair tudo" button** → all folders close except root (all chevrons show ▶, except root shows ▼)
- **Updates persist** until user toggles individual folders

### Visual hierarchy
- **Root folder icon** — shows 📁 with chevron ▼/▶
- **Child folders** — indented 24px, show 📁 with chevron ▼/▶
- **Files** — indented, show 📄, parent path shown only for root-level items
- **Indentation stacks** — each nesting level adds 24px indent

---

## Files to Modify

1. `Sources/MacDown/Models/FolderTreeNode.swift` — Add @MainActor, ObservableObject, @Published
2. `Sources/MacDown/Views/FolderTreeItemView.swift` — Change `let node` to `@ObservedObject var node`

---

## Testing Strategy

### Manual Testing
- Import a folder with nested subfolders
- Click chevron on root → should collapse, children disappear
- Click chevron on root again → should expand, children reappear
- Click chevron on child folder → should toggle independently
- Click "Expandir tudo" → all folders expand
- Click "Contrair tudo" → all folders collapse (except root stays open)

### Automated Testing
- Existing `FolderManagerTests.swift` tests pass unchanged
- No new tests needed (logic unchanged, only reactivity fixed)

---

## Risk Assessment

**Low risk.**

- Changes are isolated to the data model and one view
- No changes to FolderManager logic
- All existing tests pass
- Backward compatible — @MainActor @ObservableObject is a standard SwiftUI pattern

---

## Deliverables

1. Updated `FolderTreeNode.swift` with @MainActor, ObservableObject, @Published
2. Updated `FolderTreeItemView.swift` with @ObservedObject
3. Verification: manual test of expand/collapse at all nesting levels
4. Verification: "Expandir tudo" / "Contrair tudo" buttons work

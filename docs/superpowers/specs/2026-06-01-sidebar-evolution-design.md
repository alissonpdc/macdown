# Design Spec: Sidebar Evolution — Recentes & Folders Management

**Date:** 2026-06-01  
**Feature:** Enhanced file and folder management in MacDown sidebar  
**Status:** Approved

---

## Overview

Evolve the MacDown sidebar from a simple list of open documents to a two-section workspace manager:
1. **Recentes** — Files opened in the current session
2. **Folders** — Imported folder hierarchies with markdown file discovery

Both sections are draggable/resizable within the sidebar. Session-scoped (cleared on app quit). Integrates with Mac menu for folder operations.

---

## Requirements

### Sidebar Structure

- **Split Layout:** Two vertically stacked sections with a draggable divider
- **Recentes Section (top):** Displays files opened in the current session
- **Folders Section (bottom):** Displays imported folders in hierarchical tree view
- **Resizable Divider:** Users can drag to adjust section heights; divider state persists for the session

### Recentes Section

- **Content:** List of markdown files opened in the current session
- **Behavior:**
  - Single click → opens file in current tab (activates if already open)
  - Double click → opens file in new tab
- **Lifecycle:** Clears completely when app closes (command+q)
- **Growth:** List grows as user opens files during the session

### Folders Section

- **Content:** Imported folders with recursive discovery of `.md` and `.markdown` files
- **Hierarchy Display:**
  - Files and folders shown in tree structure (IDE-style)
  - Folders are collapsible/expandable with disclosure triangles
  - **Initial state on import:** Expanded to first level only (first folder level is expanded, nested folders are collapsed)
  - File display format: `filename.md [/path/to/folder]` (filename in normal text, folder path in faded/secondary color and brackets)
  
- **Controls:**
  - **Expand All button:** Expands all folders in the tree
  - **Collapse All button:** Collapses all folders (shows only root folders)
  - **Filter bar:** Search/filter files by name in real-time
    - While filtering, automatically expand parent folders of matching files
    - Clearing filter restores previous expansion state
  
- **File Interaction:**
  - Single click → opens in current tab
  - Double click → opens in new tab
  - Same behavior as Recentes
  
- **Folder Removal:**
  - Delete button (×) next to folder name, or right-click → "Remover pasta" context menu
  - Removes folder from Folders section
  - Files from that folder are removed from Recentes if they're there
  
- **Deduplication:** If user attempts to add a folder that's already imported, silently ignore (no error message)
- **Lifecycle:** Clears completely when app closes (command+q)

### Mac Menu Integration

Add two menu items to the main MacDown menu (File menu suggested):

1. **"Adicionar pasta ao Workspace"**
   - Opens folder picker dialog
   - Imports selected folder into current window's Folders section
   - If folder already exists, silently ignores
   - Can add multiple different folders to same workspace
   - Folders persist for the session

2. **"Abrir pasta"**
   - Opens folder picker dialog
   - Launches a NEW MacDown window with only that folder imported
   - New window has empty Recentes (new session)
   - New window operates independently from others

---

## Data Model

### RecentsManager

Tracks files opened in the current session.

**Properties:**
- `recents: [(url: URL, title: String)]` — ordered list of opened files

**Methods:**
- `addRecent(_ url: URL, title: String)` — adds file to recents (called when DocumentStore.open() is called)
- `clear()` — clears all recents (called on app quit)

**Behavior:**
- Does not persist to disk
- Order is chronological (oldest first, newest last)

### FolderManager

Manages imported folders and folder tree state.

**Properties:**
- `importedFolders: [URL]` — deduplicated list of folder URLs
- `folderTrees: [FolderTreeNode]` — root nodes of each imported folder
- `filterText: String` — current filter query
- `expandedNodeIDs: Set<UUID>` — tracks which nodes are expanded (for restoring state after filtering)

**Methods:**
- `importFolder(_ url: URL) throws` — adds folder to importedFolders, builds tree, expands to first level
- `removeFolder(_ url: URL)` — removes folder and its tree
- `toggleFolderExpansion(_ nodeID: UUID)` — toggle expanded state of a folder node
- `expandAll()` — expands all folders in all trees
- `collapseAll()` — collapses all folders except root
- `setFilter(_ text: String)` — updates filter, auto-expands parent folders of matches
- `clearFilter()` — clears filter, restores previous expansion state
- `clear()` — clears all folders (called on app quit)

**Deduplication Logic:**
- `importFolder()` checks if folder URL already exists in `importedFolders`
- If yes, returns silently without modification

### FolderTreeNode

Represents a node in the folder hierarchy (file or folder).

**Properties:**
- `id: UUID` — unique identifier
- `name: String` — filename or folder name (display name)
- `url: URL` — full file system path
- `isFolder: Bool` — true if folder, false if file
- `children: [FolderTreeNode]` — child nodes (empty for files, populated for folders)
- `isExpanded: Bool` — current expansion state (folders only)
- `parentFolderPath: String` — path to the containing folder (used for display)

**Building the tree:**
- Recursively scan imported folder for `.md` and `.markdown` files
- Folders at any depth are represented as nodes with children
- Files become leaf nodes

---

## View Components

### SidebarView

Main container for the new sidebar.

**Layout:**
- VStack containing:
  1. RecentsSection (top, flexible height)
  2. Draggable divider (height adjustable during session)
  3. FoldersSection (bottom, flexible height)

**State:**
- `@State var dividerPosition: CGFloat` — tracks divider drag position
- Divider is user-draggable to resize sections

### RecentsSection

Displays `RecentsManager.recents` as a List.

**Each row shows:**
- File icon + filename (e.g., "document.md")
- Single click → activate tab in current window
- Double click → open in new tab

### FoldersSection

Main container for folder tree, filter, and controls.

**Layout (top to bottom):**
1. Filter bar (search field)
2. Control buttons row: "Expandir tudo" | "Contrair tudo"
3. Folder tree (recursive view)

**Filter behavior:**
- Real-time filtering as user types
- Case-insensitive file name matching
- Auto-expand parent folders of matching files
- Shows folder names (greyed out) even if they don't match, but children do

### FolderTreeItemView

Renders a single node in the folder tree.

**For folders:**
- Disclosure triangle (clickable to toggle expand)
- Folder icon + folder name
- Not interactive for file opening (folder names are structural)

**For files:**
- File icon + filename
- Faded text showing parent folder path in brackets: `[/path/to/folder]`
- Single click → open in current tab
- Double click → open in new tab

**Right-click menu:**
- Files: "Abrir em nova aba" (open in new tab)
- Folders: "Remover pasta" (if it's a root folder from importedFolders list)

---

## Interaction Flows

### Import Folder Flow
1. User selects "Adicionar pasta ao Workspace" from menu
2. Folder picker dialog opens
3. User selects a folder
4. MacDown validates it's a real folder
5. FolderManager.importFolder() is called
6. If folder already imported, returns silently
7. Tree is built, folder appears in Folders section (expanded 1 level)
8. Folder and tree persist for this session

### Open in New Window Flow
1. User selects "Abrir pasta" from menu
2. Folder picker dialog opens
3. User selects a folder
4. NEW MacDown window is launched
5. New window has FolderManager with only that folder imported
6. Recentes is empty
7. Windows operate independently

### Open File Flow
1. User single-clicks file in Recentes or Folders
2. If file already open, that tab is activated
3. If file not open, it's opened in current tab
4. File is added to Recentes (if coming from Folders)

### Open File in New Tab Flow
1. User double-clicks file in Recentes or Folders
2. File is opened in a new tab
3. File is added to Recentes (if coming from Folders)

### Filter & Search Flow
1. User types in filter bar
2. Tree is filtered in real-time
3. Folders containing matching files are auto-expanded
4. Non-matching folders collapse
5. Matching files are highlighted/visible
6. Folder structure is preserved (parent folders shown even if they don't match)

### Remove Folder Flow
1. User clicks × button next to folder name OR right-clicks → "Remover pasta"
2. Folder is removed from importedFolders
3. Its tree is removed from display
4. Files from that folder are removed from Recentes (if present)

### Session End Flow
1. User presses command+q to quit
2. RecentsManager.clear() and FolderManager.clear() are called
3. Next launch has empty Recentes and empty Folders

---

## Mac Menu Structure

**File Menu (or MacDown Menu):**
```
- Adicionar pasta ao Workspace    (Cmd+Shift+O suggested, optional)
- Abrir pasta                      (Cmd+Shift+N suggested, optional)
```

Both are top-level menu items, not nested. They open folder picker dialogs.

---

## Data Persistence & Lifecycle

| Data | Persists? | Scope | Cleared When |
|------|-----------|-------|--------------|
| Recentes list | No | Current session only | App quit (command+q) |
| Folders list | No | Current session only | App quit (command+q) |
| Divider position | No | Current session only | App quit (command+q) |
| Folder expansion state | No | Current session only | App quit (command+q) |
| Filter text | No | Current session only | App quit (command+q) |

**Note:** Nothing is saved to UserDefaults or disk. All state is in-memory for the session.

---

## Error Handling

- **Invalid folder selection:** User cancels picker → no action
- **Duplicate folder import:** Silently ignored
- **File deleted during session:** File remains in Recents/Folders until user removes it manually or closes folder
- **Folder moved/deleted:** Tree may show stale references; clicking opens error dialog (standard macOS behavior)
- **Permission denied:** Standard macOS file access dialogs

No error messages for duplicate folder attempts (silent ignore per requirements).

---

## Testing Strategy

- **RecentsManager:** Unit tests for add, clear, deduplication
- **FolderManager:** Unit tests for import, remove, filter, expand/collapse logic
- **FolderTreeNode:** Tests for tree building from folder hierarchy
- **Views:** Integration tests for click behavior, filter updates, divider resizing
- **Menu integration:** Manual testing of "Adicionar pasta" and "Abrir pasta" flows

---

## Implementation Order

1. Create RecentsManager model
2. Create FolderTreeNode and FolderManager models
3. Update DocumentStore to call RecentsManager.addRecent() when files open
4. Refactor SidebarView to use new split layout
5. Build RecentsSection view
6. Build FoldersSection, FolderTreeItemView, filter bar, controls
7. Implement Mac menu items for folder operations
8. Wire up click handlers and navigation flows
9. Testing and refinement

---

## Known Constraints

- App is macOS-only (leverages NSOpenPanel for folder picker)
- Folder tree building happens synchronously on import (may be slow for very large folders; consider async later if needed)
- Filter is simple substring matching (case-insensitive); no regex or advanced search
- No folder bookmarking or persistent workspace saving (session-scoped only per requirements)

---

## Deferred / Out of Scope

- Folder sorting (alphabetical, by date, etc.) — can add later
- Nested workspace management (saving/loading workspace profiles)
- Search within content of files
- Drag-and-drop between Recentes and Folders
- Folder context menu operations (copy path, reveal in Finder, etc.) — beyond scope


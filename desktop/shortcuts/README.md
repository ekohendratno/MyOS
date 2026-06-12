# Keyboard Shortcuts — mixos macOS-inspired

## Mapping Lengkap

| macOS Shortcut | mixos Shortcut | Fungsi |
|----------------|---------------|--------|
| `⌘Q` | `Super+Q` | Quit aplikasi |
| `⌘W` | `Super+W` | Close window |
| `⌘C` | `Ctrl+C` | Copy |
| `⌘V` | `Ctrl+V` | Paste |
| `⌘X` | `Ctrl+X` | Cut |
| `⌘Z` | `Ctrl+Z` | Undo |
| `⌘S` | `Ctrl+S` | Save |
| `⌘N` | `Ctrl+N` | New window |
| `⌘O` | `Ctrl+O` | Open file |
| `⌘P` | `Ctrl+P` | Print |
| `⌘,` | `Ctrl+,` | Preferences |
| `⌘Space` | `Super+Space` | Application launcher |
| `⌘Tab` | `Alt+Tab` | Switch aplikasi |
| `⌘\`` | `Alt+Grave` | Switch window dalam app |
| `⌘F` | `Ctrl+F` | Find/Search |
| `⌘H` | `Super+H` | Minimize/hide window |
| `⌘M` | `Super+M` | Minimize |
| `⌘L` | `Super+L` | Lock screen |
| `⌘D` | `Super+D` | Show desktop |
| `⌘Shift+3` | `Shift+Super+3` | Screenshot full |
| `⌘Shift+4` | `Shift+Super+4` | Screenshot area |
| `⌘Shift+5` | `Shift+Super+5` | Screenshot options |
| `⌘Up` | `Super+Up` | Maximize |
| `⌘Down` | `Super+Down` | Unmaximize |
| `⌘Left` | `Super+Left` | Tile left |
| `⌘Right` | `Super+Right` | Tile right |
| `⌘Backspace` | `Super+Backspace` | Move to trash |
| `⌘Delete` | `Shift+Delete` | Permanently delete |
| `⌘E` | `Super+E` | Open file manager |
| `F11` | `F11` | Toggle fullscreen |

## Keyboard Layout

Default: **US** (ANSI), dengan opsi compose key di right-Win.
Yang lain bisa diatur via Settings → Keyboard.

## Catatan

- `Super` = Windows key
- `Ctrl` umumnya tetap `Ctrl`, bukan `Super`
- Untuk konsistensi macOS, beberapa app GTK4 yang support `Ctrl+,` untuk preferences akan berfungsi
- GNOME Terminal, Files, dan Code sudah support `Ctrl+,` untuk preferences
- Electron app (VS Code, Discord) tetap pakai shortcut mereka sendiri

## Implementation

Settings sudah diimplementasi di `config/keyboard-shortcuts.sh`.

Beberapa shortcut tidak bisa di-ubah karena hardcoded di GTK/GNOME:
- `Ctrl+C`/`Ctrl+V` tidak bisa diubah ke `Super+C`/`Super+V` (hardcoded di GTK)
- `Alt+F4` untuk close (alternatif ke `Super+W`)

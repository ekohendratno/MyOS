# Desktop Dock — plank Config

## Target macOS-inspired

Dock bawah dengan konfigurasi berikut:
- Posisi: **bottom-center** (bukan kiri/kanan)
- Hidden: **autohide** (muncul saat cursor mendekat, 200ms delay)
- Icon size: **40 px** (compact, tidak 48px atau 64px)
- Zoom: **120%** saat hover (animasi bounce)
- Theme: **mixos-plank** (custom, transparan dengan rounded corner)
- Trash: item paling kanan
- Running indicator: dot kecil di bawah icon
- Items: pinned (Files, Terminal, Settings, Browser, AppCenter)

## Plank Settings (dconf)

Lokasi: `~/.config/plank/dock1/settings`

```
[PlankDock]
Alignment=2               # Center
AutoHide=true
BounceDock=true
DockItemsAlignment=2       # Center
EnableTooltips=true
HideMode=1                 # Autohide
IconSize=40
ItemsAlignment=2
KeepOnScreen=true
Position=3                 # Bottom
Theme=mixos-plank
ZoomEnabled=true
ZoomFactor=1.2
```

## Plank Theme: mixos-plank

Folder: `themes/mixos-plank/`

Format tema plank:
```
mixos-plank/
├── dock.theme           # File konfigurasi (transparan, rounded)
├── close.svg            # Tombol close (jdgno)
├── quit.svg             # Tombol quit
└── urgent.svg           # Indicator urgent
```

## Patch yang Dibutuhkan

Plank sudah sangat bisa dikustomisasi via config. Patch hanya diperlukan jika:
- Ingin efek "glow" seperti macOS
- Ingin icon mirror di bawah icon (reflection)
- Ingin gesture 3D dock (tidak akan diimplementasi di tahap awal)

## Status

- Config: Siap di `config/dock-settings.sh`
- Theme: Belum dibuat (folder `branding/plank/`)

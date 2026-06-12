# Desktop Panel — wingpanel Config

## Target macOS-inspired

Top panel wingpanel akan dikonfigurasi seperti menu bar macOS:
- Tinggi: 24–26 px (compact)
- Font: Inter 9.5pt
- Background: solid #1e1e1e (solid, tidak transparan)
- Indikator kanan: network, bluetooth, sound, battery, clock
- App icon tengah: app aktif + nama app
- Global menu: jika diaktifkan (lihat global-menu/)

## GSettings Keys

```
# wingpanel
org.pantheon.desktop.wingpanel.background-color = '#1e1e1e'
org.pantheon.desktop.wingpanel.opacity = 255
org.pantheon.desktop.wingpanel.transparency-type = 'solid'

# indicator waktu
org.pantheon.desktop.wingpanel.datetime.show-date = true
org.pantheon.desktop.wingpanel.datetime.show-seconds = false
org.pantheon.desktop.wingpanel.datetime.timezone = 'UTC'
org.pantheon.desktop.wingpanel.datetime.use-meridiem = false
```

## Patch yang Dibutuhkan

Untuk mencapai tampilan menu bar seperti macOS, wingpanel perlu dipatch:

1. **Padding reduction**: kurangi padding horizontal indikator dari 8px ke 4px
2. **Font size**: turunkan default font 10pt ke 9.5pt
3. **Active indicator**: tampilkan icon app aktif + nama app sebagai heading
4. **Left side**: indicator aplikasi di kiri (bukan tengah)
5. **Clock alignment**: rata kanan

File patch: `patches/wingpanel/padding-compact.patch`

## CSS Override

```
/* Wingpanel custom CSS — if supported */
/* Beberapa versi wingpanel tidak support custom CSS */
```

## Status

- Config: Siap di `config/pantheon-settings.sh`
- Patch: Belum diimplementasi (placeholder di `patches/wingpanel/`)

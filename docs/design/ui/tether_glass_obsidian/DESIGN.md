---
name: Tether Glass Obsidian
colors:
  surface: '#0f131c'
  surface-dim: '#0f131c'
  surface-bright: '#353942'
  surface-container-lowest: '#0a0e16'
  surface-container-low: '#181c24'
  surface-container: '#1c2028'
  surface-container-high: '#262a33'
  surface-container-highest: '#31353e'
  on-surface: '#dfe2ee'
  on-surface-variant: '#b9cacb'
  inverse-surface: '#dfe2ee'
  inverse-on-surface: '#2c3039'
  outline: '#849495'
  outline-variant: '#3a494b'
  surface-tint: '#00dce6'
  primary: '#e0fdff'
  on-primary: '#00373a'
  primary-container: '#00f2fe'
  on-primary-container: '#006a70'
  inverse-primary: '#00696f'
  secondary: '#4edea3'
  on-secondary: '#003824'
  secondary-container: '#00a572'
  on-secondary-container: '#00311f'
  tertiary: '#ecfaff'
  on-tertiary: '#003640'
  tertiary-container: '#91e8ff'
  on-tertiary-container: '#00697c'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#6ff6ff'
  primary-fixed-dim: '#00dce6'
  on-primary-fixed: '#002022'
  on-primary-fixed-variant: '#004f53'
  secondary-fixed: '#6ffbbe'
  secondary-fixed-dim: '#4edea3'
  on-secondary-fixed: '#002113'
  on-secondary-fixed-variant: '#005236'
  tertiary-fixed: '#acedff'
  tertiary-fixed-dim: '#4cd7f6'
  on-tertiary-fixed: '#001f26'
  on-tertiary-fixed-variant: '#004e5c'
  background: '#0f131c'
  on-background: '#dfe2ee'
  surface-variant: '#31353e'
typography:
  headline-xl:
    fontFamily: Plus Jakarta Sans
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 22px
    fontWeight: '700'
    lineHeight: 28px
    letterSpacing: -0.015em
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
    letterSpacing: -0.01em
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  label-md:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 14px
    letterSpacing: 0.04em
  caption:
    fontFamily: Inter
    fontSize: 10px
    fontWeight: '500'
    lineHeight: 12px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  margin: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1.25rem
  space-xl: 1.75rem
---

## Brand & Style

This design system is tailored for real-time family location sharing, prioritizing trust, ambient awareness, privacy, and frictionless mobile utility. The emotional tone evokes reassuring security without feeling clinical or intrusive.

The visual direction combines **Dark Glassmorphism** with an **Obsidian Atmosphere**:
- **Palette & Mood:** Ultra-deep midnight slate surfaces (`#0B0F17` transitioning to `#111827`) elevated by translucent frosted-glass panels, fine hairline rim highlights (`rgba(255, 255, 255, 0.08)`), and glowing electric teal/cyan beacon accents.
- **Form & Tactility:** Rounded tactile shapes, pill-form actionable toggles, floating bottom sheets, and translucent map HUD overlays.
- **Localization:** Native Indonesian microcopy throughout—retaining clarity and warmth across everyday interactions (`Peta`, `Circle`, `Aktivitas`, `Profil`, `Undang`, `Keluar dari Circle`).

## Colors

The color palette centers on high-contrast emissive accents over deep ambient dark tones to ensure instant glanceability on top of street map tiles and low-light environments.

- **Primary (`#00F2FE`):** High-energy electric cyan for map pins, pulse rings, active state navigation indicators, and primary CTAs.
- **Secondary (`#10B981`):** Bio-luminescent emerald green representing safe states, active battery levels, online status, and confirmation switches.
- **Tertiary (`#06B6D4`):** Soft teal for secondary interactive controls, status chips, and contextual links.
- **Neutral Base (`#0B0F17` & `#111827`):** Obsidian slate backdrop for deep perceived black without OLED smearing.
- **Destructive Accent (`#EF4444` / `#F87171`):** Warning states, member removals (`Keluarkan`), and leaving circles (`Keluar dari Circle`).
- **Surface Transparencies:** Frosted containers use `rgba(17, 24, 39, 0.72)` over map views and `rgba(255, 255, 255, 0.04)` to `rgba(255, 255, 255, 0.08)` for hairline borders.

## Typography

Typography pairs **Plus Jakarta Sans** for expressive, human-centered UI headers and primary content with **Inter** for compact metadata, timestamps, and navigation labels.

- Headers carry subtle negative tracking (`-0.01em` to `-0.02em`) to maintain tightness in modal titles and card summaries.
- Timestamps and live statuses (e.g., `Terakhir terlihat 48 mnt lalu`, `Diperbarui 25 mnt lalu`) utilize tabular-ready body scales (`body-sm`) in muted slate tones (`#94A3B8`).
- Category super-headers (e.g., `BERBAGI`, `ANGGOTA`, `WARNA PENANDA`, `AKUN`) use `label-sm` with uppercase transformation and extended tracking (`0.06em`) for structured vertical grouping.

## Layout & Spacing

The layout is built for fluid mobile-first handheld usage with tight edge margins, persistent bottom sheet mechanics, and floating control anchors.

- **Canvas Rhythm:** 16px (`1rem`) horizontal screen padding provides maximum map and list real estate while maintaining touch thumb boundaries.
- **Map Viewport Integration:** Map cards and bottom sheets snap cleanly along a vertical axis. Floating map HUD items (re-center, layer toggles, shield/safety buttons) maintain `space-sm` (8px) stacking gaps and `margin` (16px) clearance from screen boundaries.
- **Vertical Hierarchy:** Section groups separate with `space-xl` (28px). Inner element rows in grouped lists maintain `space-md` (12px) padding and `space-sm` (8px) internal gaps.

## Elevation & Depth

Visual hierarchy uses frosted glassmorphism and subtle emissive glows rather than muddy drop shadows.

- **Level 0 (Map / Canvas Base):** Raw map surface or obsidian black canvas (`#070A0F`).
- **Level 1 (Glass Container Cards):** Semi-opaque background (`rgba(17, 24, 39, 0.78)`), backdrop filter blur of `16px` to `20px`, accompanied by a 1px border highlight (`rgba(255, 255, 255, 0.08)`).
- **Level 2 (Interactive Floating HUD & Sheets):** Backdrop blur of `24px`, background fill `rgba(15, 23, 42, 0.88)`, top border highlight `rgba(255, 255, 255, 0.12)`, and a low-opacity ambient drop shadow `0 12px 32px -4px rgba(0, 0, 0, 0.6)`.
- **Level 3 (Active Beacon / Modals):** Cyan/Teal ambient perimeter glow (`0 0 24px -2px rgba(0, 242, 254, 0.35)`) used for the active user avatar pin, safety beacon triggers, and primary submit buttons.

## Shapes

The design uses balanced, rounded geometry that bridges tactile softness and contemporary utility:

- **Cards & Input Blocks:** Standard `rounded-xl` (16px / 1rem radius) to frame grouped list items and form containers comfortably.
- **Pill Buttons & Filter Chips:** Full-radius pill shapes (`rounded-full` / 9999px) for primary action triggers (`Undang`, `Masuk`, `Daftar`, `Buat akun`), top status chips (`keluarga`, `Lokasi tidak tersedia`), and navigation pill segments.
- **Map Floating Action Buttons:** Circular shapes (44px × 44px) with centered glyphs.
- **Avatars & Color Pickers:** Circular rings with an inner 2px gap and active border ring.

## Components

### Buttons
- **Primary Pill:** Full-width or inline, height 48px, solid gradient or high-glow fill from `#00F2FE` to `#06B6D4`, label in bold dark slate (`#0B0F17`). 
- **Destructive Action:** Ghost surface (`rgba(239, 68, 68, 0.08)`), border `1px solid rgba(239, 68, 68, 0.25)`, text in crimson `#F87171` (`Keluar dari Circle`, `Hapus akun`).
- **Segmented Control:** Dark glass background (`rgba(255, 255, 255, 0.05)`) with animated pill selector highlight in translucent slate (`rgba(255, 255, 255, 0.16)`).

### Cards & Grouped Lists
- Card items feature a unified glass container holding multiple rows separated by hairline dividers (`rgba(255, 255, 255, 0.05)`).
- Member rows feature a leading avatar with the user's initial or photo, user title with `(Kamu)` badge, contextual subtitle (e.g. `Admin`, `Diam • Diperbarui 25 mnt lalu`), and trailing battery indicator or state action.

### Map Overlays & Bottom Navigation
- **Floating Top Indicators:** Pill badge with blurred black glass background (`rgba(0, 0, 0, 0.65)`), displaying the current active circle name with caret.
- **Bottom Navigation Bar:** Translucent floating or docked bar with frosted glass (`rgba(11, 15, 23, 0.9)`), active glow icon in `#00F2FE`, inactive items in `#64748B`. Items: `Peta`, `Circle`, `Aktivitas`, `Profil`.

### Inputs & Swatches
- **Form Fields:** Stacked grouped input boxes with dark translucent background (`rgba(255, 255, 255, 0.04)`), muted placeholder typography, and glowing cyan borders on focus.
- **Color Selector Chips:** Row of circular color swatches (32px diameter); selected swatch shows a sharp white checkmark glyph inside.
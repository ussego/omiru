# Omiru

Search the [svgl.app](https://svgl.app) logo library and copy SVG logos to the clipboard — an overlay for the Omarchy shell.

![omiru overlay](preview.png)

## Install

```sh
omarchy plugin add https://github.com/ussego/omiru.git --enable
```

## Removal

```sh
omarchy plugin remove ussego.omiru
```

## Usage

Summon the overlay and type — the logo grid filters live as you type:

```sh
omarchy-shell shell summon ussego.omiru
```

- Type in the input at the top to filter logos by name.
- Tab / Shift+Tab cycle categories (or click a category chip); logos are cached locally, so browsing works offline after the first run.
- Up/Down/Left/Right (PageUp/PageDown) move the selection; Enter or click copies the logo in the active format and closes.
- Ctrl+D opens the detail view of the selected logo (same as right-click); Esc returns to the grid.
- Ctrl+F cycles the copy format — `svg` (raw source), `shadcn` (shadcn/ui registry command), `jsx`, `tsx` (React component, converted from the optimized svgl API source) — shown in the header, e.g. `tsx · 7 / 665`.
- Right-click a logo to inspect it before copying: larger preview, category, website. In the detail view Enter copies in the active format, 1-4 pick a format directly, `w` opens the logo's website, Esc goes back.
- Esc clears the search (or closes), clicking the backdrop closes, Ctrl+R re-fetches the catalog from svgl.app.

Logos with separate light/dark variants follow the menu background: dark themes get the dark variant, light themes the light one.

### IPC

```sh
omarchy-shell shell summon ussego.omiru '{"query":"git","category":"Software"}'
omarchy-shell shell hide ussego.omiru
omarchy-shell shell toggle ussego.omiru
omarchy-shell shell call ussego.omiru refresh '{}'
omarchy-shell shell call ussego.omiru clearCache '{}'
```

Payload: `{"query": "..."}` pre-fills the search, `{"category": "..."}` pre-selects a category. `refresh` forces a catalog re-fetch from the svgl API. `clearCache` deletes the local cache (below) and re-fetches the catalog from scratch.

### Keybinding

Add to `~/.config/hypr/bindings.lua`:

```lua
hl.unbind("SUPER + CTRL + G")
o.bind("SUPER + CTRL + G", "Search SVG logos", "omarchy-shell shell toggle ussego.omiru")
```

SUPER + CTRL + I (icon) would be the better mnemonic, but it's taken by the idle-lock toggle —> hence G.

## Cache

Omiru caches everything under one directory so browsing works offline after the first run:

- `~/.local/state/omarchy/omiru/svgl.json` — the svgl catalog (auto re-fetched when older than 30 minutes, or with Ctrl+R)
- `~/.local/state/omarchy/omiru/library/` — each logo's SVG plus a PNG preview (`<slug>.svg.png`) rasterized with `rsvg-convert`

Nothing is written anywhere else — the React component cache (`tsx`/`jsx`) lives only in memory and is rebuilt on demand. To wipe the cache and start fresh:

```sh
omarchy-shell shell call ussego.omiru clearCache '{}'
```

## Dependencies

Uses `curl` and `wl-copy` (from `wl-clipboard`), which ship with Omarchy. Previews are rasterized with `rsvg-convert` (librsvg, also shipped) so every logo renders faithfully even when Qt's SVG renderer can't handle it; the raw SVG is still what gets copied.

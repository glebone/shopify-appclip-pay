# MfB → App Clip → Shopify Apple Pay (proof of concept)

One link in Apple Messages for Business opens an App Clip with a single Apple Pay button
backed by Shopify Checkout Kit. Spec: `docs/superpowers/specs/`. Plan: `docs/superpowers/plans/`.

## Parameters

Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and fill every key.
Shell scripts read the same file via `source scripts/config.sh`.

## Build

    xcodegen generate
    open PayClipDemo.xcodeproj

Schemes: `PayDemo` (parent app), `PayClip` (App Clip, launches with `_XCAppClipURL`).

## Unit tests

    swift test --package-path Packages/PayLinkCore

## Demo modes

- Mode A: run the `PayClip` scheme on a device; `_XCAppClipURL` supplies the link.
- Mode B: register a Local Experience, then text the link from a contact.
- Mode C: App Store release, then `scripts/send_mfb_appclip.sh`.

Sections below are filled in by later tasks.

## Website

The AASA file and the `/pay/` landing page are hosted on the existing user site repo
`glebone/glebone.github.io` (legacy GitHub Pages: branch `main`, root), next to the older
Universal Link PoC that already lives there. `CLIP_DOMAIN = glebone.github.io`.

- `site/` is generated from `site-src/` by `scripts/render_site.sh`. The AASA template keeps the
  existing `linkdemo` applinks entry and adds the `appclips` entry plus `/pay/*` for this app.
- `scripts/deploy_site.sh` clones the Pages repo, writes only `.well-known/apple-app-site-association`,
  `pay/index.html` and `preview.png`, commits, and pushes. Legacy Pages rebuilds in about a minute.
- `scripts/check_aasa.sh` fetches the file directly and through Apple's CDN
  (`app-site-association.cdn-apple.com`), which is what iOS reads, and prints the landing page meta tag.

After changing any key in `Config/Local.xcconfig`: `scripts/render_site.sh`, commit `site/`,
`scripts/deploy_site.sh`, then `scripts/check_aasa.sh`.

Observed direct Content-Type on GitHub Pages: `application/octet-stream` (2026-10-13). Apple CDN status: 200, serves the same JSON, so the octet-stream type is accepted. The legacy Pages build takes about a minute after `deploy_site.sh`; `check_aasa.sh` exits 1 until it lands.

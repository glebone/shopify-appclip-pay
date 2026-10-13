# MfB → App Clip → Shopify Apple Pay (proof of concept)

One link in Apple Messages for Business opens an App Clip with a single Apple Pay button
backed by Shopify Checkout Kit. Spec: `docs/superpowers/specs/`. Plan: `docs/superpowers/plans/`.

## Parameters

Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and fill every key.
Shell scripts read the same file via `source scripts/config.sh` (bash only; from zsh use
`bash -c 'source scripts/config.sh && echo "$CLIP_DOMAIN"'`).

## Build

    xcodegen generate
    open PayClipDemo.xcodeproj

Schemes: `PayDemo` (parent app), `PayClip` (App Clip, launches with `_XCAppClipURL`).

## Unit tests

    swift test --package-path Packages/PayLinkCore
    python3 -I -m unittest discover -s scripts/tests -p 'test_*.py'
    scripts/tests/test_config_sh.sh

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

Observed direct Content-Type on GitHub Pages: `application/octet-stream` (2026-10-13). Apple CDN status: 200, serves the same JSON, so the octet-stream type is accepted. The legacy Pages build takes about a minute after `deploy_site.sh`; `check_aasa.sh` exits 1 until the direct file, Apple's CDN copy, and the landing page meta all carry the configured clip id. Apple's CDN kept the previous copy for a while after Pages had updated (observed 2026-10-13), so the CDN line can lag the other two; device tests in Task 8 use `?mode=developer` on the associated domain so the phone reads the site directly.

## Apple setup

- Team ID, bundle ID, merchant ID and App Store Apple ID live in `Config/Local.xcconfig`.
- Xcode automatic signing (`xcodebuild -allowProvisioningUpdates`) registered both App IDs and the
  merchant ID `merchant.<bundle id>` on 2026-10-13; the clip's profile grants Associated Domains,
  Apple Pay with that merchant ID, and the App Clip parent entitlement.
- Both targets take their version from `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `project.yml`;
  Apple rejects a build whose clip `CFBundleVersion` differs from the parent's.
- The App Store Connect record is needed before any device test because the landing page's `app-id` meta value comes from it.
- The Apple Pay *Payment Processing* certificate is created in Task 7 because its CSR comes from Shopify.

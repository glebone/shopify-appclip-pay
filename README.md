# MfB → App Clip → Shopify Apple Pay (proof of concept)

One link in Apple Messages for Business opens an App Clip that presents Shopify's checkout sheet
(Checkout Sheet Kit) from a cart permalink; Apple Pay is served by Shopify inside that sheet. The
clip holds no merchant ID, certificate, Storefront token, or custom app. The native Accelerated
Checkouts button was dropped on 2026-10-13; see the change note at the top of the spec. Spec: `docs/superpowers/specs/`. Plan: `docs/superpowers/plans/`.

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

- Mode A: run the `PayClip` scheme on a device; `_XCAppClipURL` supplies the link. Debug builds also read
  the variable directly, so a command-line launch works too:
  `xcrun devicectl device process launch --device <udid> --environment-variables '{"_XCAppClipURL":"https://glebone.github.io/pay/?v=0"}' com.glebone.payclipdemo.Clip`
  (verified on iPhone Air 2026-10-13: pay view with a Storefront error, as expected before Task 7).
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

Observed direct Content-Type on GitHub Pages: `application/octet-stream` (2026-10-13). Apple CDN status: 200, serves the same JSON, so the octet-stream type is accepted. The legacy Pages build takes about a minute after `deploy_site.sh`; `check_aasa.sh` exits 1 until the direct file, Apple's CDN copy, and the landing page meta all carry the configured clip id. Apple's CDN kept the previous copy for a while after Pages had updated (observed 2026-10-13), so the CDN line can lag the other two; both entitlements carry `?mode=developer`, which development-signed builds honor to read the site directly instead of the CDN (needs Developer Mode on the phone; ignored by App Store builds).

## Apple setup

- Team ID, bundle ID and App Store Apple ID live in `Config/Local.xcconfig`.
- Xcode automatic signing (`xcodebuild -allowProvisioningUpdates`) registered both App IDs on
  2026-10-13; the clip's profile grants Associated Domains and the App Clip parent entitlement.
- Both targets take their version from `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `project.yml`;
  Apple rejects a build whose clip `CFBundleVersion` differs from the parent's.
- The App Store Connect record is needed only for Mode C: the landing page's `app-id` meta value comes
  from it. Modes A and B work without it.
- No Apple Pay merchant ID or payment processing certificate: Shopify is the Apple Pay web merchant
  inside the checkout sheet.

## Shopify setup

- Any store on a paid plan with Shopify Payments active, test mode enabled, and Apple Pay ticked under
  Wallets. A free Partner development store cannot provide Apple Pay.
- One product (`Demo Pass`, 5.00, digital, Active, on the Online Store channel). Its numeric variant id
  goes in `Config/Local.xcconfig` as `DEMO_VARIANT_ID`; the `*.myshopify.com` host as `STOREFRONT_DOMAIN`.
- The clip opens `https://$STOREFRONT_DOMAIN/cart/$DEMO_VARIANT_ID:1` in the checkout sheet. Check it
  with `curl -sS -o /dev/null -w "%{http_code} %{redirect_url}\n" <that url>`: expect a 302 to `/checkouts/…`.

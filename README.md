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

# Requirements: Messages for Business → App Clip → Shopify Apple Pay (POC)

Date: 2026-10-13
Status: Draft for review
Stage: Requirements discovery (no architecture or implementation decisions yet)

## 1. Goal

Prove, end to end on a real iPhone, that a business can send a link in Apple
Messages for Business (MfB) via Infobip, the customer taps it, an App Clip
opens with essentially one Apple Pay button, and paying creates an order in a
Shopify store through Shopify's native iOS SDK (Checkout Kit "Accelerated
Checkouts").

This is a proof of concept. Polish, catalog, accounts, and production hardening
are explicitly out of scope.

## 2. What was stated vs. what is assumed

Stated by the user:

- Entry point is a link sent through MfB. MSP is Infobip, which has an
  `APP_CLIP` content type on its `apple-mfb` messages endpoint.
- Payment must go through the Shopify iOS SDK, not a direct PassKit
  integration.
- The App Clip should have the minimum possible steps: ideally just an Apple
  Pay button.
- Shopify store does not exist yet; a sandbox is wanted for now.
- Public HTTPS domain will be GitHub Pages.
- Paid Apple Developer account exists. MfB business account exists.
- Store and Apple Pay merchant entity will be in the United States.

Assumed (confirm or correct):

- A1. One Shopify store, one product variant, fixed quantity of 1.
- A2. The link encodes which variant to sell (e.g. `/pay/<id>`); the App Clip
  does not browse or search.
- A3. The storefront access token is embedded in the App Clip binary. This is
  acceptable for a POC because Storefront tokens are public-facing.
- A4. Shipping is not part of the demo: either the product is a digital or
  "no shipping required" item, or a single flat rate is accepted without the
  customer choosing anything.
- A5. Real money must never move. Orders are test orders.
- A6. Target iOS 17 or later on the test device, to use the 100 MB App Clip
  budget and avoid physical-invocation constraints.

## 3. Facts established during discovery (with sources)

F1. App Clips launch from Messages when the shared URL points to a page that
    carries the `apple-itunes-app` meta tag with `app-clip-bundle-id`. The
    recipient's device must run iOS 14+ and have the sender as a contact.
    Preview image comes from `og:image`.
    https://developer.apple.com/documentation/appclip/supporting-invocations-from-your-website-and-the-messages-app

F2. Before App Store release, a Local Experience registered on the test device
    (Settings → Developer → Local Experiences) can launch a Development,
    Ad Hoc, or TestFlight-signed App Clip from a link shared in Messages. The
    App Clip card in Messages for the general public requires the app to be
    published on the App Store. TestFlight App Clip experiences launch from
    the TestFlight app, not from Messages, and show no card.
    https://developer.apple.com/documentation/appclip/testing-the-launch-experience-of-your-app-clip

F3. Apple's MSP `constructPayload` endpoint turns an App Clip URL into a rich
    link payload. It returns 400 if the page has no App Clip elements. It
    takes a `storeRegion` (default US), which implies the App Clip is looked
    up in the App Store. Infobip wraps this behind its `APP_CLIP` type.
    https://register.apple.com/resources/messages/msp-rest-api/construct-payload

F4. Apple Pay is a supported App Clip capability. Size limit is 100 MB
    uncompressed when targeting iOS 17+ with digital invocations only.
    https://developer.apple.com/documentation/appclip/choosing-the-right-functionality-for-your-app-clip

F5. Shopify "Accelerated Checkouts" (Checkout Kit for Swift ≥ 3.4.0, module
    `ShopifyAcceleratedCheckouts`, iOS 16+) provides a native SwiftUI
    `AcceleratedCheckoutButtons(variantID:quantity:)` with Apple Pay. It needs
    a storefront domain, storefront access token with the
    `write_cart_wallet_payments` scope, an Apple Pay merchant identifier in
    the Apple Developer portal and the Xcode Apple Pay capability, and Apple
    payment processing certificates. Callbacks: `onComplete`, `onFail`,
    `onCancel`. On Apple Pay failure it falls back to the web checkout sheet.
    Announced 2025-10-08.
    https://shopify.dev/docs/storefronts/mobile/checkout-kit/accelerated-checkouts
    https://changelog.shopify.com/posts/integrate-accelerated-checkout-buttons-shop-pay-and-apple-pay-on-your-mobile-app-storefronts

F6. Shopify Payments test mode requires a paid plan and completed Shopify
    Payments setup (business info may be required). Apple Pay in test mode
    uses a real card but creates no charge; the order shows a test-mode
    banner. A free Partner development store offers only the Test (Bogus)
    gateway, which does not provide Apple Pay.
    https://help.shopify.com/en/manual/payments/shopify-payments/testing-shopify-payments
    https://help.shopify.com/en/partners/dashboard/managing-stores/test-orders-in-dev-stores

F7. GitHub Pages cannot set custom response headers. The AASA file is served
    extensionless, so its Content-Type will not be `application/json`. Apple's
    CDN has historically accepted this, but it is unverified for this project.

## 4. Functional requirements

FR1. Link delivery. A business agent (or script) sends one Infobip
     `APP_CLIP` message containing the invocation URL to the test iPhone's
     MfB conversation.

FR2. Landing page. The invocation URL resolves to an HTTPS page on the
     project domain that carries the `apple-itunes-app` meta tag (with
     `app-id`, `app-clip-bundle-id`, `app-clip-display=card`) and an
     `og:image`. If the App Clip cannot launch, the page itself must show the
     same product and a plain "open in Safari" fallback message so the demo
     degrades visibly rather than silently.

FR3. Domain association. The domain serves
     `/.well-known/apple-app-site-association` with an `appclips` entry for
     the App Clip bundle ID, and the App Clip has the matching
     `appclips:` associated-domains entitlement.

FR4. Invocation handling. The App Clip reads the invocation URL from the
     `NSUserActivity`, extracts the variant identifier, and rejects malformed
     or unknown identifiers with a one-line error screen.

FR5. Single screen. The App Clip shows one screen: product title, price, a
     small image (optional), and Shopify's Apple Pay button. No navigation,
     no cart, no quantity picker, no account.

FR6. Payment. Tapping the button presents the Apple Pay sheet via Shopify's
     Accelerated Checkouts. The customer authorizes with Face ID / Touch ID.

FR7. Confirmation. On `onComplete` the App Clip replaces the button with a
     confirmation state (order placed). On `onCancel` it returns to the
     button. On `onFail` it shows the error text; Shopify's web checkout
     fallback is acceptable if the SDK triggers it.

FR8. Order visibility. The resulting order appears in the Shopify admin
     marked as a test order, with the correct variant and Apple Pay as the
     payment method.

FR9. Parent app. A minimal container app exists only because App Store
     Connect requires one. It needs no features beyond launching.

## 5. Non-functional requirements

NFR1. No real charges at any point. Shopify Payments stays in test mode.
NFR2. App Clip uncompressed binary stays well under 100 MB (target: under
      30 MB after thinning) so iOS 17+ digital invocation is unconstrained.
NFR3. Time from tap in Messages to visible Apple Pay button under 3 seconds
      on Wi-Fi, excluding first-time App Clip download.
NFR4. No secrets beyond the public storefront token ship in the binary. The
      Infobip API key and Apple MSP credentials live only on the sending
      side. (The key pasted during discovery should be rotated.)
NFR5. Everything needed to reproduce the demo (AASA, landing page, send
      script, Xcode project, store setup checklist) lives in this repository.
NFR6. The POC must be demonstrable in three escalating modes, so progress is
      visible before App Store review completes:
      - Mode A: Xcode `_XCAppClipURL` launch (no card, no domain check).
      - Mode B: Local Experience on the device + link in a regular iMessage
        from a contact (card appears, domain check bypassed).
      - Mode C: App Store-released App Clip + Infobip `APP_CLIP` message
        (the real thing).

## 6. User stories and acceptance criteria

US1. As a business agent, I send one API call to Infobip and the customer
     receives an App Clip card in the MfB conversation.
     Accept: card shows app name, icon, and an Open action; no plain-link
     fallback (Mode C). In Mode B the same card appears from a regular
     iMessage sent by a contact.

US2. As a customer, I tap Open and within seconds see the product and an
     Apple Pay button, nothing else to fill in.
     Accept: one screen, no text input, button visible without scrolling.

US3. As a customer, I tap Apple Pay, authorize, and see "order placed".
     Accept: Apple Pay sheet is Shopify's (not a custom PassKit sheet), the
     sheet shows the product price, confirmation appears after authorization.

US4. As the merchant, I open Shopify admin and find the order.
     Accept: order exists, flagged test, line item matches the variant from
     the link, gateway shows Apple Pay / Shopify Payments.

US5. As a developer, I can re-run the demo from a clean device.
     Accept: README steps cover store setup, certificates, Local Experience
     registration, and the Infobip send command.

## 7. Risks ranked by likelihood of blocking the POC

R1. Shopify Payments test mode + native Accelerated Checkouts Apple Pay is
    not documented together. The wallet payment flow might not work in test
    mode. Mitigation: validate first (see §8, V1). Fallback: Shopify Checkout
    Sheet Kit (web checkout in the SDK's sheet) which still satisfies "Apple
    Pay through the Shopify iOS SDK" but adds one screen.

R2. Free development store cannot provide Apple Pay (F6). The sandbox must
    be a trial store on a paid plan with Shopify Payments test mode and a US
    business profile. Cost is small but non-zero and needs business details.

R3. App Clip card from MfB (Mode C) requires App Store release (F2, F3).
    App Store review of a near-empty app with an App Clip may be rejected or
    delayed. Mitigation: Mode B proves the same mechanism without review;
    treat Mode C as the final milestone.

R4. The "sender must be a contact" rule (F1) is documented for consumer
    sharing. Whether MfB business conversations satisfy it is unknown.
    Only Mode C can answer this.

R5. GitHub Pages AASA Content-Type (F7). Mitigation: verify with Apple's
    CDN (`https://app-site-association.cdn-apple.com/a/v1/<domain>`) on day
    one; fall back to Cloudflare Pages or Netlify, both of which allow
    custom headers.

R6. Apple Pay merchant setup requires a US merchant entity and payment
    processing certificate exchange with Shopify. Lead time is a few days.

## 8. Validation order (cheapest first)

V1. Store sandbox: create a US trial store on the cheapest paid plan, enable
    Shopify Payments test mode, enable Apple Pay under Wallets, add one
    product, create a Headless storefront token with
    `write_cart_wallet_payments`. Confirm Apple Pay shows in the web
    checkout in test mode. (Answers R2, half of R1.)

V2. Native SDK on a full app target, not yet an App Clip: Accelerated
    Checkouts Apple Pay button pays a test order. (Answers R1.)

V3. Domain: publish AASA and landing page on GitHub Pages; check Apple CDN
    response. (Answers R5.)

V4. Mode A then Mode B invocation with the App Clip target. (Proves FR2-FR8
    without App Store.)

V5. Submit parent app + App Clip; on approval run Mode C via Infobip.
    (Answers R3, R4.)

## 9. Out of scope

- Multiple products, carts, quantities, discounts, shipping choice.
- Customer accounts, Shop Pay, Google Pay, card entry.
- Analytics, push, localization, accessibility audit, App Store marketing.
- Production hardening of the sending side (retries, webhooks, templates).
- Android or RCS equivalents.

## 10. Open questions for the user

Q1. Is a paid Shopify trial store with a US business profile acceptable for
    the sandbox, given F6? If not, the only SDK path left is Checkout Sheet
    Kit with the Test gateway, which has no Apple Pay.
Q2. Do you have (or can you create) a US Apple Pay merchant entity for the
    merchant ID and Shopify payment processing certificate?
Q3. Is submitting a minimal parent app to the App Store acceptable for this
    POC, or should Mode B (Local Experience + iMessage) be the finish line?
Q4. GitHub Pages: is a custom domain already attached, or will it be
    `<user>.github.io`? Either works for AASA, but the domain name is baked
    into entitlements and App Store Connect, so it should not change later.
Q5. Shipping (A4): digital product, or physical with one flat rate?

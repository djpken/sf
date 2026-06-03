# sf-pos Phase A Design

## Goal

Stabilize the existing iPad POS proof of concept into a reliable front-of-house core workflow. Phase A keeps the current single-device React/Vite app and mock data model, improves state consistency and UI/UX, and verifies the main service flow end to end.

## Scope

Phase A includes:

- Table lifecycle from available, seated, ordering, cooking, served, waiting visit, checkout, cleaning, and back to available.
- Order line lifecycle from draft, sent to kitchen, served, and included in checkout.
- iPad POS operations for PIN login, table selection, opening a table, ordering, sending to kitchen, marking food served, visit follow-up, checkout, and cleaning.
- Settings improvements that keep table layout editing separate from front-of-house table operation.
- UI/UX polish for touch targets, text density, disabled states, empty states, next-step calls to action, and visual severity.
- Playwright coverage for the main iPad workflow and responsive device preview modes.

Phase A does not include:

- Backend API integration, database schema, multi-device sync, or real authentication.
- Production KDS, inventory, membership, invoicing compliance, or exported reports.
- Dedicated back-office application.
- Payment processor integration.

## Product Decisions

The first screen remains the iPad POS workspace, not a landing page. Front staff should default to their assigned zone, while managers can see the whole restaurant. The UI should support a dinner rush: high information density, obvious status signals, and short paths to the next action.

The app should treat Phase A as a realistic local simulation rather than a production POS. Mock persistence may be added only if it helps demonstrate continuity during a single browser session. Formal backend-ready abstractions should be avoided unless they directly reduce current state bugs.

## Data And State Design

Table state should be derived through clear actions rather than scattered UI patches:

- Opening a table sets party count and moves the table into ordering.
- Sending new order lines marks only draft lines as sent and moves the table to cooking.
- Marking all sent lines as served moves the table to served.
- A served table can be moved to waiting visit or checkout.
- Completing checkout clears order lines, moves the table to cleaning, then releases it to available.

Order submission must append or update draft lines without replacing sent lines for the same table. Already-sent lines should not be removable from the order overlay. Draft lines can be removed or adjusted before sending.

Checkout totals should use the actual table order lines rather than synthetic estimates wherever order data exists.

## UI/UX Requirements

Touch controls must remain comfortable on iPad-sized viewports. High-frequency actions should be primary buttons, while destructive or irreversible actions must be visibly distinct or disabled when unavailable.

Long menu item names and subtitles should not break card layout. Table cards, order lines, drawer content, and queue cards should truncate or wrap predictably without overlapping. The UI should not rely on one hue only: status colors should stay distinct for available, ordering, cooking, served, visit, checkout, and cleaning.

The table detail drawer must always show the next recommended action. Empty states must explain what will appear there next. Settings table layout cards should remain identity-focused and not show live operational details.

## Verification

Verification must include:

- `npm run build`
- Existing Playwright smoke flow, expanded for Phase A behavior.
- Browser screenshot checks for the main iPad views after implementation.

Tests should cover:

- PIN login for front staff and manager.
- Zone table visibility.
- Opening a table.
- Adding, adjusting, removing, and sending draft order lines.
- Appending later order lines without deleting existing sent lines.
- Preventing sent lines from being removed in the order overlay.
- Marking single items and whole tables served.
- Checkout using actual order totals, completing checkout, and clearing the table.
- Settings layout editing persisting back into read-only floor views.

## Future Phases

Phase B can extend checkout with discounts, split bills, receipt/fiscal mock data, payment method details, and shift totals.

Phase C can add a dedicated KDS view, management/back-office entry points, richer role permissions, and a backend-ready data contract.

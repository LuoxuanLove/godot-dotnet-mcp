# Dock UI Style Guide

This guide is the shared visual and interaction contract for every Godot .NET MCP Dock page. New pages and material changes to existing pages should follow it unless an editor limitation is documented and covered by a focused test.

## Principles

- Stay Godot-native: inherit editor themes, controls, icons, focus behavior, and scale.
- Keep the interface quiet: show the current task and primary action before metadata or diagnostics.
- Use progressive disclosure: essential state stays visible, while audit and technical detail remain available on demand.
- Preserve capability when simplifying presentation; moving secondary information must not remove the action or evidence behind it.
- Never rely on color alone for current, warning, error, selected, or disabled state.

## Page Hierarchy

Use no more than three structural levels.

| Level | Purpose | Guidance |
|---|---|---|
| Page | One Dock tab | Use at most one page-level `ScrollContainer`; specialized `Tree` or preview panes may scroll independently, and page-level horizontal scrolling is not allowed. |
| Card | One feature area | Give each card one title, at most one persistent description, and one status region. |
| Group | Related fields or actions | Keep labels, controls, and feedback together with predictable spacing. |

The visual order must match the keyboard focus order. Put the most common path first and move fixed repository facts, hashes, timestamps, and audit trails into secondary details.

## Spacing And Layout Tokens

All values are logical pixels multiplied by the current editor scale.

| Token | Use |
|---|---|
| `4` | Tightly related icon, badge, or helper content |
| `8` | Controls and buttons inside one group |
| `10` | Content rhythm inside a card or inset status panel |
| `12` | Page margin, vertical card padding, and major group separation |
| `14` | Horizontal card padding |
| `16` | Optional separation between large regions on wide layouts only |

Prefer margins and ordinary container separation in `.tscn` scenes. Scripts may scale those values or change layout at a breakpoint, but should not duplicate static scene spacing without a runtime reason.

## Theme, Text, And Icons

- Duplicate and adjust editor `PanelContainer`, `Tree`, `LineEdit`, `TextEdit`, and related style boxes instead of creating an unrelated palette.
- Read accent, separator, error, font, and disabled-font colors from the `Editor` theme.
- Use `EditorIcons` for familiar editor actions. An icon-only action requires a tooltip and an accessible action name.
- Use the normal label color for primary content. Descriptions, hints, and metadata form progressively quieter levels, but must remain readable in light and dark editor themes.
- Keep section titles at the editor's normal type scale unless a shared semantic variation is introduced for every page.

## Forms And Control Widths

- Use a two-column `GridContainer` for label and field pairs on regular widths.
- Labels use a consistent regular-width minimum near `112` logical pixels; fields expand and should not depend on their longest localized item.
- At ultra-narrow widths, change the grid to one column, clear fixed field widths, and place each label immediately before its control.
- Long paths, refs, and IDs may use ellipsis only when the complete value is available through a tooltip or details surface.
- Do not make a disabled control the only explanation. Provide nearby status text or a localized tooltip that states why it is unavailable.

## Status, Help, And Details

- A card may keep one persistent description and one live status region. Do not repeat the same instruction in both.
- Idle guidance should name the next action. Loading state should identify the active scope, lock conflicting actions, and show progress when measurable.
- Success text should be short. Error text must retain the cause and a recovery action when one is known.
- Operational metadata such as trigger source, HTTP status, rate-limit reset, hashes, and comparison counts belongs in a collapsible details surface.
- Error and exhausted-rate-limit details may open automatically; ordinary audit information stays collapsed.

## Lists, Tables, And Empty States

- Show only columns needed to choose or inspect the item. Move secondary dates and identifiers to tooltips or details on narrow layouts.
- Current rows require a text marker or icon in addition to any color treatment, and must not offer an action that would select the same item again.
- Row actions are tertiary. Use a localized label or tooltip even when an editor icon is present.
- Hide an empty `Tree` and show a concise empty state that distinguishes not-yet-loaded, loading, no-results, and error conditions.
- Keep selection, scroll position, and deferred row actions stable while the model refreshes.

## Action Semantics

| Priority | Typical use | Placement |
|---|---|---|
| Primary | Start, apply, or one-click update | One per card, last in visual and focus order |
| Secondary | Refresh, copy, retry, or open details | Near the scope it affects |
| Tertiary | Per-row switch or compact utility action | Inside the relevant row or context menu |
| Destructive | Remove, clear, or delete | Visually separated and confirmed when loss is possible |

Hover-only controls may duplicate a discoverable action, but must never be the sole way to invoke an important operation.

## Responsive Dock Behavior

| Content width | Expected layout |
|---|---|
| `>= 560` | Two-column forms, compact summary rows, and side-by-side action buttons |
| `360-559` | Two-column forms where readable, reduced metadata, and compact tables |
| `< 360` | One-column forms and actions, zero fixed field width, and reduced table height |

Use containers and size flags so the page remains usable at the Dock's minimum width. Avoid fixed column totals that exceed the available width. Validate short and tall Dock shapes as well as editor scales `1`, `1.5`, and `2`.

## Accessibility

- Preserve keyboard focus for every important action and ensure focus order follows visual order.
- Pair color with text, icon, shape, or position for every semantic state.
- Give icon-only controls tooltips and meaningful accessible text.
- Do not make hover, animation, or pointer coordinates required for understanding or operating the page.
- Keep target sizes and contrast consistent with the Godot editor theme.

## Localization

- Every visible label, tooltip, empty state, loading state, and error message is localized through the plugin locale files.
- Avoid assembling translated sentences from fragments. Prefer complete messages with explicit placeholders.
- Use smart word wrapping for prose and test German or Russian expansion together with Chinese, Japanese, and Korean layouts.
- Buttons must retain the action verb; shorten supporting copy before truncating the action.

## Scene And Script Responsibilities

- `.tscn` scenes own semantic control names, ordinary containers, base margins, separation, and initial visibility.
- Tab scripts own model rendering, signals, editor scale, breakpoints, dynamic rows, tooltips, and theme values that must come from the editor.
- Model projection services own state normalization and presentation-ready facts; view scripts should not infer behavior by matching translated text.
- Dock root code owns cross-tab coordination only. Page-specific layout remains inside the page scene and controller.

## Acceptance Matrix

Material UI changes should cover these dimensions in automated contracts or editor evidence:

| Dimension | Minimum cases |
|---|---|
| Width | `280`, `360`, `560`, and a wide layout |
| Scale | `1`, `1.5`, and `2` when scale-sensitive geometry changes |
| Language | English, a long Latin/Cyrillic locale, and a CJK locale |
| State | Idle, loading, success, error, rate limited, and empty |
| Theme and input | Light/dark-compatible theme values and keyboard focus |

Acceptance requires no overlap, no page-level horizontal scrolling, no color-only state, complete localized actions, and continued access to every feature already exposed by the affected surface.

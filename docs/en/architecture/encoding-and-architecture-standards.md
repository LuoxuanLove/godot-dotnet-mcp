# Encoding and Architecture Standards

This document is a hard rule set for `godot-dotnet-mcp`. Every `must` and `must not` item here is enforced by `scripts/validate_refactor_guardrails.ps1`.

---

## 1. Scope and Enforcement Level

- Scope: `godot-dotnet-mcp` only.
- Enforcement level: immediate hard block, with no grace period.
- Compatibility policy: destructive refactors are allowed. After replacement, remove the old implementation and do not keep a compatibility layer.

---

## 2. Layer Boundary Matrix

Allowed dependency directions:

```text
plugin composition -> plugin runtime -> tools domain
plugin composition -> plugin presenters/ui
```

Forbidden dependency directions:

- `tools/*` must not depend on `plugin/*` in reverse.
- `plugin runtime` must not depend on `ui/*` in reverse.
- Do not bypass collaborator injection with string method names or global singletons across layers.

---

## 3. Injection and Wiring Rules

Must:

- Use typed context or explicit parameter injection.
- Keep the composition root responsible only for object assembly and lifecycle wiring, not business branching.
- Make `configure()` idempotent and support `dispose` or `reset` to release references.

Must not:

- `configure(callbacks: Dictionary)`.
- Rely on arbitrary-key callback dictionaries in the main path.
- Return large cross-domain dictionaries from contexts or factories as if they were the source of truth.

---

## 4. Size Thresholds

Hard limits by responsibility layer:

- `plugin.gd`, `plugin/runtime/mcp_http_server.gd`: `<= 360` lines.
- `plugin/runtime/*service*.gd`: `<= 320` lines.
- `plugin/*coordinator*.gd`: `<= 260` lines.
- `ui/*tab*.gd`: `<= 420` lines.
- `tools/*/catalog.gd`:
  - `get_tools` function `<= 120` lines.
  - If over the limit, convert it into a static data source with a stable read entry point.
- Any single GDScript function: `<= 90` lines, except data-table functions, which still follow the catalog rule.
- Any GDScript file public function count: `<= 28`.
- New `*context*.gd` files must be tiny:
  - single file `<= 28` lines.
  - fields only, with at most a very small helper section.

---

## 5. Micro Shell Files

Allowed micro shell files, `<= 8` lines, are limited to:

- `tools/*/executor.gd` bridge entry files.
- Explicitly whitelisted stable re-export entries.

Must not:

- Split out many semantically empty shell files just to dodge file limits.
- Hide real behavior dispatch inside shell files.

---

## 6. Anti-Pattern Ban

Forbidden:

- Dual-path implementations where both old and new paths stay reachable.
- Compatibility wrappers, aliases, and long-lived transition helpers.
- Cross-layer direct access to mutable internal state fields.
- String method callbacks, such as `call("method_name")`, as the main path.
- Keeping outdated code around with the idea of deleting it later.

Required:

- Delete the old entry, helper, and test path immediately after replacement.
- Add contract tests in the same batch as structural changes. Long-term test debt is not allowed.

---

## 7. External Protocol and Tool Interface Strategy

- External MCP tool names and protocol payload shapes may change when the new design is better.
- When an external shape changes, update all of these in the same batch:
  - the protocol source of truth, so docs and code stay aligned
  - contract tests
  - the matching change note under `docs/`

---

## 8. Guardrails and Debt Baseline

Guardrail scripts must hard block:

- new `callbacks: Dictionary` injection signatures
- new large dictionary assembly entry points
- file and function limit overages
- excessive micro shell files
- known anti-pattern regressions

Legacy debt baseline rules:

- the baseline may only go down, never up
- when a cleanup batch removes one debt item, lower the baseline too
- do not hide new coupling by changing the threshold

---

## 9. Execution Order Requirements

Each batch must follow this order:

1. Confirm the request, scope, risk, and validation criteria.
2. Implement the refactor and remove outdated code.
3. Update docs and protocol notes.
4. Run guardrails and contract tests.
5. Record the validation result and remaining risk.

---

## 10. Violation Handling

- Any change that violates this standard must not be merged.
- If an emergency fix needs a temporary exception, restore the hard rule in the same batch and do not defer it.

---

## 11. Legacy Debt Baseline

Current retained legacy debt baseline:

- `callbacks: Dictionary` residue:
  - the runtime main path is already clean, and new residue is blocked by guardrails.
- Large dictionary assembly residue:
  - the plugin composition layer main path is already clean, and new residue is blocked by guardrails.
- Large file residue, still being reduced:
  - `plugin/runtime/mcp_runtime_command_service.gd` (`331` lines, threshold `320`)
  - `plugin/runtime/user_tool_maintenance_service.gd` (`418` lines, threshold `320`)
  - multiple `tools/*/catalog.gd:get_tools`

This debt may only decrease. It must not increase, and it must not be moved into a new structure of the same kind.

---

## 12. Execution Order Requirements

Execute in this order, without skipping or expanding scope:

1. Clear runtime callback dictionaries.
2. Remove dictionary usage from the composition layer.
3. Reduce the HTTP composition layer load.
4. Split the large UI files.
5. Move catalog static data out of the file.
6. Delete all corresponding old implementations and compatibility paths.

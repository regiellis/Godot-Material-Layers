# Known issues

The remaining trade-offs and limitations in the addon, kept so nobody re-derives them. Everything
that was cleanly fixable from the 2026-07-22 audit has been fixed; what is left below is either a
deliberate design decision or outside the addon's control.

Status as of 2026-07-22, Godot 4.7.1-rc, addon version 0.9.0.
Run `.\test\run-tests.ps1` to verify: **207 checks, 0 failing**.

Fixed on this branch, listed so this file is not mistaken for the full picture: CRLF checkouts
destroying the shader macros; helper functions failing to compile; the `BENT_NORMAL` token tables
disagreeing; `LAYER_BELOW_TEX_*` / `LAYER_BELOW_MASK_*` ordering; the parser dropping global
`const`s, `#define`s, `struct`s, `instance uniform`s, array uniforms and `render_mode`; sampler
dedup baking compile-time textures into the shader; missing-base-layer shader spew; the
`SETUP_LAYER_*` re-expansion that made missing-table tokens fail silently; the `SETUP_VARYINGS`
ghost machinery and dead `get_fragment_macros`; the vertex stage having no texture-mask blend path;
mask textures pinned to raw `UV`; cross-layer identifier accumulation shadowing include-provided
names; all-or-nothing uniform sync; and the vestigial `use_as_overlay`. See the git history.

Also investigated and closed without a change: uniform defaults referencing a layer `const` were
listed as un-renamed, but Godot rejects `uniform float x = SOME_CONST;` outright ("Expected constant
expression"), so the input cannot reach the generator.

---

## Design limitations

- **Helper functions cannot use layer tokens.** `LAYER_OUT_*` and friends exist only inside
  `fragment()` / `vertex()`, so a helper referencing them does not compile. Only those two bodies go
  through token substitution; helpers would need struct parameters threaded through, which is a
  redesign, not a fix.
- **A custom `light()` function is dropped**, with a `push_warning` naming the layer. Supporting it
  would mean deciding how N layers' light functions compose, which is the same design problem as
  `render_mode` but harder.
- **Layers sharing a texture cost one sampler slot each.** The deliberate price of removing sampler
  dedup: correctness of texture swaps won over slot count. Only relevant if a very deep stack
  approaches driver sampler limits on the Compatibility renderer.
- **`group_uniforms` is dropped.** Cosmetic only: the LayerStack inspector hides shader parameters,
  so carried-through groups would decorate uniforms nobody sees.

## Environment quirks

- **An open Shader Editor tab can shadow the generated shader's disk save.** Observed once while
  driving the editor: with the generated `.gdshader` open in a tab, an auto-generate recompile
  updated the rendered material but the file on disk kept the previous content despite a fresh
  mtime, until a later recompile restored parity. The in-memory shader is always correct, and the
  headless golden check in `run-tests.ps1` is unaffected; just avoid trusting the on-disk generated
  shader mid-session while it is open in a tab.
- **`plugin.cfg` cannot declare an engine minimum.** Godot's editor-plugin config has no
  `compatibility_minimum` field, so the 4.5+ requirement (generated shaders write
  `BENT_NORMAL_MAP`) is documented in the README instead of enforced at install time.

---

## Checked and found correct

Recorded so the next pass does not re-investigate:

- The real example stack (`examples/vcol-heightblend/`, three layers with a height-blend
  vertex-colour mask material) compiles cleanly through every change on this branch, and is
  verified on every full `run-tests.ps1` run.
- Uniform values propagate live after `compile()` without a recompile, per edited material,
  including texture swaps, mask UV controls, and values reverted to their shader default.
- Layers reference their assigned materials (live-link, a deliberate fork change): editing the
  asset updates every stack using it, and Godot's Make Unique gives a per-stack copy when wanted.
  Stacks saved under the old duplicate-on-assign design still load; their embedded copies simply
  have no `resource_path`.
- Two layers may declare uniforms, samplers, helper functions, consts or structs with the same
  name; namespacing handles all of them, including struct-typed locals sharing a name across
  layers. Renaming is scoped per layer, so include-provided names another layer happens to declare
  locally are left alone.
- A token missing from the substitution tables is a loud compile error, not a silent default.
- Statements that write built-in outputs (`ALBEDO = ...`) are stripped correctly. A local whose
  name merely *starts* with an output name (`AOamount`, `EMISSIONtint`) survives, because the
  statement text begins with its type. A bare reassignment such as `AOamount = 1.0;` on its own
  line is still untested and remains a theoretical risk.
- Control flow (`for`, `if/else`), comments containing `;` and braces, and commented-out code are
  all handled correctly by the statement splitter.
- `varying` declarations survive, including across the vertex and fragment stages.
- All three blend paths work: texture masks via `l_mixFragment` in fragment and `l_mixVertex` in
  vertex, mask materials by writing `RESULT_*` straight to `finalFragment` / `finalVertex`.
- Null entries in the `layers` array become real `MaterialLayer` instances, and an active layer
  with no Surface Material is skipped with a warning rather than breaking the build.

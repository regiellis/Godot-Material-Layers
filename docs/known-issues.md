# Known issues

The remaining trade-offs and limitations in the addon, kept so nobody re-derives them. Everything
that was cleanly fixable from the 2026-07-22 audit has been fixed; what is left below is either a
deliberate design decision or outside the addon's control.

Status as of 2026-07-22, Godot 4.7.1-rc, addon version 0.9.0.
Run `.\test\run-tests.ps1` to verify: **211 checks, 0 failing**.

Fixed on this branch, listed so this file is not mistaken for the full picture: CRLF checkouts
destroying the shader macros; helper functions failing to compile; the `BENT_NORMAL` token tables
disagreeing; `LAYER_BELOW_TEX_*` / `LAYER_BELOW_MASK_*` ordering; the parser dropping global
`const`s, `#define`s, `struct`s, `instance uniform`s, array uniforms and `render_mode`; sampler
dedup baking compile-time textures into the shader; missing-base-layer shader spew; the
`SETUP_LAYER_*` re-expansion that made missing-table tokens fail silently; the `SETUP_VARYINGS`
ghost machinery and dead `get_fragment_macros`; the vertex stage having no texture-mask blend path;
mask textures pinned to raw `UV`; cross-layer identifier accumulation shadowing include-provided
names; all-or-nothing uniform sync; the vestigial `use_as_overlay`; `light()` being dropped
entirely (the base layer's now carries through, base-wins like `render_mode`, and upper layers
warn); and the missing engine-version floor (the plugin now `push_error`s at enable time below
Godot 4.5, since `plugin.cfg` has no compatibility field). See the git history.

Also investigated and closed without a change:

- Uniform defaults referencing a layer `const`: Godot rejects `uniform float x = SOME_CONST;`
  outright ("Expected constant expression"), so the input cannot reach the generator.
- Helper functions referencing layer tokens: `SETUP_LAYER_*` declares the tokens as `fragment()` /
  `vertex()` locals, so a helper referencing one fails the standalone compile ("Unknown identifier
  in expression") before it can ever be assigned to a stack. The merged shader simply has the same
  scoping rules as the authoring shader.

---

## Design limitations

- **Non-base layers' `light()` functions are ignored** (with a warning). Composing N light
  functions has no meaningful answer, so `light()` is base-wins like `render_mode`. If per-layer
  lighting ever matters, the masks would have to be recomputed or carried into `light()` via
  varyings, which is a redesign.
- **Layers sharing a texture cost one sampler slot each.** The deliberate price of removing sampler
  dedup: correctness of texture swaps won over slot count. With auto-generate in place, a safe
  re-dedup (recompile when the texture grouping changes) is now possible; not worth the recompile
  hitch on texture swaps until a real stack approaches driver sampler limits on the Compatibility
  renderer.
- **`group_uniforms` is dropped.** Cosmetic only: the LayerStack inspector hides shader parameters,
  so carried-through groups would decorate uniforms nobody sees.

## Environment quirks

- **An open Shader Editor tab can shadow the generated shader's disk save.** Observed once while
  driving the editor: with the generated `.gdshader` open in a tab, an auto-generate recompile
  updated the rendered material but the file on disk kept the previous content despite a fresh
  mtime, until a later recompile restored parity. The in-memory shader is always correct, and the
  headless golden check in `run-tests.ps1` is unaffected; just avoid trusting the on-disk generated
  shader mid-session while it is open in a tab.

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

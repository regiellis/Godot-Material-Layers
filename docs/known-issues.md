# Known issues

Minor open trade-offs in the addon, kept so nobody re-derives them. Every majority defect found in
the 2026-07-22 audit has been fixed; the suite is fully green.

Status as of 2026-07-22, Godot 4.7.1-rc, addon version 0.9.0.
Run `.\test\run-tests.ps1` to verify: **175 checks, 0 failing**.

Fixed on this branch, listed so this file is not mistaken for the full picture: CRLF checkouts
destroying the shader macros; helper functions failing to compile; the `BENT_NORMAL` token tables
disagreeing; `LAYER_BELOW_TEX_*` / `LAYER_BELOW_MASK_*` referencing `finalLayerData` before it was
declared; the parser dropping global `const`s, `#define`s, `struct`s, `instance uniform`s, array
uniforms and `render_mode`; sampler dedup baking compile-time textures into the shader; and a
missing base layer emitting a broken shader instead of a clear error. See the git history.

---

## Smaller things

- **Dead code.** `get_fragment_macros` is never called. `l_mixVertex` in `layer_lib.gdshaderinc` is
  never called, because the vertex stage has no texture-mask blend path at all: `blend_vertex_block`
  only seeds `finalVertex` at slot 0.
- **`get_global_macros` matches a macro that does not exist.** It searches for `SETUP_VARYINGS`,
  which is defined nowhere in the addon. If a user did define it, it would be emitted at global scope
  *and* left in the fragment body by the macro lifter, producing a duplicate.
- **`SETUP_LAYER_FRAGMENT` is re-expanded into every generated shader**, declaring roughly 70 locals
  that are dead once the real tokens have been rewritten to struct fields. Harmless, but it also means
  a token missing from the substitution tables compiles silently against a constant instead of
  erroring, which is how the `BENT_NORMAL` mismatch survived.
- **Layers sharing a texture now cost one sampler slot each.** The deliberate price of removing
  sampler dedup: a stack whose layers reuse the same texture declares one sampler uniform per layer.
  Only relevant if a very deep stack approaches driver sampler limits on the Compatibility renderer.
- **Texture masks always sample at raw `UV`.** `mask_texture_sample` hardcodes it, so a mask texture
  cannot be scaled, offset, or driven by UV2. `l_getChannel` takes a `uv` parameter it never uses.
- **Helper functions cannot use layer tokens.** `LAYER_OUT_*` and friends are locals inside
  `fragment()`, so a helper referencing them does not compile. Only `fragment()` and `vertex()` bodies
  go through token substitution.
- **A custom `light()` function is dropped** (with a `push_warning` naming the layer). Supporting it
  would mean deciding how N layers' light functions compose, which is the same design problem as
  `render_mode` but harder.
- **`group_uniforms` is silently dropped.** Cosmetic only: uniforms lose their inspector grouping,
  and the LayerStack inspector hides shader parameters anyway.
- **An open Shader Editor tab can shadow the generated shader's disk save.** Observed once while
  driving the editor: with `rockGroundMossStack.gdshader` open in a Shader Editor tab, an
  auto-generate recompile updated the rendered material but the file on disk kept the previous
  content despite a fresh mtime, until a later recompile restored parity. The in-memory shader is
  always correct, and the headless golden check in `run-tests.ps1` is unaffected; just avoid
  trusting the on-disk generated shader mid-session while it is open in a tab.
- **`use_as_overlay` is vestigial.** `SurfaceMaterial.use_as_overlay` only forces `mask_active = false`
  in `material_layer.gd`; nothing in code generation reads it.
- **`plugin.cfg` declares no `compatibility_minimum`.** `FRAGMENT_OUTPUTS` writes `BENT_NORMAL_MAP`,
  which needs Godot 4.5 or newer, so installing on 4.4 fails at shader compile with no useful hint.
- **Uniform sync is O(all uniforms) per edit.** `update_uniforms` nulls every `shader_parameter/*` on
  the stack and re-copies all of them on every `changed` signal, so a slider drag rewrites the whole
  set.
- **Identifier lists accumulate across layers.** `all_identifiers` and `vertex_identifiers` are never
  cleared between slots in `_generate_code`, so layer N's body is rewritten using layers 0..N's
  identifiers under layer N's own prefix. Benign in the common case, but an identifier that must stay
  global (one from an `#include`) is renamed and breaks if an earlier layer happened to declare the
  same name.
- **Uniform hints and defaults are never renamed.** A uniform default referencing a layer const
  (`uniform float x = SCALE;`) keeps the raw name and breaks; only statement bodies, helpers, consts
  and structs go through identifier renaming.

---

## Checked and found correct

Recorded so the next pass does not re-investigate:

- The real example stack (`examples/vcol-heightblend/`, three layers with a height-blend
  vertex-colour mask material) compiles cleanly through every change on this branch, and is now
  verified on every full `run-tests.ps1` run.
- Uniform values propagate live after `compile()` without a recompile, including a texture swap on a
  layer whose texture was shared with another layer at Generate time.
- Layers reference their assigned materials (live-link, a deliberate fork change): editing the
  asset updates every stack using it, and Godot's Make Unique gives a per-stack copy when wanted.
  Stacks saved under the old duplicate-on-assign design still load; their embedded copies simply
  have no `resource_path`.
- Two layers may declare uniforms, samplers, helper functions, consts or structs with the same name;
  namespacing handles all of them, including struct-typed locals sharing a name across layers.
- Statements that write built-in outputs (`ALBEDO = ...`) are stripped correctly. A local whose name
  merely *starts* with an output name (`AOamount`, `EMISSIONtint`) survives, because the statement
  text begins with its type. A bare reassignment such as `AOamount = 1.0;` on its own line is still
  untested and remains a theoretical risk.
- Control flow (`for`, `if/else`), comments containing `;` and braces, and commented-out code are all
  handled correctly by the statement splitter.
- `varying` declarations survive, including across the vertex and fragment stages.
- Both blend paths work: texture masks via `l_mixFragment`, mask materials by writing `RESULT_*`
  straight to `finalFragment`.
- Null entries in the `layers` array become real `MaterialLayer` instances, and an active layer with
  no Surface Material is skipped with a warning rather than breaking the build.

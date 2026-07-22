# Known issues

Open defects in the addon. Every entry is reproduced by a failing test in `test/tests/cases/`, or by
an explicit command.

Status as of 2026-07-22, Godot 4.7.1-rc, addon version 0.9.0.
Run `.\test\run-tests.ps1` to see the current state: **149 checks, 7 failing**.

Already fixed on this branch, kept here only so the list is not mistaken for the full picture:
CRLF checkouts destroying the shader macros, helper functions failing to compile, the
`BENT_NORMAL` token tables disagreeing, and `LAYER_BELOW_TEX_*` / `LAYER_BELOW_MASK_*` referencing
`finalLayerData` before it was declared. See the git history for those changes.

---

## 1. The parser drops most global shader constructs

**Severity: high, and undocumented. Each of these silently vanishes.**

The generator rebuilds the global section only from constructs it recognises: `#include`, `uniform`,
`global uniform`, `varying`, and helper functions. Anything else in a layer shader's global scope is
discarded, and any reference to it becomes an undeclared identifier.

Confirmed dropped:

| Construct | Example | Result |
| --- | --- | --- |
| global `const` | `const float SCALE = 2.0;` | undeclared identifier |
| `#define` | `#define DOUBLE(x) ((x)*2.0)` | undeclared identifier |
| `struct` | `struct Pair { float a; };` | undeclared type |
| `instance uniform` | `instance uniform float w;` | dropped, `parse_uniforms` matches only `uniform ` |
| `render_mode` | `render_mode unshaded;` | dropped, output is always plain `shader_type spatial;` |
| array uniform | `uniform vec4 palette[4];` | identifier captured as `palette[4]`, then used as a regex character class |

The array case is the nastiest: `parse_uniforms` takes `head_tokens[2]` as the identifier, which for
an array is `palette[4]`, and `prefix_vertex_fragment` compiles that straight into a regex where
`[4]` is a character class.

`render_mode` is the one worth deciding first, because it is not a parser limitation so much as a
design question: a generated shader blends N layers, and there is no obvious correct answer for
whose `render_mode` wins.

**Fix direction:** either extend the parser to carry these through, or reject them at compile time
with a clear error. Silently dropping them is the worst option. Whichever is chosen, the README's
authoring rules need to state what a layer shader may contain.

**Tests:** `test_shader_features.gd` (6 failures).

---

## 2. Sampler deduplication bakes in the textures present at compile time

**Severity: medium.**

`dedup_samplers` compares texture RIDs across layers and, when two layers point at the same texture,
deletes the second layer's sampler uniform and rewrites its references to the first. That is a sound
size optimisation, but it is keyed on the texture assigned *at the moment Generate was pressed*.

Assign a different texture to the second layer afterwards and there is no uniform left to receive
it. The layer keeps rendering the first layer's texture until the user presses Generate again, with
no indication anything is wrong. `_rebuild_uniform_maps()` on project load does not re-run dedup, so
`copy_uniform_values` writes to a uniform that no longer exists and the write is silently ignored.

**Fix direction:** either drop the optimisation, or re-run dedup on texture change, or keep
per-layer uniforms and dedup only the sampler *bindings*.

**Tests:** `test_resources.test_shared_texture_is_deduplicated`.

---

## 3. A stack with no base layer emits a broken shader

**Severity: medium.**

`_generate_code` skips any slot whose surface shader is null (`continue`). When the base layer is
empty, slot 0 is skipped, so nothing ever declares `finalFragment` or `finalVertex`, and the layers
above emit `vertexMaterial vertex_1_out = finalVertex;` against an undeclared name.

Pressing Generate on a half-configured stack, which is the normal way to build one, produces a wall
of shader errors rather than a message saying the base layer is required.

**Fix direction:** validate before generating and `push_error` with a clear message, or seed the
defaults when slot 0 is absent.

**Tests:** `test_codegen.test_missing_base_layer` (currently passes, because it only asserts the
result is not silently wrong; tighten it when this is fixed).

---

## 4. Smaller things

- **Dead code.** `get_fragment_macros` and `prefix_vertex_samplers` are never called.
  `_base_layer_initialized`, `_layers_initialized` and `_compiled` are never read. `l_mixVertex` in
  `layer_lib.gdshaderinc` is never called, because the vertex stage has no texture-mask blend path at
  all: `blend_vertex_block` only seeds `finalVertex` at slot 0.
- **`get_global_macros` matches a macro that does not exist.** It searches for `SETUP_VARYINGS`,
  which is defined nowhere in the addon. If a user did define it, it would be emitted at global scope
  *and* left in the fragment body by the macro lifter, producing a duplicate.
- **`SETUP_LAYER_FRAGMENT` is re-expanded into every generated shader**, declaring roughly 70 locals
  that are dead once the real tokens have been rewritten to struct fields. Harmless, but it also means
  a token missing from the substitution tables compiles silently against a constant instead of
  erroring, which is how the `BENT_NORMAL` mismatch survived.
- **Texture masks always sample at raw `UV`.** `mask_texture_sample` hardcodes it, so a mask texture
  cannot be scaled, offset, or driven by UV2. `l_getChannel` takes a `uv` parameter it never uses.
- **Helper functions cannot use layer tokens.** `LAYER_OUT_*` and friends are locals inside
  `fragment()`, so a helper referencing them does not compile. Only `fragment()` and `vertex()` bodies
  go through token substitution.
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

---

## Checked and found correct

Recorded so the next pass does not re-investigate:

- The real example stack (`examples/material-layers-vcol-heightblend-example.zip`, three layers with a
  height-blend vertex-colour mask material) compiles cleanly, and its generated shader is byte
  identical before and after the fixes on this branch once line endings are ignored.
- Uniform values propagate live after `compile()` without a recompile.
- Layers duplicate their assigned materials, so editing a layer never writes back to the source
  resource on disk, and two layers assigned the same material stay independent.
- Two layers may declare uniforms, samplers, or helper functions with the same name; namespacing
  handles it.
- Statements that write built-in outputs (`ALBEDO = ...`) are stripped correctly. A local whose name
  merely *starts* with an output name (`AOamount`, `EMISSIONtint`) survives, because the statement
  text begins with its type. A bare reassignment such as `AOamount = 1.0;` on its own line is still
  untested and remains a theoretical risk.
- Control flow (`for`, `if/else`), comments containing `;` and braces, and commented-out code are all
  handled correctly by the statement splitter.
- `varying` declarations survive, including across the vertex and fragment stages.
- Both blend paths work: texture masks via `l_mixFragment`, mask materials by writing `RESULT_*`
  straight to `finalFragment`.
- Null entries in the `layers` array become real `MaterialLayer` instances.

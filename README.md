# GDHPR — Godot High Performance Rendering

A drop-in Godot 4 addon that makes 3D scenes look better and run faster with a
few clicks: **quality presets**, **automatic optimization** (draw-call batching,
auto-LOD, light budgets), **art-directed lighting rigs**, **PBR material presets**,
sane scene setup — plus a **visual scripting editor** that compiles to real
GDScript.

Everything is packaged as a standard Godot addon (`addons/gdhpr/` + `plugin.cfg`),
so it installs by copying one folder and ticking a checkbox. No build step.

```
addons/gdhpr/
├── plugin.cfg            editor plugin manifest
├── plugin.gd             EditorPlugin entry point
├── gdhpr.gd              public API facade (class GDHPR)
├── core/                 config resource, presets, environment/viewport applier
├── geometry/             mesh cleanup, merge, collision, stats, decimator
├── optimize/             batcher, LOD generator, light budget, optimizer
├── lighting/             sky presets, lighting rigs
├── materials/            PBR preset library
├── scene/                GDHPRWorld node, orbit camera
├── blueprint/            visual scripting (graph, compiler, GraphEdit UI)
└── editor/               the GDHPR dock
```

## Requirements

- Godot **4.3 or newer** (developed and verified against **4.7.2**).
- Forward+ renderer recommended; Mobile works (presets auto-cap themselves).

## Install

1. Copy `addons/gdhpr/` into your project's `addons/` folder.
2. **Project → Project Settings → Plugins → enable "GDHPR"**.
3. A **GDHPR** dock appears (right side), plus two `Tools → GDHPR` menu items.

Or just open this repository as a project — the plugin is already enabled and
`demo/demo.tscn` is the main scene.

## 60-second start

**Editor:** open a 3D scene → GDHPR dock → pick a quality + scene look →
**Quick Setup**. Then **Optimize Scene** and check the report.

**Code:**

```gdscript
func _ready() -> void:
    # One call: environment, sky, viewport quality, shadows.
    GDHPR.apply(GDHPR.archetype_config("outdoor", "high"), self)

    # One call: a full lighting rig.
    GDHPR.rig("golden", self)

    # One call: batching + auto-LOD + light budget, with a report.
    print(GDHPROptimizer.format_report(GDHPR.optimize(self)))
```

**One node:** add `GDHPRWorld` to a 3D scene and pick a quality and look. It
configures environment, rig and camera at runtime, and is inert in the editor
(open a scene, nothing changes behind your back).

## Quality presets

| | Low | Medium | High | Ultra |
|---|---|---|---|---|
| MSAA | off | 2× | 2× | 4× |
| TAA / FXAA | FXAA | TAA+FXAA | TAA+FXAA | TAA+FXAA |
| Render scale | 0.80 | 0.90 | 1.0 | 1.0 |
| SSAO / SSIL | off | SSAO | SSAO+SSIL | SSAO+SSIL |
| SSR / SDFGI | off | off | SSR | SSR+SDFGI |
| Volumetric fog | off | off | light | full |
| Shadow atlas | 2048 (16-bit) | 2048 | 4096 | 4096 |
| Glow | off | subtle | on | strong |
| Mesh LOD bias | 1.8 | 1.2 | 1.0 | 0.7 |

`GDHPRPresets.from_quality(GDHPRConfig.Quality.HIGH)` returns a fully populated
`GDHPRConfig` resource you can inspect, tweak, save, and reuse.

Scene looks: `outdoor`, `indoor`, `night`, `neon`, `product` — they retune sky,
fog, exposure, AO and the default lighting rig.

## Optimization

- **Draw-call batching** (`GDHPRBatcher`) — identical meshes + materials are
  collapsed into `MultiMeshInstance3D`s. In the demo: 36 crates + 40 draw calls
  → **5 draw calls**. Only leaf, unscripted, non-skinned, non-LOD instances are
  touched, and world transforms are preserved exactly.
- **Automatic LOD** (`GDHPRLOD` + `GDHPRDecimator`) — meshes above a triangle
  threshold get decimated copies driven by `visibility_range_*`; the last step
  stops casting shadows. The demo's heavy props drop from **16,512 → 1,312
  triangles** at distance.
- **Light budget** (`GDHPRLightManager`) — keeps the N most important lights
  casting shadows and fades distant lights out. Original flags are restored when
  a light leaves the budget.
- **Geometry toolkit** (`GDHPRGeometry`) — vertex welding + cache-ordered
  indices (`optimize`), mesh merging, lightmap UV2 unwrap, trimesh/convex
  collision generation, scene statistics.

All destructive operations go through the editor undo stack.

## Lighting

`GDHPRLightingRig.build(mood, parent)` creates a plain `Node3D` with ordinary
lights named `Key`/`Fill`/`Rim`/`Accent`/`Practical_*` — tweak them like any
other node. Moods: Studio, Outdoor Day, Golden Hour, Indoor Warm, Night, Neon,
Product.

`GDHPRSky.make(preset)` builds procedural skies (no HDRIs needed) for Studio,
Outdoor, Golden Hour, Dusk, Night, Neon, and a cheap Plain sky. Fog colour is
matched to the sky horizon automatically.

## Materials

`GDHPRMaterialLibrary.preset("car_paint")` — 18 presets: `metal`,
`brushed_metal`, `gold`, `concrete`, `asphalt`, `marble`, `wood`, `fabric`,
`glass`, `plastic`, `rubber`, `ceramic`, `emissive`, `car_paint`, `snow`,
`water`, `foliage`, `clay`.

Each one is a `StandardMaterial3D` with tuned metallic/roughness/clearcoat and a
**procedurally generated normal-detail map** (`NoiseTexture2D`), so grey-boxed
scenes read as real surfaces without importing a single texture. Helpers:
`make_triplanar(mat, scale)` for UV-less level geometry and
`add_detail(mat, frequency, strength)` to add bump.

## Visual scripting → GDScript

GDHPR dock → **Blueprint** tab. Connect flow ports left to right, and plug value
ports into inputs.

| Category | Nodes |
|---|---|
| Event | `On Ready`, `On Process`, `On Action Pressed`, `Function` (custom function, 3 typed args + return type), `Signal`, `On Signal` |
| Flow | `Print`, `Branch (If)`, `Set Variable`, `Call Method`, `Call Function`, `Set Property`, `Wait`, `Return`, `Emit Signal`, `Connect Signal`, `Array Add` |
| Loop | `For Loop` (range From→To), `For Each` (over an array), `While Loop`, each with an `After` continuation, plus `Break` / `Continue` |
| Value | `Number`, `Text`, `Boolean`, `Vector3`, `Array` (literal), `Array Size`, `Array Get`, `Get Variable`, `Math`, `Compare`, `Random Number`, `Delta`, `Position`, and any `Call Function` node's Value port |

Function arguments and return values are typed (`func total(xs: Array, scale: float) -> int:`).
`On Signal` generates `_on_<signal>(...)` and, when its connect target is not
empty, wires itself up from `_ready` (merged into an existing `On Ready` body if
there is one). `Connect Signal` covers the explicit case.

Graphs save as `.tres` (`GDHPRBlueprintGraph`) and **Generate GDScript** emits
plain GDScript that has **no GDHPR dependency**:

```gdscript
# Generated by GDHPR Blueprint (LoopsAndFunctions).
extends Node3D

var n = 0.0

func greet(who):
	print(who)

func answer():
	return 42.0

func _ready() -> void:
	greet("Buffy")
	n = 0.0
	for i in range(0.0, 3.0):
		print(i)
	while (n < 3.0):
		print("loop")
		n = (n + 1.0)
	print("done")

func _process(delta: float) -> void:
	print(answer())
```

The compiler reports problems instead of silently producing broken code:
undefined `Call Function` targets, duplicate function names, `Return` outside a
function or returning a value from a `void` function, `Break`/`Continue` outside
a loop, unused `Delta` outside `On Process`. Duplicate definitions are skipped so
the output still parses. It is a one-file compiler
(`blueprint/gdhpr_blueprint_compiler.gd`), so new node types are a definition
entry plus a case.

Not there yet: typed script variables (variables stay `Variant`), untyped signal
arguments, dictionary nodes, and `match`/switch. The generated code is plain
GDScript, so it can be extended by hand afterwards.

## API at a glance

| Call | Purpose |
|---|---|
| `GDHPR.apply(cfg, root)` | environment, sky, viewport, shadows |
| `GDHPR.optimize(root, cfg)` | batching + LOD + light budget, returns report |
| `GDHPR.setup(root, quality, archetype)` | all of the above in one call |
| `GDHPR.rig("golden", parent)` | lighting rig |
| `GDHPR.material("marble")` | material preset |
| `GDHPR.report(root)` | scene summary string |
| `GDHPRApplier.apply_project_settings(cfg)` | debanding, occlusion culling, shadow filter quality |
| `GDHPRGeometry.optimize/merge/add_collision/unwrap_lightmap` | mesh work |
| `GDHPRDecimator.simplify(mesh, 0.4)` | decimated copy of any mesh |
| `GDHPRBlueprintCompiler.compile(graph)` | graph → GDScript source |

## About the implementation language

The addon is written in **GDScript**, Godot's built-in Python-like language,
with the same module-per-concern layout you'd use in Python.

The alternative was a C GDExtension. That cannot be "directly usable in Godot":
it ships as a compiled shared library per platform (Windows, Linux, macOS,
Android, iOS, Web), so every user would need a matching toolchain and build
step. GDScript is interpreted by the engine itself, so copying the folder is
enough — which was the explicit requirement here. If you want the hot loops
(decimation, visibility culling) in C, a `gdextension` module that the addon
uses only when its binaries are present is the clean follow-up; the GDScript
implementations are structured to be swapped out for it.

## Verification

Checked with the real engine (Godot 4.7.2 headless, in this repository):

- Whole project imports with **zero script errors** and the editor plugin loads.
- `demo/demo.tscn` runs, reports `Draw calls: 40 → 5` and
  `2 LOD chains: 16,512 → 1,312 triangles`.
- Batcher, LOD generator, decimator, geometry helpers, all 18 material presets,
  `GDHPRWorld`, `GDHPRLightManager`, `GDHPR.setup()` and the blueprint editor all
  instantiate and run.
- Blueprint compiler output was written to disk, parsed by Godot, instantiated
  and executed: branches, variables, method calls, wait, value nodes,
  `for`/`while`/`for each` loops, custom functions with typed arguments and
  return types, function calls used as expressions, array literals/`append`/index
  access, and custom signals (declaration, auto-connected `On Signal` handler,
  `emit_signal` actually firing it). Warning paths checked too: duplicate
  function, undefined call, value returned from a `void` function.

Not verified here: visual appearance on a GPU (this environment is headless), and
the dock's interactive behaviour beyond instantiating cleanly.

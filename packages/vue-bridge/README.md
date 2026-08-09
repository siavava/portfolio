# vue-bridge

Effect-wrapped PureScript bindings to Vue's composition API: `Ref`,
`Computed`, a reactive `Set`, `watch`, lifecycle hooks, and rAF helpers.
Everything must be called synchronously from a component's `setup()` body —
Effects are thunks, so PureScript setup composables satisfy Vue's context
rules naturally.

Local workspace package of the portfolio today; extractable to the npm /
PureScript registry later (the FFI is self-contained plain JS with a peer
dependency on `vue`).

```purescript
import Vue (Ref, onMounted, ref, watchGetter, writeRef)
```

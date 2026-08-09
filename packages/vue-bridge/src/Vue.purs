-- | ## Vue
-- |
-- | Effect-wrapped bindings to Vue's composition API — the reactive bridge
-- | PureScript composables and store cores reach the framework through.
-- | Everything here must be called synchronously from a component's
-- | `setup()` body, exactly like the TypeScript equivalents.
module Vue
  ( ReactiveSet
  , Computed
  , Ref
  , cancelFrame
  , computed
  , reactiveSet
  , ref
  , shallowRef
  , onBeforeUnmount
  , onMounted
  , onUnmounted
  , class Readable
  , read
  , requestFrame
  , setAdd
  , setClear
  , setDelete
  , setHas
  , watchGetter
  , watchRef
  , write
  ) where

import Prelude

import Effect (Effect)
import Effect.Uncurried (EffectFn1, EffectFn2, mkEffectFn1, mkEffectFn2, runEffectFn1, runEffectFn2)

-- | A `Ref<a>` from Vue.
foreign import data Ref :: Type -> Type

-- | A `ComputedRef<a>` from Vue.
foreign import data Computed :: Type -> Type

-- | A `shallowReactive(new Set<a>())` from Vue.
foreign import data ReactiveSet :: Type -> Type

foreign import refImpl :: forall a. EffectFn1 a (Ref a)
foreign import shallowRefImpl :: forall a. EffectFn1 a (Ref a)
foreign import reactiveSetImpl :: forall a. Effect (ReactiveSet a)
foreign import setAddImpl :: forall a. EffectFn2 (ReactiveSet a) a Unit
foreign import setDeleteImpl :: forall a. EffectFn2 (ReactiveSet a) a Unit
foreign import setHasImpl :: forall a. EffectFn2 (ReactiveSet a) a Boolean
foreign import setClearImpl :: forall a. EffectFn1 (ReactiveSet a) Unit
foreign import readRefImpl :: forall a. EffectFn1 (Ref a) a
foreign import writeRefImpl :: forall a. EffectFn2 (Ref a) a Unit
foreign import computedImpl :: forall a. EffectFn1 (Effect a) (Computed a)
foreign import readComputedImpl :: forall a. EffectFn1 (Computed a) a
foreign import watchRefImpl :: forall a. EffectFn2 (Ref a) (EffectFn1 a Unit) (Effect Unit)
foreign import onMountedImpl :: EffectFn1 (Effect Unit) Unit
foreign import onBeforeUnmountImpl :: EffectFn1 (Effect Unit) Unit
foreign import onUnmountedImpl :: EffectFn1 (Effect Unit) Unit
foreign import watchGetterImpl :: forall a. EffectFn2 (Effect a) (EffectFn2 a a Unit) (Effect Unit)
foreign import requestFrameImpl :: EffectFn1 (Effect Unit) Int
foreign import cancelFrameImpl :: EffectFn1 Int Unit

ref :: forall a. a -> Effect (Ref a)
ref = runEffectFn1 refImpl

shallowRef :: forall a. a -> Effect (Ref a)
shallowRef = runEffectFn1 shallowRefImpl

reactiveSet :: forall a. Effect (ReactiveSet a)
reactiveSet = reactiveSetImpl

setAdd :: forall a. ReactiveSet a -> a -> Effect Unit
setAdd = runEffectFn2 setAddImpl

setDelete :: forall a. ReactiveSet a -> a -> Effect Unit
setDelete = runEffectFn2 setDeleteImpl

setHas :: forall a. ReactiveSet a -> a -> Effect Boolean
setHas = runEffectFn2 setHasImpl

setClear :: forall a. ReactiveSet a -> Effect Unit
setClear = runEffectFn1 setClearImpl

-- | One `read` for every reactive cell — refs and computeds alike.
class Readable box where
  read :: forall a. box a -> Effect a

instance Readable Ref where
  read = runEffectFn1 readRefImpl

instance Readable Computed where
  read = runEffectFn1 readComputedImpl

-- | Only refs are writable; computeds are read-only by type.
write :: forall a. Ref a -> a -> Effect Unit
write = runEffectFn2 writeRefImpl

computed :: forall a. Effect a -> Effect (Computed a)
computed = runEffectFn1 computedImpl

-- | Watch a ref; returns the stop handle.
watchRef :: forall a. Ref a -> (a -> Effect Unit) -> Effect (Effect Unit)
watchRef source callback = runEffectFn2 watchRefImpl source (mkEffectFn1 callback)

onMounted :: Effect Unit -> Effect Unit
onMounted = runEffectFn1 onMountedImpl

onBeforeUnmount :: Effect Unit -> Effect Unit
onBeforeUnmount = runEffectFn1 onBeforeUnmountImpl

onUnmounted :: Effect Unit -> Effect Unit
onUnmounted = runEffectFn1 onUnmountedImpl

-- | Watch an arbitrary getter; the callback receives (value, previous).
-- | Returns the stop handle.
watchGetter :: forall a. Effect a -> (a -> a -> Effect Unit) -> Effect (Effect Unit)
watchGetter source callback = runEffectFn2 watchGetterImpl source (mkEffectFn2 callback)

requestFrame :: Effect Unit -> Effect Int
requestFrame = runEffectFn1 requestFrameImpl

cancelFrame :: Int -> Effect Unit
cancelFrame = runEffectFn1 cancelFrameImpl

-- | ## Socket
-- |
-- | The shared WebSocket connection to the metrics backend — the same
-- | connection pattern the blog uses. Handles auto-reconnect (in the
-- | vueuse FFI), message queuing while disconnected, and scope-based
-- | routing of incoming messages. The singleton lives in FFI module
-- | state; `app/composables/metrics/useSocket.ts` is the hand-adapted
-- | shim exposing `useSocket` and the `Scope` enum to TypeScript.
module App.Composables.Metrics.Socket
  ( Scope(..)
  , SocketBindings
  , WsData
  , scopeKey
  , useSocketCore
  ) where

import Prelude

import App.Composables.Metrics.ApiRoute (useWebSocketRoute)
import Data.Array (filter, snoc)
import Data.Foldable (find, for_, sequence_)
import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, toMaybe)
import Effect (Effect)
import Effect.Ref as Ref
import Effect.Uncurried
  ( EffectFn1
  , EffectFn2
  , EffectFn3
  , mkEffectFn1
  , mkEffectFn2
  , runEffectFn1
  , runEffectFn2
  , runEffectFn3
  )
import Vue (Computed, Ref, computed, read)

-- | A parsed WebSocket message payload (`Record<string, unknown>`).
foreign import data WsData :: Type

-- | The vueuse `useWebSocket` surface the core drives.
type WsHandle =
  { status :: Ref String
  , send :: EffectFn1 String Boolean
  , open :: Effect Unit
  }

foreign import connectImpl :: EffectFn3 String (Effect Unit) (EffectFn1 String Unit) WsHandle
foreign import parseRouteImpl :: EffectFn2 String (EffectFn2 String WsData Unit) Unit
foreign import stringifyImpl :: WsData -> String
foreign import isClientImpl :: Effect Boolean
foreign import instanceImpl :: Effect (Nullable SocketBindings)
foreign import setInstanceImpl :: EffectFn1 SocketBindings Unit

-- | ## Scope
-- |
-- | WebSocket message scopes on the shared backend's unified `/connect`
-- | endpoint. Incoming messages carry a `scope` field that routes them
-- | to the matching handler; outgoing messages declare the subsystem
-- | they address. The portfolio only sends the watch scope; the
-- | standalone status app consumes the rest.
data Scope = Watch

-- | The wire value of a scope — the `scope` field on messages.
scopeKey :: Scope -> String
scopeKey Watch = "watch"

type ScopeEntry = { key :: String, handler :: EffectFn1 WsData Unit }

type SocketBindings =
  { send :: EffectFn1 WsData Unit
  , onScope :: EffectFn2 String (EffectFn1 WsData Unit) Unit
  , onConnect :: EffectFn1 (Effect Unit) Unit
  , isConnected :: Computed Boolean
  }

createWs :: Effect SocketBindings
createWs = do
  base <- useWebSocketRoute
  let wsUrl = base <> "/connect"
  pending <- Ref.new ([] :: Array String)
  scopeHandlers <- Ref.new ([] :: Array ScopeEntry)
  connectHandlers <- Ref.new ([] :: Array (Effect Unit))
  handleRef <- Ref.new (Nothing :: Maybe WsHandle)

  let
    flushPending = Ref.read handleRef >>= case _ of
      Nothing -> pure unit
      Just handle -> do
        messages <- Ref.read pending
        Ref.write [] pending
        for_ messages \msg -> void (runEffectFn1 handle.send msg)

    onConnected = do
      flushPending
      handlers <- Ref.read connectHandlers
      sequence_ handlers

    routeMessage = mkEffectFn2 \scope wsData -> do
      entries <- Ref.read scopeHandlers
      case find (\entry -> entry.key == scope) entries of
        Just entry -> runEffectFn1 entry.handler wsData
        Nothing -> pure unit

    onMessage raw = runEffectFn2 parseRouteImpl raw routeMessage

  handle <- runEffectFn3 connectImpl wsUrl onConnected (mkEffectFn1 onMessage)
  Ref.write (Just handle) handleRef

  client <- isClientImpl
  when client handle.open

  isConnected <- computed (map (_ == "OPEN") (read handle.status))

  let
    send payload = do
      let msg = stringifyImpl payload
      connected <- read isConnected
      sent <- if connected then runEffectFn1 handle.send msg else pure false
      unless sent (Ref.modify_ (flip snoc msg) pending)

    onScope scope handler = Ref.modify_
      (\entries -> snoc (filter (\entry -> entry.key /= scope) entries) { key: scope, handler })
      scopeHandlers

    onConnect handler = Ref.modify_ (flip snoc handler) connectHandlers

  pure
    { send: mkEffectFn1 send
    , onScope: mkEffectFn2 onScope
    , onConnect: mkEffectFn1 onConnect
    , isConnected
    }

-- | ## useSocketCore
-- |
-- | Singleton core behind `useSocket` — creates the shared connection on
-- | first call and returns the same bindings ever after.
-- |
-- | ### Returns
-- |
-- | | Field | Type | Description |
-- | | --- | --- | --- |
-- | | `send` | `(payload) => void` | Send a JSON payload, queued if disconnected |
-- | | `onScope` | `(scope, handler) => void` | Register a handler for a `Scope` |
-- | | `onConnect` | `(handler) => void` | Register a callback fired on each (re)connect |
-- | | `isConnected` | `ComputedRef<boolean>` | Reactive connection status |
useSocketCore :: Effect SocketBindings
useSocketCore = do
  existing <- toMaybe <$> instanceImpl
  case existing of
    Just bindings -> pure bindings
    Nothing -> do
      bindings <- createWs
      runEffectFn1 setInstanceImpl bindings
      pure bindings

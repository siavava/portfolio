/**
 * ## useConnections
 *
 * Links the bio copy to the interest map: bio targets announce node names
 * on hover, map nodes register themselves, and the map lights the lineage
 * to each known name. The core lives in `Connections.purs`.
 */
export const useConnections = defineStore("connections", useConnectionsCore)

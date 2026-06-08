extends Node
## Placeholder for the "remove ads + cosmetic deck back" purchase. Exposes the
## same interface a real store plugin will use in v2 — a synchronous "always
## succeeds" stub so the rest of the game can check entitlement and trigger
## purchases against the final call shape before any store SDK is wired in.

var _ads_removed: bool = false


func has_removed_ads() -> bool:
	return _ads_removed


## Simulates a successful purchase. Real implementation will be async
## (store callback/receipt validation); this stub resolves immediately.
func purchase_remove_ads() -> bool:
	_ads_removed = true
	return true

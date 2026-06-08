extends Node
## Placeholder for rewarded-ad placements (revive, double gold). Exposes the
## same interface a real AdMob wrapper will use in v2 — synchronous "always
## succeeds" stubs here so the rest of the game can be built and tested
## against the real shape of these calls before any ad SDK is wired in.

const REVIVE_HP_FRACTION: float = 0.5

var _revive_used_this_run: bool = false
var _double_gold_used_this_run: bool = false


## Called by GameRoot when a fresh run begins, so a previous run's ad usage
## doesn't carry over.
func reset_for_new_run() -> void:
	_revive_used_this_run = false
	_double_gold_used_this_run = false


func can_offer_revive() -> bool:
	return not _revive_used_this_run


## Simulates watching a rewarded ad to revive once per run. Real implementation
## will be async (ad load/show callbacks); this stub resolves immediately so
## callers can be written against the final synchronous-looking call shape
## and only the body needs to change later.
func watch_ad_to_revive() -> bool:
	if not can_offer_revive():
		return false
	_revive_used_this_run = true
	return true


func can_offer_double_gold() -> bool:
	return not _double_gold_used_this_run


func watch_ad_to_double_gold() -> bool:
	if not can_offer_double_gold():
		return false
	_double_gold_used_this_run = true
	return true

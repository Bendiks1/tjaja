extends GutTest

var stub: Node

func before_each() -> void:
	stub = load("res://state/ad_stub.gd").new()

func after_each() -> void:
	stub.free()


func test_revive_can_be_used_once_per_run() -> void:
	assert_true(stub.can_offer_revive())
	assert_true(stub.watch_ad_to_revive())
	assert_false(stub.can_offer_revive())
	assert_false(stub.watch_ad_to_revive(), "a second revive in the same run should be refused")


func test_double_gold_can_be_used_once_per_run() -> void:
	assert_true(stub.watch_ad_to_double_gold())
	assert_false(stub.can_offer_double_gold())


func test_reset_for_new_run_clears_usage() -> void:
	stub.watch_ad_to_revive()
	stub.watch_ad_to_double_gold()
	stub.reset_for_new_run()

	assert_true(stub.can_offer_revive())
	assert_true(stub.can_offer_double_gold())

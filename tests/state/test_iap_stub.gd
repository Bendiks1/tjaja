extends GutTest

var stub: Node

func before_each() -> void:
	stub = load("res://state/iap_stub.gd").new()

func after_each() -> void:
	stub.free()


func test_starts_without_ads_removed() -> void:
	assert_false(stub.has_removed_ads())


func test_purchase_grants_the_entitlement() -> void:
	assert_true(stub.purchase_remove_ads())
	assert_true(stub.has_removed_ads())

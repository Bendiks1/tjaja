extends GutTest
## Smoke test confirming GUT is wired up correctly. Run with:
##   godot --headless -s addons/gut/gut_cmdln.gd

func test_gut_is_running() -> void:
	assert_true(true, "GUT should be able to run a trivial assertion")

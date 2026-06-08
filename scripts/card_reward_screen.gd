extends Control
## Controller for the post-combat reward screen: offers a few cards generated
## by CardRewardGenerator, lets the player tap one to add to their deck (or
## skip), then reports the choice for the run-loop controller to act on.
## Reuses CardView for display — a reward offer is just cards to look at and
## tap, the same interaction CardView already provides in the hand.

signal card_chosen(card: CardDefinition)
signal skipped

const CardViewScene: PackedScene = preload("res://scenes/components/card_view.tscn")

@onready var _offer_row: HBoxContainer = %OfferRow
@onready var _skip_button: Button = %SkipButton

var _offer: Array[CardDefinition] = []


func _ready() -> void:
	_skip_button.pressed.connect(_on_skip_pressed)


## Generates an offer of `count` cards from `pool` using `rng_seed` and
## displays them. Picking is final — tapping a card immediately resolves
## the screen, mirroring the "tap to commit" feel used elsewhere.
func show_offer(pool: Array[CardDefinition], rng_seed: int, count: int = 3) -> void:
	_offer = CardRewardGenerator.generate(pool, RNGStream.new(rng_seed), count)
	_rebuild_offer_row()


func _rebuild_offer_row() -> void:
	for child in _offer_row.get_children():
		child.queue_free()

	for i in range(_offer.size()):
		var view: CardView = CardViewScene.instantiate()
		_offer_row.add_child(view)
		view.setup(CardInstance.new(i, _offer[i]), true)
		view.tapped.connect(_on_card_tapped)


func _on_card_tapped(instance_id: int) -> void:
	if instance_id < 0 or instance_id >= _offer.size():
		return
	card_chosen.emit(_offer[instance_id])


func _on_skip_pressed() -> void:
	skipped.emit()

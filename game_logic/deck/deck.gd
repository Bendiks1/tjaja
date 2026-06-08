class_name Deck
extends RefCounted
## Owns the four piles (draw/hand/discard/exhaust) and the rules for moving
## cards between them. All randomness (draws, reshuffles) goes through the
## RNGStream passed in by the caller, so combat stays reproducible from a seed.

var draw_pile: Array[CardInstance] = []
var hand: Array[CardInstance] = []
var discard_pile: Array[CardInstance] = []
var exhaust_pile: Array[CardInstance] = []

var _next_instance_id: int = 0


## Wraps a definition as a new physical copy with a fresh, stable instance_id.
## Centralizing this here means the id counter is the only thing that needs
## saving to keep ids stable across a save/resume cycle.
func instantiate(definition: CardDefinition) -> CardInstance:
	var instance := CardInstance.new(_next_instance_id, definition)
	_next_instance_id += 1
	return instance


func get_next_instance_id() -> int:
	return _next_instance_id


func set_next_instance_id(value: int) -> void:
	_next_instance_id = value


## Builds the starting deck: each definition becomes one fresh CardInstance,
## all starting in the draw pile, then shuffled.
func setup_starting_deck(definitions: Array[CardDefinition], rng: RNGStream) -> void:
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	for definition in definitions:
		draw_pile.append(instantiate(definition))
	rng.shuffle(draw_pile)


## Moves up to `count` cards from draw pile to hand, reshuffling the discard
## pile into the draw pile mid-draw if it runs out (matches Slay the Spire).
## Returns the cards that were actually drawn — fewer than `count` only if
## both piles are simultaneously exhausted.
func draw(count: int, rng: RNGStream) -> Array[CardInstance]:
	var drawn: Array[CardInstance] = []
	for i in range(count):
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			shuffle_discard_into_draw(rng)
		var card: CardInstance = draw_pile.pop_back()
		hand.append(card)
		drawn.append(card)
	return drawn


func shuffle_discard_into_draw(rng: RNGStream) -> void:
	draw_pile.append_array(discard_pile)
	discard_pile.clear()
	rng.shuffle(draw_pile)


## Discards the entire hand at end of turn.
func discard_hand() -> void:
	discard_pile.append_array(hand)
	hand.clear()


## Removes a card from hand by instance id (e.g. when it's played) and returns
## it, or null if it isn't there. Caller decides whether it goes to discard or exhaust.
func remove_from_hand(instance_id: int) -> CardInstance:
	for i in range(hand.size()):
		if hand[i].instance_id == instance_id:
			return hand.pop_at(i)
	return null


func send_to_discard(card: CardInstance) -> void:
	discard_pile.append(card)


func send_to_exhaust(card: CardInstance) -> void:
	exhaust_pile.append(card)


## All cards currently owned by the deck across every pile — the full deck list
## shown on the deck-viewer screen.
func get_all_cards() -> Array[CardInstance]:
	var all_cards: Array[CardInstance] = []
	all_cards.append_array(draw_pile)
	all_cards.append_array(hand)
	all_cards.append_array(discard_pile)
	all_cards.append_array(exhaust_pile)
	return all_cards

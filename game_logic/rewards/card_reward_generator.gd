class_name CardRewardGenerator
extends RefCounted
## Picks the post-combat card choices offered to the player. Pure function of
## a card pool and a seeded RNGStream — same inputs always produce the same
## offer, so it slots into the deterministic-run guarantee like map generation.

## Returns up to `count` distinct cards drawn from `pool`, in a shuffled order.
## Fewer are returned only if the pool itself is smaller than `count`.
static func generate(pool: Array[CardDefinition], rng: RNGStream, count: int = 3) -> Array[CardDefinition]:
	var candidates: Array[CardDefinition] = pool.duplicate()
	rng.shuffle(candidates)
	return candidates.slice(0, min(count, candidates.size()))

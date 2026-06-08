class_name ActData
extends Resource
## Content definition for one act: how many map nodes it has and which enemies
## populate its combat/elite/boss encounters. The procedural map generator
## (game_logic/map, built in a later step) draws from these pools using the
## run's seeded RNGStream — nothing here is randomized at the data level.

@export var act_number: int = 1
@export var node_count: int = 15
@export var regular_enemies: Array[EnemyData] = []
@export var elite_enemies: Array[EnemyData] = []
@export var boss: EnemyData

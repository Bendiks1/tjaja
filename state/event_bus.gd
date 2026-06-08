extends Node
## Global signal hub. UI and screens connect here instead of referencing each other directly.
## Signals are added as each system (combat, map, rewards, ...) is built.

## Fired by the combat screen when an encounter resolves. The run-loop
## controller (built alongside the map/reward screens) listens for this to
## route to CardReward on victory or back to the run summary on defeat.
signal combat_finished(outcome: CombatState.Outcome)

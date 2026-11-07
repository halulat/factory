class_name MachineSimulator
extends RefCounted

## Advances machine behaviour one step. The recipe body itself is still a TODO;
## this class exists so FactoryManager's tick has a machine phase and the
## scheduling seam lives in one place instead of the manager.

var _store: MachineStore
var _active_machines: DenseIdSet


func _init(machine_store: MachineStore, active_machines: DenseIdSet) -> void:
	_store = machine_store
	_active_machines = active_machines


func tick(delta: float) -> void:
	for machine_id in _active_machines.ids:
		update_machine(machine_id, delta)


func update_machine(machine_id: int, delta: float) -> void:
	var recipe_id: int = _store.recipe_ids[machine_id]

	if recipe_id == MachineStore.EMPTY:
		return

	# TODO: consume inputs, advance progress, produce outputs.

extends Node

class_name Inventory

@export var light_attack_power: ElementalPower
@export var heavy_attack_power: ElementalPower
@export var passive_power: ElementalPower

var old_powers = []

func insert_new_power_resource(resource: ElementalPower):
	var new_light_attack = resource
	var new_heavy_attack = light_attack_power
	var new_passive = heavy_attack_power
	var removed_passive = passive_power
	
	print_debug("Poder adicionado:", resource.name)
	
	light_attack_power = new_light_attack
	heavy_attack_power = new_heavy_attack
	passive_power = new_passive
	
	old_powers.append(removed_passive)

class_name RobotData
extends Resource

@export var texture = Texture2D

@export var amount: int

@export var description: String
@export var cost: int
@export var costIncrease: float

@export_group ("Stats")
@export var size: int
@export var rate: float
@export var resourceReturn: float
@export var pollutionEffect: int

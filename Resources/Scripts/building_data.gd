class_name BuildingData
extends Resource

@export var buildingName: String

@export_group("Textures")
@export var texture: Texture2D
@export var UISprite: Texture2D

@export_group("PurchaseData")
@export var description: String
@export var unlockCost: Array[CostEntry] = []
@export var amount: int

@export_group("Stats")
@export var size: int = 1
@export var storage_capacity: int = 100
@export var process_amount: int = 10

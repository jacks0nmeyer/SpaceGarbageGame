class_name RobotData
extends Resource

@export var robotName: String

@export_group("Textures")
@export var texture: Texture2D
@export var UISprite: Texture2D

@export_group("PurchaseData")
@export var description: String
@export var unlockCost: Array[CostEntry] = []
@export var costIncrease: float
@export var amount: int

@export_group ("Stats")
@export var size: int
@export var productionRate: float
@export var resourceReturn: float
@export var pollutionEffect: float
@export var worksInWater: bool = true

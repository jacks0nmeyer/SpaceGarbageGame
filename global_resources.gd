extends Node
#Resources
#var junk:= 0:
var junk:= 1000: #testing
	set(new_value):
		if new_value > junk:
			var junkConversion = new_value-junk
			EarthGlobal.earthTrash -= junkConversion
			junk = new_value
		else:
			junk = new_value

func gotJunk(clickMultiplier):
	GlobalResources.junk += 1 * junkModifier * globalModifier * clickMultiplier


var scrap:= 0
func gotScrap():
	GlobalResources.scrap += 1 * scrapModifier * globalModifier


var plastic:= 0
func gotPlastic():
	GlobalResources.plastic += 1 * plasticModifier * globalModifier


var glass:= 0
func gotGlass():
	GlobalResources.glass += 1 * glassModifier * globalModifier

#modifiers
var globalModifier:= 1
var junkModifier:= 1
var scrapModifier:= 1
var plasticModifier:= 1
var glassModifier:= 1


#Progress
var totalSystemTrash 
var totalSystemPollution


	

extends Node

# Canonical lowercase resource string keys. Use these in script code in place
# of raw string literals so typos surface at edit time. `.tres` drop tables
# (ResourceEntry / CostEntry) keep plain strings — `GlobalResources` lowercases
# all inputs before indexing `player_resources`.

const JUNK := "junk"
const SCRAP := "scrap"
const PLASTIC := "plastic"
const GLASS := "glass"
const RESEARCH := "research"

const ALL: Array[String] = [JUNK, SCRAP, PLASTIC, GLASS, RESEARCH]

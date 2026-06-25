class_name ContractSet
extends Resource
## The authored campaign: an ordered, escalating list of contracts the Career
## hands out one at a time. Edit contract_set.tres. A seeded generator
## (mission_generator.md) can later replace this with the same Array[Contract]
## shape — the rest of the loop reads contracts, not how they were made.

@export var contracts: Array[Contract] = []

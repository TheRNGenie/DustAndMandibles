class_name CpuBudget
extends RefCounted
## How much of the team's shared resources a CPU teammate may spend: never more
## than its share of everything the team has had (starting stock plus earnings).
## One CPU among 4 team members gets 25%; a CPU partner in a 2-player game, 50%.


## A CPU's share of the team pool.
static func share(cpus: int, team_size: int) -> float:
	if team_size <= 0 or cpus <= 0:
		return 0.0
	return 1.0 / float(team_size)


## May a CPU that has already spent `spent` of a resource spend `cost` more,
## when the team has had `gained` of it in total?
static func may_spend(spent: int, cost: int, gained: int, cpu_share: float) -> bool:
	return cost >= 0 and spent + cost <= int(floor(float(gained) * cpu_share))


## Every resource in `cost` within budget.
static func may_spend_all(spent: Dictionary, cost: Dictionary, gained: Dictionary, cpu_share: float) -> bool:
	for res: StringName in cost:
		if not may_spend(int(spent.get(res, 0)), int(cost[res]), int(gained.get(res, 0)), cpu_share):
			return false
	return true

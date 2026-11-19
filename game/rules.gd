extends RefCounted

const CHARGE_TIME := 1.05
const GREEN := 0.68
const SHOT_CLOCK := 15.0
const WIN_SCORE := 11
const POINT_BUDGET := 400
const APTITUDES := {
	"height": Vector2(1.62,2.22), "weight": Vector2(58,132), "muscle": Vector2(0,100),
	"shot": Vector2(0,100), "defense": Vector2(0,100), "dribble": Vector2(0,100)
}
const CPU_TIERS := [
	{"label":"Fácil", "pace":0.74, "gap":1.65, "reaction":0.70, "steal":Vector2(2.6,4.0), "reach":0.44, "contest":0.48, "aim":0.58, "spread":0.13, "cpu_bonus":-0.15, "human_bonus":0.12, "green_bonus":0.047, "charge_time":1.28},
	{"label":"Normal", "pace":0.89, "gap":1.26, "reaction":0.42, "steal":Vector2(1.28,2.05), "reach":0.72, "contest":0.77, "aim":0.64, "spread":0.10, "cpu_bonus":-0.055, "human_bonus":0.045, "green_bonus":0.019, "charge_time":1.12},
	{"label":"Difícil", "pace":1.0, "gap":0.89, "reaction":0.20, "steal":Vector2(0.50,0.95), "reach":1.04, "contest":1.0, "aim":0.68, "spread":0.080, "cpu_bonus":0.0, "human_bonus":0.0, "green_bonus":0.0, "charge_time":1.05}
]

static func tension(score: Array[int]) -> bool:
	return maxi(score[0],score[1]) >= WIN_SCORE-2 and winner(score) < 0

static func aptitude_points(key: String, value: float) -> int:
	var limits: Vector2 = APTITUDES[key]
	return roundi(clampf(inverse_lerp(limits.x,limits.y,value),0.0,1.0)*100.0)

static func aptitude_value(key: String, points: int) -> float:
	var limits: Vector2 = APTITUDES[key]
	return snappedf(lerpf(limits.x,limits.y,clampi(points,0,100)/100.0),0.001)

static func spent_points(profile: Dictionary) -> int:
	var total := 0
	for key in APTITUDES:
		total += aptitude_points(key,profile[key])
	return total

static func fit_budget(profile: Dictionary) -> void:
	var total := spent_points(profile)
	if total <= POINT_BUDGET:
		return
	var used := 0
	var remainders: Array[Vector2i] = []
	var keys := APTITUDES.keys()
	for i in keys.size():
		var key: String = keys[i]
		var scaled := aptitude_points(key,profile[key])*POINT_BUDGET
		var whole := floori(float(scaled)/total)
		profile[key] = aptitude_value(key,whole)
		used += whole
		remainders.append(Vector2i(scaled%total,i))
	remainders.sort_custom(func(a: Vector2i,b: Vector2i): return a.x>b.x or (a.x==b.x and a.y<b.y))
	for n in POINT_BUDGET-used:
		var key: String = keys[remainders[n].y]
		profile[key] = aptitude_value(key,aptitude_points(key,profile[key])+1)

static func dunk_range(height: float, muscle: float) -> float:
	return clampf(1.96+(height-1.84)*0.83+muscle*0.0041,1.78,2.60)

static func block_lift(phase: float) -> float:
	var up := 0.30
	var arc := phase*0.5/up if phase < up else 0.5+(phase-up)*0.5/(1.0-up)
	return 0.79*maxf(0.0,sin(PI*arc))

static func shot_points(distance: float, arc: float) -> int:
	return 2 if distance >= arc else 1

static func winner(score: Array[int]) -> int:
	for i in 2:
		if score[i] >= WIN_SCORE and score[i] - score[1-i] >= 2:
			return i
	return -1

static func shot_probability(quality: float, skill: float, distance: float, contest: float, style: int) -> float:
	var range_tax := clampf((distance-1.3)/8.9, 0.0, 1.0)*0.27
	var archetype := 0.0
	if style == 1:
		archetype = 0.045 if distance > 4.5 else -0.015
	elif style == 2:
		archetype = 0.10 if distance < 2.45 else -0.08
	var timing := maxf(0.0,1.0-absf(quality-GREEN)*1.85)
	return clampf(0.08+skill*0.0022+timing*timing*0.82-range_tax-contest*0.32+archetype,0.045,0.99)

static func green_width(skill: float) -> float:
	return lerpf(0.055,0.104,clampf(skill/100.0,0.0,1.0))

static func pace(dribble: float, weight: float, carrying: bool, sprint: bool) -> float:
	var speed := 4.85 + (90.0-weight)*0.014
	if carrying:
		speed *= lerpf(0.72,0.96,dribble/100.0)
	return speed * (1.28 if sprint and carrying else 1.0)

static func steal_probability(defense: float, dribble: float, gap: float, angle: float) -> float:
	return clampf(0.24 + (defense-dribble)*0.0036 + (1.0-gap)*0.45 + angle*0.10,0.075,0.83)

static func trajectory(a: Vector3, rim: Vector3, arc: float, t: float) -> Vector3:
	return a.lerp(rim,t) + Vector3.UP*4.0*arc*t*(1.0-t)

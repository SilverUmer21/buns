extends Resource
## A small exact damped spring shared by all bun motion. Stable at any frame rate.
@export var frequency := 4.2
@export var damping := 0.30
@export var pull_frequency := 8.0
@export var minimum_height := 0.72
@export var maximum_height := 1.20
@export var lean_frequency := 4.4
@export var lean_damping := 0.38
@export var crest_frequency := 5.2
@export var crest_damping := 0.25
@export var limb_frequency := 3.7
@export var limb_damping := 0.30
@export var maximum_squeeze := 0.08

static func advance(value: float, velocity: float, target: float, hz: float, ratio: float, dt: float) -> Vector2:
    if dt <= 0.0:
        return Vector2(value, velocity)
    hz = maxf(hz, 0.001)
    ratio = clampf(ratio, 0.0, 1.0)
    var w := TAU * hz
    var offset := value - target
    var decay := exp(-ratio * w * dt)
    if ratio >= 0.999:
        var c := velocity + w * offset
        return Vector2(target + (offset + c * dt) * decay, (velocity - w * c * dt) * decay)
    var wd := w * sqrt(1.0 - ratio * ratio)
    var c := (velocity + ratio * w * offset) / wd
    var cosine := cos(wd * dt)
    var sine := sin(wd * dt)
    var position := decay * (offset * cosine + c * sine)
    var speed := decay * ((c * wd - ratio * w * offset) * cosine - (offset * wd + ratio * w * c) * sine)
    return Vector2(target + position, speed)

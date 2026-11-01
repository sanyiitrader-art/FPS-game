extends Node
## Roster and lobby/match configuration (autoload name: Session).
##
## This is pure game logic with no networking. On the host it is changed directly; on
## clients it is replaced by snapshots from the host through apply_dict(). It preloads the
## Config script (instead of using the autoload name) so it can run in headless tests.
##
## Rules implemented here (so every screen and the network layer agree):
##  - A match can start only when: at least 2 players, every player READY and, in TEAM
##    mode, every player assigned to a team and both teams non-empty.
##  - Changing map, mode, max players or team assignment resets everyone's READY, applied
##    once when the host closes the customize/team window (commit_config).
##  - Changing the duration or team names does not reset READY.
##  - Any change while a countdown runs cancels it. A stale countdown can never start a match.
##  - Nobody can join while a match is running.

const C = preload("res://game/autoload/config.gd")

signal roster_changed
signal config_changed
signal state_changed(new_state: int)
signal countdown_cancelled(reason: String)

enum State { MENU, LOBBY, COUNTDOWN, MATCH, RESULT }

var state: int = State.MENU
var is_host := false
var local_id := 0
## peer id (int) -> {id, name, avatar, ready, team, kills, deaths, host}
var players: Dictionary = {}
var map_id: String = C.DEFAULT_MAP
var mode: String = C.MODE_NORMAL
var duration: int = C.DEFAULT_DURATION
var max_players: int = C.MAX_PLAYERS
var team_names: Array[String] = ["Team A", "Team B"]
var config_rev := 0
## True while the host has the customize or team window open (no countdown may start).
var editing := false

var _ready_reset_pending := false


# ---- Session lifecycle ---------------------------------------------------------------

func reset_session() -> void:
	players.clear()
	is_host = false
	local_id = 0
	map_id = C.DEFAULT_MAP
	mode = C.MODE_NORMAL
	duration = C.DEFAULT_DURATION
	max_players = C.MAX_PLAYERS
	team_names.assign(C.DEFAULT_TEAM_NAMES)
	config_rev = 0
	editing = false
	_ready_reset_pending = false
	_set_state(State.MENU)
	roster_changed.emit()
	config_changed.emit()


## Starts a new lobby with the local player as host (peer id 1).
func create_host(host_name: String, avatar: int) -> void:
	reset_session()
	is_host = true
	local_id = 1
	players[1] = _make_player(1, host_name, avatar, true)
	_set_state(State.LOBBY)
	roster_changed.emit()


## After a match: back to the lobby with settings and teams kept, scores cleared,
## and everybody NOT READY.
func reset_after_match() -> void:
	for p in players.values():
		p["ready"] = false
		p["kills"] = 0
		p["deaths"] = 0
	editing = false
	_set_state(State.LOBBY)
	roster_changed.emit()


func _set_state(new_state: int) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(new_state)


# ---- Roster -------------------------------------------------------------------------------

func _make_player(id: int, pname: String, avatar: int, host: bool) -> Dictionary:
	return {
		"id": id,
		"name": pname,
		"avatar": avatar,
		"ready": false,
		"team": C.TEAM_NONE,
		"kills": 0,
		"deaths": 0,
		"host": host,
	}


func player_count() -> int:
	return players.size()


func has_player(id: int) -> bool:
	return players.has(id)


func get_player(id: int) -> Dictionary:
	return players.get(id, {})


func local_player() -> Dictionary:
	return get_player(local_id)


func host_id() -> int:
	for p in players.values():
		if p["host"]:
			return int(p["id"])
	return 0


## "<host name>'s game", shown on the discovery card.
func game_name() -> String:
	var host := get_player(host_id())
	return "%s's game" % String(host.get("name", "Host"))


## Player ids in a stable order (the host's id is 1, so the host comes first).
func sorted_ids() -> Array[int]:
	var ids: Array[int] = []
	for id in players.keys():
		ids.append(int(id))
	ids.sort()
	return ids


func is_full() -> bool:
	return players.size() >= max_players


## Adds a joining player. Returns the new entry, the existing one if already present,
## or an empty dictionary if the lobby is full or a match is running.
func add_player(id: int, pname: String, avatar: int) -> Dictionary:
	if players.has(id):
		return players[id]
	if state != State.LOBBY and state != State.COUNTDOWN:
		return {}
	if is_full():
		return {}
	var clean := C.sanitize_name(pname)
	if clean == "":
		clean = C.default_player_name()
	var entry := _make_player(id, _unique_name(clean), avatar, false)
	players[id] = entry
	_revalidate("player_joined")
	roster_changed.emit()
	return entry


func remove_player(id: int) -> void:
	if not players.erase(id):
		return
	_revalidate("player_left")
	roster_changed.emit()


func _unique_name(base: String) -> String:
	if not _name_taken(base):
		return base
	for n in range(2, 100):
		var suffix := " (%d)" % n
		var candidate := base.substr(0, maxi(1, C.MAX_NAME_LENGTH - suffix.length())) + suffix
		if not _name_taken(candidate):
			return candidate
	return base + str(randi() % 1000)


func _name_taken(candidate: String) -> bool:
	var wanted := candidate.to_lower()
	for p in players.values():
		if String(p["name"]).to_lower() == wanted:
			return true
	return false


# ---- Ready and countdown ---------------------------------------------------------------

func set_ready(id: int, value: bool) -> bool:
	if not players.has(id):
		return false
	if state != State.LOBBY and state != State.COUNTDOWN:
		return false
	var p: Dictionary = players[id]
	if p["ready"] == value:
		return false
	p["ready"] = value
	if not value:
		_revalidate("not_ready")
	roster_changed.emit()
	return true


func reset_all_ready() -> void:
	for p in players.values():
		p["ready"] = false
	cancel_countdown("ready_reset")
	roster_changed.emit()


## Returns "" if a match could start, otherwise a short code:
## "players", "unassigned", "team_empty" or "not_ready" (checked in that order).
func start_blocker() -> String:
	if players.size() < C.MIN_PLAYERS:
		return "players"
	if mode == C.MODE_TEAM:
		var counts := team_counts()
		if counts[2] > 0:
			return "unassigned"
		if counts[0] == 0 or counts[1] == 0:
			return "team_empty"
	for p in players.values():
		if not p["ready"]:
			return "not_ready"
	return ""


static func blocker_text(code: String) -> String:
	match code:
		"players":
			return "NEED AT LEAST 2 PLAYERS"
		"unassigned":
			return "ASSIGN ALL PLAYERS TO TEAMS"
		"team_empty":
			return "EACH TEAM NEEDS AT LEAST ONE PLAYER"
		"not_ready":
			return "WAITING FOR PLAYERS TO BE READY"
	return ""


func countdown_allowed() -> bool:
	return is_host and state == State.LOBBY and not editing and start_blocker() == ""


func begin_countdown() -> bool:
	if not countdown_allowed():
		return false
	_set_state(State.COUNTDOWN)
	return true


func cancel_countdown(reason: String) -> void:
	if state == State.COUNTDOWN:
		_set_state(State.LOBBY)
		countdown_cancelled.emit(reason)


## Called when the countdown timer ends. Starts the match only if the lobby is still
## exactly as it was when the countdown began; otherwise cancels it.
func finish_countdown() -> bool:
	if state != State.COUNTDOWN:
		return false
	if editing or start_blocker() != "":
		cancel_countdown("stale")
		return false
	_set_state(State.MATCH)
	return true


func _revalidate(reason: String) -> void:
	if state == State.COUNTDOWN and start_blocker() != "":
		cancel_countdown(reason)


# ---- Match configuration (host only; callers check is_host) ----------------------------

func set_map(id: String) -> bool:
	if not C.MAPS.has(id) or id == map_id:
		return false
	map_id = id
	_config_touched(true)
	return true


func set_mode(new_mode: String) -> bool:
	if not C.MODES.has(new_mode) or new_mode == mode:
		return false
	mode = new_mode
	_config_touched(true)
	return true


func set_duration(seconds: int) -> bool:
	var clean := C.clamp_duration(seconds)
	if clean == duration:
		return false
	duration = clean
	_config_touched(false)
	return true


## steps = +1 / -1 for one 30-second click.
func adjust_duration(steps: int) -> bool:
	return set_duration(duration + steps * C.DURATION_STEP)


func set_max_players(count: int) -> bool:
	var clean := clampi(count, maxi(C.MIN_PLAYERS, players.size()), C.MAX_PLAYERS)
	if clean == max_players:
		return false
	max_players = clean
	_config_touched(true)
	return true


func adjust_max_players(delta: int) -> bool:
	return set_max_players(max_players + delta)


func set_team_name(index: int, new_name: String) -> bool:
	if index < 0 or index > 1:
		return false
	var clean := C.sanitize_team_name(new_name, String(C.DEFAULT_TEAM_NAMES[index]))
	if clean == team_names[index]:
		return false
	team_names[index] = clean
	_config_touched(false)
	return true


func assign_team(id: int, team: int) -> bool:
	if not players.has(id) or team < C.TEAM_NONE or team > C.TEAM_B:
		return false
	var p: Dictionary = players[id]
	if p["team"] == team:
		return false
	p["team"] = team
	_config_touched(true)
	roster_changed.emit()
	return true


func _config_touched(resets_ready: bool) -> void:
	if resets_ready:
		_ready_reset_pending = true
	cancel_countdown("config_changed")
	config_changed.emit()


## Called when the customize or team window closes. Bumps the config revision and, if a
## fairness-relevant setting changed, sets every player back to NOT READY. Returns true
## if readiness was reset.
func commit_config() -> bool:
	var reset := _ready_reset_pending
	_ready_reset_pending = false
	config_rev += 1
	if reset:
		reset_all_ready()
	config_changed.emit()
	return reset


# ---- Teams -------------------------------------------------------------------------------------

## Returns [players in team A, players in team B, unassigned players].
func team_counts() -> Array[int]:
	var counts: Array[int] = [0, 0, 0]
	for p in players.values():
		var team: int = p["team"]
		if team == C.TEAM_A:
			counts[0] += 1
		elif team == C.TEAM_B:
			counts[1] += 1
		else:
			counts[2] += 1
	return counts


func players_in_team(team: int) -> Array[int]:
	var ids: Array[int] = []
	for id in sorted_ids():
		if int(players[id]["team"]) == team:
			ids.append(id)
	return ids


# ---- Scores ------------------------------------------------------------------------------------

func add_kill(id: int) -> void:
	if players.has(id):
		players[id]["kills"] = int(players[id]["kills"]) + 1


func add_death(id: int) -> void:
	if players.has(id):
		players[id]["deaths"] = int(players[id]["deaths"]) + 1


# ---- Snapshots (host -> clients) ----------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"state": state,
		"players": players.duplicate(true),
		"map": map_id,
		"mode": mode,
		"duration": duration,
		"max": max_players,
		"teams": [team_names[0], team_names[1]],
		"rev": config_rev,
	}


func apply_dict(d: Dictionary) -> void:
	var incoming: Dictionary = d.get("players", {})
	players = incoming.duplicate(true)
	var new_map := String(d.get("map", map_id))
	if C.MAPS.has(new_map):
		map_id = new_map
	var new_mode := String(d.get("mode", mode))
	if C.MODES.has(new_mode):
		mode = new_mode
	duration = C.clamp_duration(int(d.get("duration", duration)))
	max_players = clampi(int(d.get("max", max_players)), C.MIN_PLAYERS, C.MAX_PLAYERS)
	var teams: Array = d.get("teams", [])
	if teams.size() >= 2:
		team_names[0] = C.sanitize_team_name(String(teams[0]), String(C.DEFAULT_TEAM_NAMES[0]))
		team_names[1] = C.sanitize_team_name(String(teams[1]), String(C.DEFAULT_TEAM_NAMES[1]))
	config_rev = int(d.get("rev", config_rev))
	_set_state(int(d.get("state", state)))
	roster_changed.emit()
	config_changed.emit()
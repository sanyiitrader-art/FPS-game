extends RefCounted
## Logic tests for the lobby rules in session.gd and the text/duration helpers in config.gd.

const SessionScript = preload("res://game/autoload/session.gd")
const C = preload("res://game/autoload/config.gd")


func _lobby(host_name: String = "HOST") -> SessionScript:
	var session := SessionScript.new()
	session.create_host(host_name, 0)
	return session


func _lobby_with(count: int) -> SessionScript:
	var session := _lobby()
	for id in range(2, count + 1):
		session.add_player(id, "P%d" % id, 0)
	return session


func _ready_all(session: SessionScript) -> void:
	for id in session.players.keys():
		session.set_ready(id, true)


func test_create_host(t) -> void:
	var s := _lobby()
	t.equal(s.player_count(), 1, "host is the only player")
	t.equal(s.host_id(), 1, "host has id 1")
	t.equal(s.state, SessionScript.State.LOBBY, "lobby state")
	t.equal(s.game_name(), "HOST's game", "game name")
	s.free()


func test_capacity_limit(t) -> void:
	var s := _lobby()
	t.check(s.set_max_players(2), "max players can be set to 2")
	t.check(not s.add_player(2, "B", 0).is_empty(), "second player accepted")
	t.check(s.is_full(), "lobby is full")
	t.check(s.add_player(3, "C", 0).is_empty(), "third player rejected")
	t.equal(s.player_count(), 2, "roster size")
	s.free()


func test_max_players_never_below_roster(t) -> void:
	var s := _lobby_with(3)
	s.set_max_players(2)
	t.equal(s.max_players, 3, "cannot go below the number of joined players")
	t.check(not s.adjust_max_players(-1), "left arrow does nothing at the roster size")
	s.set_max_players(100)
	t.equal(s.max_players, 20, "cannot exceed 20")
	s.free()


func test_twenty_players(t) -> void:
	var s := _lobby_with(20)
	t.equal(s.player_count(), 20, "twenty players fit")
	t.check(s.add_player(21, "P21", 0).is_empty(), "twenty-first rejected")
	s.free()


func test_unique_names(t) -> void:
	var s := _lobby()
	s.add_player(2, "HOST", 0)
	t.equal(s.get_player(2)["name"], "HOST (2)", "duplicate name gets a suffix")
	s.add_player(3, "host", 0)
	t.check(String(s.get_player(3)["name"]).to_lower() != "host", "case-insensitive duplicate")
	s.free()


func test_sanitize_name(t) -> void:
	t.equal(C.sanitize_name("  A[B]  C "), "AB C", "brackets removed, spaces collapsed")
	t.equal(C.sanitize_name("x".repeat(30)).length(), 16, "length limited to 16")
	t.equal(C.sanitize_name("   "), "", "blank name is empty")
	t.equal(C.sanitize_name("A\nB"), "AB", "control characters removed")


func test_duration_helpers(t) -> void:
	t.equal(C.clamp_duration(10), 120, "minimum is 02:00")
	t.equal(C.clamp_duration(100), 120, "below minimum rounds up")
	t.equal(C.clamp_duration(5000), 1800, "maximum is 30:00")
	t.equal(C.clamp_duration(610), 600, "rounds to 30 second steps")
	t.equal(C.format_time(125), "02:05", "MM:SS format")
	t.equal(C.format_time(-5), "00:00", "never negative")


func test_duration_buttons(t) -> void:
	var s := _lobby()
	t.equal(s.duration, 600, "default duration")
	t.check(s.adjust_duration(1), "right arrow")
	t.equal(s.duration, 630, "plus 30 seconds")
	s.set_duration(120)
	t.check(not s.adjust_duration(-1), "left arrow at minimum does nothing")
	t.equal(s.duration, 120, "stays at 02:00")
	s.set_duration(1800)
	t.check(not s.adjust_duration(1), "right arrow at maximum does nothing")
	t.equal(s.duration, 1800, "stays at 30:00")
	s.free()


func test_start_blockers(t) -> void:
	var s := _lobby()
	t.equal(s.start_blocker(), "players", "a single player cannot start")
	s.add_player(2, "B", 0)
	t.equal(s.start_blocker(), "not_ready", "nobody ready")
	s.set_ready(1, true)
	t.equal(s.start_blocker(), "not_ready", "one player ready")
	s.set_ready(2, true)
	t.equal(s.start_blocker(), "", "everybody ready")
	t.equal(SessionScript.blocker_text("unassigned"), "ASSIGN ALL PLAYERS TO TEAMS", "message text")
	s.free()


func test_countdown_flow(t) -> void:
	var s := _lobby_with(2)
	_ready_all(s)
	t.check(s.begin_countdown(), "countdown starts when all ready")
	t.equal(s.state, SessionScript.State.COUNTDOWN, "countdown state")
	t.check(s.finish_countdown(), "countdown finishes")
	t.equal(s.state, SessionScript.State.MATCH, "match state")
	s.free()


func test_countdown_cancel_not_ready(t) -> void:
	var s := _lobby_with(2)
	_ready_all(s)
	s.begin_countdown()
	s.set_ready(2, false)
	t.equal(s.state, SessionScript.State.LOBBY, "going NOT READY cancels the countdown")
	s.free()


func test_countdown_cancel_on_join(t) -> void:
	var s := _lobby_with(2)
	_ready_all(s)
	s.begin_countdown()
	s.add_player(3, "C", 0)
	t.equal(s.state, SessionScript.State.LOBBY, "a new player cancels the countdown")
	t.equal(s.start_blocker(), "not_ready", "the new player must get ready")
	s.free()


func test_countdown_cancel_on_config(t) -> void:
	var s := _lobby_with(2)
	_ready_all(s)
	s.begin_countdown()
	s.set_duration(900)
	t.equal(s.state, SessionScript.State.LOBBY, "a settings change cancels the countdown")
	t.check(not s.commit_config(), "a duration change does not reset ready")
	t.equal(s.start_blocker(), "", "players are still ready")
	s.free()


func test_stale_countdown_never_starts(t) -> void:
	var s := _lobby_with(2)
	_ready_all(s)
	s.begin_countdown()
	s.players[2]["ready"] = false  # simulate a change that slipped past the checks
	t.check(not s.finish_countdown(), "stale countdown must not start the match")
	t.equal(s.state, SessionScript.State.LOBBY, "back to the lobby")
	s.free()


func test_editing_blocks_countdown(t) -> void:
	var s := _lobby_with(2)
	_ready_all(s)
	s.editing = true
	t.check(not s.begin_countdown(), "no countdown while the host is customizing")
	s.editing = false
	t.check(s.begin_countdown(), "countdown allowed afterwards")
	s.free()


func test_config_change_resets_ready(t) -> void:
	var s := _lobby_with(2)
	_ready_all(s)
	t.check(s.set_map("industrial"), "map changed")
	t.check(s.commit_config(), "closing the window resets ready")
	t.equal(s.start_blocker(), "not_ready", "everybody is NOT READY again")
	t.equal(s.config_rev, 1, "config revision increased")
	s.free()


func test_team_rules(t) -> void:
	var s := _lobby_with(2)
	_ready_all(s)
	s.set_mode(C.MODE_TEAM)
	t.equal(s.start_blocker(), "unassigned", "teams not assigned")
	s.assign_team(1, C.TEAM_A)
	t.equal(s.start_blocker(), "unassigned", "one player still unassigned")
	s.assign_team(2, C.TEAM_A)
	t.equal(s.start_blocker(), "team_empty", "team B has nobody")
	s.assign_team(2, C.TEAM_B)
	t.equal(s.start_blocker(), "", "both teams have a player")
	t.check(s.commit_config(), "mode and team changes reset ready")
	t.equal(s.start_blocker(), "not_ready", "everybody must ready up again")
	s.free()


func test_uneven_teams(t) -> void:
	var s := _lobby_with(20)
	s.set_mode(C.MODE_TEAM)
	var ids := s.sorted_ids()
	for i in ids.size():
		s.assign_team(ids[i], C.TEAM_A if i < 8 else C.TEAM_B)
	var counts := s.team_counts()
	t.equal(counts[0], 8, "8 players in team A")
	t.equal(counts[1], 12, "12 players in team B")
	t.equal(counts[2], 0, "nobody unassigned")
	_ready_all(s)
	t.equal(s.start_blocker(), "", "uneven teams may start")
	s.free()


func test_team_names(t) -> void:
	var s := _lobby()
	t.check(s.set_team_name(0, "Wolves"), "team A renamed")
	t.equal(s.team_names[0], "Wolves", "name stored")
	t.check(not s.set_team_name(1, "   "), "blank name keeps the default")
	t.equal(s.team_names[1], "Team B", "default team B name")
	s.free()


func test_remove_player(t) -> void:
	var s := _lobby_with(3)
	s.remove_player(2)
	t.equal(s.player_count(), 2, "player removed")
	s.remove_player(99)
	t.equal(s.player_count(), 2, "unknown id is ignored")
	s.free()


func test_no_join_during_match(t) -> void:
	var s := _lobby_with(2)
	_ready_all(s)
	s.begin_countdown()
	s.finish_countdown()
	t.check(s.add_player(3, "C", 0).is_empty(), "nobody can join a running match")
	s.free()


func test_reset_after_match(t) -> void:
	var s := _lobby_with(2)
	s.set_mode(C.MODE_TEAM)
	s.assign_team(1, C.TEAM_A)
	s.assign_team(2, C.TEAM_B)
	s.set_team_name(0, "Wolves")
	s.commit_config()
	_ready_all(s)
	s.begin_countdown()
	s.finish_countdown()
	s.add_kill(1)
	s.add_death(2)
	s.reset_after_match()
	t.equal(s.state, SessionScript.State.LOBBY, "back in the lobby")
	t.equal(s.start_blocker(), "not_ready", "everybody must press READY again")
	t.equal(s.get_player(1)["kills"], 0, "kills cleared")
	t.equal(s.get_player(2)["deaths"], 0, "deaths cleared")
	t.equal(s.mode, C.MODE_TEAM, "mode kept")
	t.equal(s.get_player(2)["team"], C.TEAM_B, "team assignment kept")
	t.equal(s.team_names[0], "Wolves", "team name kept")
	s.free()


func test_snapshot_roundtrip(t) -> void:
	var host := _lobby_with(3)
	host.set_mode(C.MODE_TEAM)
	host.assign_team(2, C.TEAM_B)
	host.set_team_name(0, "Wolves")
	host.set_map("industrial")
	host.set_duration(900)
	var client := SessionScript.new()
	client.apply_dict(host.to_dict())
	t.equal(client.player_count(), 3, "roster copied")
	t.equal(client.mode, C.MODE_TEAM, "mode copied")
	t.equal(client.map_id, "industrial", "map copied")
	t.equal(client.duration, 900, "duration copied")
	t.equal(client.team_names[0], "Wolves", "team name copied")
	t.equal(client.get_player(2)["team"], C.TEAM_B, "team assignment copied")
	host.free()
	client.free()
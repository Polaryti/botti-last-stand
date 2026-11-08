class_name FakeLeaderboard
extends FakeEpic

signal stats_interface_query_stats_callback(data: Dictionary)
signal stats_interface_ingest_stat_callback(data: Dictionary)
signal leaderboards_interface_query_leaderboard_ranks_callback(data: Dictionary)
signal leaderboards_interface_query_leaderboard_user_scores_callback(data: Dictionary)
var ingested := {}
var ingest_result := 0
var attempts: Array = []

func respond(callback: String, options: Object) -> void:
	call_deferred("emit_signal", callback, {"result_code": 0, "client_data": options.client_data})

func stats_interface_query_stats(options: Object) -> void:
	respond("stats_interface_query_stats_callback", options)

func stats_interface_copy_stat_by_name(_options: Object) -> Dictionary:
	return {"result_code": 18}

func stats_interface_ingest_stat(options: Object) -> void:
	attempts.append(options.stats.duplicate(true))
	if ingest_result != 0:
		call_deferred("emit_signal", "stats_interface_ingest_stat_callback", {"result_code": ingest_result, "client_data": options.client_data})
		return
	for stat: Dictionary in options.stats:
		ingested[stat["stat_name"]] = stat["ingest_amount"]
	respond("stats_interface_ingest_stat_callback", options)

func leaderboards_interface_query_leaderboard_ranks(options: Object) -> void:
	respond("leaderboards_interface_query_leaderboard_ranks_callback", options)

func leaderboards_interface_get_leaderboard_record_count(_options: Object) -> int:
	return 2

func leaderboards_interface_copy_leaderboard_record_by_index(options: Object) -> Dictionary:
	var index: int = options.leaderboard_record_index
	return {"result_code": 0, "record": {"user_id": "user%d" % index, "user_display_name": "Mara", "score": 10 if index == 0 else 50}}

func leaderboards_interface_query_leaderboard_user_scores(options: Object) -> void:
	respond("leaderboards_interface_query_leaderboard_user_scores_callback", options)

func leaderboards_interface_copy_leaderboard_user_score_by_user_id(options: Object) -> Dictionary:
	return {"result_code": 0, "user_score": {"score": 4 if str(options.stat_name).ends_with("PLAGUE_DOCTOR_PESTILENCE") else 0}}

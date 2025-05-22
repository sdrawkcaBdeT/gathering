extends Node
const BASE := "http://127.0.0.1:8000/v1"
const HDRS := [
	"Content-Type: application/json",
	"X-API-Key: local-dev-only"
]

@onready var http := HTTPRequest.new()

func _ready() -> void:
	add_child(http)
	http.request_completed.connect(_on_request_done)
	# pull config as soon as the game boots (agent_id hard-coded for now)
	http.request("%s/round_config?agent_id=17" % BASE, HDRS)

func _on_request_done(result:int, code:int, _hdrs:Array, body:PackedByteArray) -> void:
	if code != 200:
		push_error("Side-car HTTP %d" % code); return
	var cfg: Dictionary = JSON.parse_string(body.get_string_from_utf8()) as Dictionary
	get_tree().get_first_node_in_group("player").apply_config(cfg)

# -------------------------------------------------------------------------
# POST after the round ends
# -------------------------------------------------------------------------
func send_gather(path: PackedVector2Array, nodes_collected: int) -> void:
	# 1.  JSON-friendly path
	var path_arr: Array = []
	for p in path:
		path_arr.append([p.x, p.y])

	# 2.  Body
	var body := {
		"agent_id":        17,
		"zone_id":         3,
		"path":            path_arr,
		"nodes_collected": nodes_collected
	}

	# 3.  Fire POST with throw-away HTTPRequest
	var http2 := HTTPRequest.new()
	http2.pause_mode = Node.PAUSE_MODE_PROCESS
	add_child(http2)

	# bind(http2) passes the node as last param so we can free it later
	http2.request_completed.connect(_on_submit_done.bind(http2), CONNECT_ONE_SHOT)

	http2.request(
		"%s/submit_gather" % BASE,
		HDRS,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)
	print("POST body →", JSON.stringify(body))

# -------------------------------------------------------------------------
# Callback for the POST 
# -------------------------------------------------------------------------
func _on_submit_done(_result: int, code: int, _hdrs: Array,
					 body: PackedByteArray, http2: HTTPRequest) -> void:
	if code == 200:
		var res: Dictionary = JSON.parse_string(body.get_string_from_utf8())
		print("POST ok →", res)
	else:
		push_error("Submit error %d" % code)

	http2.queue_free()   # clean up the temporary request node

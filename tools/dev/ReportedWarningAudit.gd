extends SceneTree
## Snapshot-only diagnostic. Configure warning severities before engine startup.
## A normal SceneTree registers real autoloads before these scripts are reloaded.
const TARGETS := [
	"scenes/world/buildings/RoofOverlay.gd","scenes/world/buildings/DungeonRoof.gd",
	"scenes/world/buildings/CityBlockKit.gd","scenes/world/buildings/DungeonBuilding.gd",
	"core/systems/world/ChunkManager.gd","ui/screens/CityDevelopmentScreen.gd",
	"ui/widgets/library/LibraryBook.gd","ui/widgets/library/LibraryOpenBook.gd",
	"ui/widgets/library/LibraryRibbon.gd","ui/widgets/library/LibraryPagination.gd",
	"ui/screens/opening/OpeningPresentation.gd","core/systems/world/Level1Builder.gd",
	"scenes/world/bosses/BossBulldozerBrain.gd","core/systems/world/objectives/BreachSealObjective.gd",
]
const CATEGORIES := ["shadowed_variable_base_class","unused_private_class_variable","unused_parameter","shadowed_global_identifier","confusable_local_declaration","integer_division","redundant_await"]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var strict := true
	for category: String in CATEGORIES:
		strict = strict and int(ProjectSettings.get_setting("debug/gdscript/warnings/"+category)) == 2
	var failures := 0
	var rows: Array[Dictionary] = []
	for path: String in TARGETS:
		print("WARNING_AUDIT_BEGIN ",path)
		var script := load("res://"+path) as GDScript
		var result := script.reload(true) if script != null else ERR_CANT_OPEN
		if result != OK: failures += 1
		rows.append({"path":path,"reload_result":result,"source_sha256":FileAccess.get_sha256("res://"+path)})
		print("WARNING_AUDIT_END ",path," result=",result)
	var file := FileAccess.open(OS.get_environment("REPORTED_WARNING_AUDIT_OUT"),FileAccess.WRITE)
	if file == null:
		push_error("Cannot write warning audit report")
		quit(2)
		return
	file.store_string(JSON.stringify({"startup_severities_strict":strict,"warning_categories":CATEGORIES,"targets":rows,"failed_scripts":failures,"autoload_context":true,"limit":"Checks the reported categories in 14 scripts; does not inventory the human editor's complete warning panel."},"\t"))
	file.close()
	print("ReportedWarningAudit: targets=%d failed_scripts=%d strict=%s" % [TARGETS.size(),failures,strict])
	quit(1 if failures > 0 or not strict else 0)

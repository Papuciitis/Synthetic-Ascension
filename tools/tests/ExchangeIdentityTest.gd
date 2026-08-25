extends SceneTree

## Breaks if the Exchange loses controller-owned node paths, returns to five
## identical cards, or clips the action/search surface at 1280x720.

const CRITICAL_PATHS := [
	"Root/HBox/Left/Margin/VBox/Title",
	"Root/HBox/Left/Margin/VBox/Info",
	"Root/HBox/Left/Margin/VBox/Continue",
	"Root/HBox/Equipped/Margin/VBox/InventoryBar",
	"Root/HBox/Backpack/Margin/VBox/BagGrid",
	"Root/HBox/CartPanel/Margin/VBox/Grids/OfferBox/OfferGrid",
	"Root/HBox/CartPanel/Margin/VBox/Grids/DemandBox/DemandGrid",
	"Root/HBox/CartPanel/Margin/VBox/Buttons/BtnBarter",
	"Root/HBox/Vendor/Margin/VBox/VendorTools/Search",
	"Root/HBox/Vendor/Margin/VBox/VendorGrid",
	"ConfirmSell",
	"Tooltip",
	"FlyVfx",
]
const LOGICAL_SIZE := Vector2(1920.0, 1080.0)
const PHYSICAL_SIZE := Vector2(1280.0, 720.0)

var _passes := 0
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	root.size = Vector2i(LOGICAL_SIZE)
	var scene := load("res://ui/screens/HubShop.tscn") as PackedScene
	var shop := scene.instantiate() as Control
	root.add_child(shop)
	await process_frame
	await process_frame

	for path in CRITICAL_PATHS:
		_check(shop.has_node(path), "Exchange preserves controller path %s" % path)

	_check(
		shop.theme != null and "SyntheticHudTheme" in shop.theme.resource_path,
		"Exchange uses the shared theme"
	)
	for path in ["Root/HBox/Left", "Root/HBox/Equipped", "Root/HBox/Backpack", "Root/HBox/Vendor"]:
		var panel := shop.get_node_or_null(path) as PanelContainer
		_check(panel != null and panel.theme_type_variation == &"LedgerPanel", path + " is an open register")
	var ritual := shop.get_node_or_null("Root/HBox/CartPanel") as PanelContainer
	_check(ritual != null and ritual.theme_type_variation == &"RitualPanel", "Balance the Exchange is the sole emphasized rite")

	var search := shop.get_node_or_null("Root/HBox/Vendor/Margin/VBox/VendorTools/Search") as LineEdit
	var include_equipped := shop.get_node_or_null("Root/HBox/CartPanel/Margin/VBox/TradeTools/IncludeEquipped") as CheckBox
	_check(search != null and search.theme_type_variation == &"InstitutionalLineEdit", "stock search matches the ledger")
	_check(include_equipped != null and include_equipped.theme_type_variation == &"InstitutionalCheckBox", "trade checkbox matches the ledger")

	for path in [
		"Root/HBox/Left/Margin/VBox/Continue",
		"Root/HBox/CartPanel/Margin/VBox/Buttons/BtnBarter",
		"Root/HBox/Vendor/Margin/VBox/VendorTools/Search",
		"Root/HBox/Vendor/Margin/VBox/VendorGrid",
	]:
		var control := shop.get_node_or_null(path) as Control
		_check(_inside_scaled_viewport(control), "%s remains usable at 1280x720" % path)
	_check(
		String(ProjectSettings.get_setting("display/window/stretch/mode", "")) == "canvas_items",
		"1280x720 uses the project's logical canvas scaling contract"
	)

	var classification := shop.get_node_or_null("ExchangeClassification") as Label
	_check(
		classification != null and classification.text == "RECONSTRUCTION EXCHANGE // AFTERMATH REGISTER",
		"Exchange carries its institutional classification"
	)

	shop.queue_free()
	await process_frame
	print("ExchangeIdentityTest: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)


func _inside_scaled_viewport(control: Control) -> bool:
	if control == null or not control.is_visible_in_tree():
		return false
	var rect := control.get_global_rect()
	var scale := PHYSICAL_SIZE / LOGICAL_SIZE
	var physical_rect := Rect2(rect.position * scale, rect.size * scale)
	return (
		physical_rect.size.x > 0.0
		and physical_rect.size.y > 0.0
		and Rect2(Vector2.ZERO, PHYSICAL_SIZE).encloses(physical_rect)
	)

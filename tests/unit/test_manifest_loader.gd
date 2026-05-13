extends GutTest


func test_loads_manifest() -> void:
	ManifestLoader.reload()
	var ids := ManifestLoader.list_ids()
	assert_true(ids.size() > 0, "manifest should contain some assets")


func test_returns_placeholder_for_needed() -> void:
	ManifestLoader.reload()
	# Pick any entry whose status is needed; expect a magenta placeholder.
	var needed := ManifestLoader.entries_by_status("needed")
	if needed.is_empty():
		gut.p("All manifest entries are final — skipping placeholder test")
		return
	var first_id: StringName = StringName(needed[0]["id"])
	var tex := ManifestLoader.get_texture(first_id)
	assert_not_null(tex)


func test_unknown_id_returns_placeholder() -> void:
	ManifestLoader.reload()
	var tex := ManifestLoader.get_texture(&"definitely_not_a_real_asset_id")
	assert_not_null(tex)

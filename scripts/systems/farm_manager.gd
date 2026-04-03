extends Node

## 新地块注册时发射
signal plot_registered(plot: Plot)

## 地块注销时发射
signal plot_unregistered(plot: Plot)

var _plots_by_grid: Dictionary = {}
var _plots: Array[Plot] = []


func register_plot(plot: Plot) -> void:
	"""按网格坐标注册地块，重复注册时先去重。"""
	if plot == null:
		return

	unregister_plot(plot)
	_plots.append(plot)
	_plots_by_grid[plot.grid_position] = plot
	emit_signal("plot_registered", plot)


func unregister_plot(plot: Plot) -> void:
	"""从管理器中移除地块。"""
	if plot == null:
		return

	_plots.erase(plot)

	if _plots_by_grid.get(plot.grid_position) == plot:
		_plots_by_grid.erase(plot.grid_position)

	emit_signal("plot_unregistered", plot)


func get_plot_at_grid_position(grid_position: Vector2i) -> Plot:
	"""按网格坐标查找单个地块。"""
	return _plots_by_grid.get(grid_position, null)


func get_plot_at_world_position(world_position: Vector2, max_distance: float = 20.0) -> Plot:
	"""按世界坐标查找最近地块，仅返回距离阈值内的候选。"""
	var closest_plot: Plot = null
	var closest_distance: float = max_distance

	for plot in _plots:
		if not is_instance_valid(plot):
			continue

		var distance: float = plot.global_position.distance_to(world_position)
		if distance <= closest_distance:
			closest_distance = distance
			closest_plot = plot

	return closest_plot


func get_all_plots() -> Array[Plot]:
	"""返回当前所有已注册地块的副本，避免外部直接修改内部数组。"""
	return _plots.duplicate()

extends Node

@onready var farm_manager = get_node_or_null("/root/FarmManager")


func _ready() -> void:
	"""延迟连接 FarmManager，避免 autoload 初始化顺序导致的空引用。"""
	call_deferred("_connect_farm_manager")


func _connect_farm_manager() -> void:
	"""连接集中管理器及其已注册地块的视觉刷新信号。"""
	if farm_manager == null:
		farm_manager = get_node_or_null("/root/FarmManager")
	if farm_manager == null:
		return

	if not farm_manager.plot_registered.is_connected(_on_plot_registered):
		farm_manager.plot_registered.connect(_on_plot_registered)

	if not farm_manager.plot_unregistered.is_connected(_on_plot_unregistered):
		farm_manager.plot_unregistered.connect(_on_plot_unregistered)

	for plot in farm_manager.get_all_plots():
		_attach_to_plot(plot)
		refresh_plot_visual(plot)


func refresh_plot_visual(plot: Plot) -> void:
	"""刷新指定地块表现；当前 Demo 由地块自身贴图完成，渲染系统负责中转和统一入口。"""
	if plot == null or not is_instance_valid(plot):
		return

	if plot is CropPlot:
		plot._apply_visual_state()


func _on_plot_registered(plot: Plot) -> void:
	"""新地块加入后立即挂接刷新逻辑。"""
	_attach_to_plot(plot)
	refresh_plot_visual(plot)


func _on_plot_unregistered(plot: Plot) -> void:
	"""地块注销时断开信号连接。"""
	if plot == null or not is_instance_valid(plot):
		return

	if plot.visual_update_requested.is_connected(_on_plot_visual_update_requested):
		plot.visual_update_requested.disconnect(_on_plot_visual_update_requested)


func _attach_to_plot(plot: Plot) -> void:
	"""监听单个地块的视觉刷新请求。"""
	if plot == null or not is_instance_valid(plot):
		return

	if not plot.visual_update_requested.is_connected(_on_plot_visual_update_requested):
		plot.visual_update_requested.connect(_on_plot_visual_update_requested)


func _on_plot_visual_update_requested(plot: Plot) -> void:
	"""收到地块刷新请求后，统一调用视觉刷新入口。"""
	refresh_plot_visual(plot)

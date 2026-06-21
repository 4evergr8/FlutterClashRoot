import 'package:quick_settings_with_flutter_plugins/quick_settings.dart';
import 'package:mihomoR/service/control.dart';

/// =======================
/// Tile callbacks
/// =======================

@pragma('vm:entry-point')
Tile onTileClicked(Tile tile) {
  final isActive = tile.tileStatus == TileStatus.active;

  if (isActive) {
    stopMihomo();

    tile
      ..tileStatus = TileStatus.inactive
      ..label = "mihomo"
      ..drawableName = "alarm_off"
      ..contentDescription = "mihomo 已停止";
  } else {
    startMihomo();

    tile
      ..tileStatus = TileStatus.active
      ..label = "mihomo"
      ..drawableName = "alarm_on"
      ..contentDescription = "mihomo 已启动";
  }

  return tile;
}

@pragma('vm:entry-point')
Tile? onTileAdded(Tile tile) {
  tile.label = "mihomo";
  tile.drawableName = "alarm_off";
  tile.contentDescription = "mihomo 核心控制";
  tile.tileStatus = TileStatus.inactive;
  return tile;
}

@pragma('vm:entry-point')
void onTileRemoved() {}
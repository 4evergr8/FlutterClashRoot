import 'package:quick_settings_with_flutter_plugins/quick_settings.dart';
import 'package:clashroot/service/control.dart';

/// =======================
/// Tile callbacks
/// =======================

@pragma('vm:entry-point')
Tile onTileClicked(Tile tile) {
  final isActive = tile.tileStatus == TileStatus.active;

  if (isActive) {
    stopClash();

    tile
      ..tileStatus = TileStatus.inactive
      ..label = "ClashRoot"
      ..drawableName = "alarm_off"
      ..contentDescription = "Clash核心已停止";
  } else {
    startClash();

    tile
      ..tileStatus = TileStatus.active
      ..label = "ClashRoot"
      ..drawableName = "alarm_on"
      ..contentDescription = "Clash核心已启动";
  }

  return tile;
}

@pragma('vm:entry-point')
Tile? onTileAdded(Tile tile) {
  tile.label = "ClashRoot";
  tile.drawableName = "alarm_off";
  tile.contentDescription = "Clash核心控制";
  tile.tileStatus = TileStatus.inactive;
  return tile;
}

@pragma('vm:entry-point')
void onTileRemoved() {}
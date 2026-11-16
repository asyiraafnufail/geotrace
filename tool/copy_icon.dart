// ignore_for_file: avoid_print
import 'dart:io';

void main() async {
  const iconPath =
      '/Users/asyiraaf/.gemini/antigravity-cli/brain/031f47aa-9682-487a-b7ad-848396020e7c/geotrace_app_icon_1794817868162.jpg';
  final srcFile = File(iconPath);

  if (!srcFile.existsSync()) {
    print('Source icon not found at: $iconPath');
    return;
  }

  // 1. Salin ke assets/icon/
  final assetsDir = Directory('assets/icon');
  if (!assetsDir.existsSync()) {
    assetsDir.createSync(recursive: true);
  }
  srcFile.copySync('assets/icon/app_icon.png');
  srcFile.copySync('assets/icon/app_icon.jpg');
  print('✓ Berhasil menyalin ke assets/icon/app_icon.png');

  // 2. Salin ke seluruh folder launcher icon Android (mipmap)
  final resDir = Directory('android/app/src/main/res');
  int mipmapCount = 0;
  if (resDir.existsSync()) {
    for (final entity in resDir.listSync()) {
      if (entity is Directory && entity.path.contains('mipmap-')) {
        srcFile.copySync('${entity.path}/ic_launcher.png');
        print('✓ Berhasil mengupdate: ${entity.path}/ic_launcher.png');
        mipmapCount++;
      }
    }
  }

  print('\nSelesai! Berhasil memasang $mipmapCount icon Android dan asset icon.');
}

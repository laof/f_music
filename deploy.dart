import 'dart:io';

void main(List<String> args) {
  if (args.length == 0) {
    print("loca testing");
    return;
  }
  var pf = args[0];
  print("build folder pipeline: " + pf);
  File apk = File('build/app/outputs/flutter-apk/app-release.apk');
  new Directory("output").createSync();
  apk.copySync("output/f_music.apk");
}
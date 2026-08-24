# Launcher icons

This hand-authored `android/` tree does **not** include real launcher icon
PNGs (`app/src/main/res/mipmap-*/ic_launcher.png` / adaptive-icon variants) —
they're binary files and can't be fabricated sensibly without real artwork.

`AndroidManifest.xml`'s `<application android:icon="@mipmap/ic_launcher" ...>`
still references them, exactly as Flutter's own `flutter create` template
does by default. **This will fail resource resolution** (`resource
mipmap/ic_launcher not found`) until real icons exist at that path.

Before the first real build, do one of:

1. **Recommended:** add the
   [`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons)
   dev dependency to `pubspec.yaml`, point it at a source image, and run
   `flutter pub run flutter_launcher_icons` — it generates all
   `mipmap-*/ic_launcher.png` (and adaptive icon foreground/background/XML)
   variants for you.
2. **Manual:** use Android Studio's Image Asset Studio (right-click
   `res/` → New → Image Asset) or hand-place PNGs at each
   `mipmap-mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi/ic_launcher.png` density bucket.

Either way, opening this project in Android Studio for the first time will
surface the missing-resource error immediately — that's expected, not a sign
something else is broken.

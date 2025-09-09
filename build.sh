rm -r build/*
rm -r AppDir/*
linuxdeploy --appdir=AppDir --desktop-file=encrypter.desktop --icon-file=icon.svg --executable=zig-out/bin/encrypter
linuxdeploy --appdir=AppDir --executable=bin/keepassxc-cli
linuxdeploy --appdir=AppDir --executable=bin/age-keygen
linuxdeploy --appdir=AppDir --executable=bin/age
linuxdeploy --appdir=AppDir --output=appimage
mv Encrypter-x86_64.AppImage build/

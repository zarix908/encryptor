# clean build directory
rm -r build/*

# deploy encrypter
zig build
linuxdeploy --appdir=./build/AppDir --desktop-file=./build_deps/encrypter.desktop --icon-file=./build_deps/icon.svg --executable=./zig-out/bin/encrypter

# deploy binarydependencies
linuxdeploy --appdir=./build/AppDir --executable=./build_bin/keepassxc-cli
linuxdeploy --appdir=./build/AppDir --executable=./build_bin/age-keygen
linuxdeploy --appdir=./build/AppDir --executable=./build_bin/age

# create appimage
linuxdeploy --appdir=./build/AppDir --output=appimage
mv Encrypter-x86_64.AppImage ./build/

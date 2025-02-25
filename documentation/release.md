
# Release procedure

- On voxl-dev branch in submodule px4-firmware
- Commit and push everything
- tag it and push tag
  - Tag format: vX.Y.Z-X.Y.Z-<type>
    - First X.Y.Z is for PX4 version number
    - Second X.Y.Z is for our ModalAI vendor version number
    - Type: dev, alpha<number>, beta<number>, rc<number>

- On dev branch
- Add release notes to this document
- Add release notes to the CHANGELOG
- Bump package version number in debian/control
- ./clean.sh (in Docker)
- ./build.sh (in Docker)
- ./make_package.sh
- deploy / validate
- Commit and push everything
- Merge dev into master
- Add version tag
- Commit and push everything
- post package to cloud bucket

# Releases

See the CHANGELOG for details on the contents of each release
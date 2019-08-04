#!/bin/bash
set -ev

HOST=$3
USER=$4
PASS=$5
COMMIT=$6
BUILD=$7
DATE=`date +"%y%m%d"`
FILE=MyStory-$COMMIT-$DATE.zip
LATEST=MyStore-latest.zip


echo "Download und extract sourcemod"
wget "http://www.sourcemod.net/latest.php?version=$1&os=linux" -O sourcemod.tar.gz
tar -xzf sourcemod.tar.gz

echo "Give compiler rights for compile"
chmod +x addons/sourcemod/scripting/spcomp

echo "Set plugins version"
for file in addons/sourcemod/scripting/mystore_*.sp
do
  sed -i "s/<COMMIT>/$COMMIT/g" $file
  sed -i "s/<BUILD>/$BUILD/g" $file
  sed -i "s/<DATE>/$DATE/g" $file
done

echo "Compile MyStore plugins"
for file in addons/sourcemod/scripting/mystore_*.sp
do
echo "Compile $file"
  addons/sourcemod/scripting/spcomp -E -v0 $file
done

echo "Remove plugins folder if exists"
if [ -d "addons/sourcemod/plugins" ]; then
  rm -r addons/sourcemod/plugins
fi

echo "Create clean plugins folder"
mkdir addons/sourcemod/plugins

echo "Move all MyJB binary files to plugins folder"
for file in mystore_*.smx
do
  mv $file addons/sourcemod/plugins
done

echo "Remove build folder if exists"
if [ -d "build" ]; then
  rm -r build
fi

echo "Create clean build & sub folder"
mkdir build
mkdir build/gameserver
mkdir build/fastDL

echo "Move addons, materials and sound folder"
echo mv addons cfg materials models sound particles build/gameserver

echo "Move FastDL folder"
echo mv fastDL/materials fastDL/models fastDL/sound fastDL/particles build/fastDL

echo "Move license to build"
echo mv install.txt license.txt build/

echo "Remove sourcemod folders"
rm -r build/gameserver/addons/metamod
rm -r build/gameserver/addons/sourcemod/bin
rm -r build/gameserver/addons/sourcemod/configs/geoip
rm -r build/gameserver/addons/sourcemod/configs/sql-init-scripts
rm -r build/gameserver/addons/sourcemod/configs/*.txt
rm -r build/gameserver/addons/sourcemod/configs/*.ini
rm -r build/gameserver/addons/sourcemod/configs/*.cfg
rm -r build/gameserver/addons/sourcemod/data
rm -r build/gameserver/addons/sourcemod/extensions
rm -r build/gameserver/addons/sourcemod/gamedata
rm -r build/gameserver/addons/sourcemod/scripting
rm -r build/gameserver/addons/sourcemod/translations
rm -r build/gameserver/cfg/sourcemod
rm build/gameserver/addons/sourcemod/*.txt

echo "Download sourcefiles & create clean scripting folder"
git clone --depth=50 --branch=$2 https://github.com/shanapu/MyStore.git source/MyStore
mv source/MyStore/addons/sourcemod/scripting build/gameserver/addons/sourcemod

echo "Set plugins version"
for file in build/gameserver/addons/sourcemod/scripting/mystore_*.sp
do
  sed -i "s/<COMMIT>/$COMMIT/g" $file
  sed -i "s/<BUILD>/$BUILD/g" $file
  sed -i "s/<DATE>/$DATE/g" $file
done

echo "Create clean translation folder"
mkdir build/gameserver/addons/sourcemod/translations

echo "Download und unzip translation file"
wget -q -O translations.zip http://translator.mitchdempsey.com/sourcemod_plugins/322/download/mystore.translations.zip
unzip -qo translations.zip -d build/gameserver/

echo "Clean root folder"
rm sourcemod.tar.gz
rm translations.zip

echo "Go to build folder"
cd build

echo "Compress directories and files"
zip -9rq $FILE gameserver fastDL install.txt license.txt

echo "Upload file"
lftp -c "set ftp:ssl-allow no; set ssl:verify-certificate no; open -u $USER,$PASS $HOST; put -O MyStore/downloads/SM$1/$2/ $FILE"

echo "Add latest build"
mv $FILE $LATEST

echo "Upload latest build"
lftp -c "set ftp:ssl-allow no; set ssl:verify-certificate no; open -u $USER,$PASS $HOST; put -O MyStore/downloads/SM$1/ $LATEST"

echo "Build done"
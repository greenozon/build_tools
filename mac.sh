function check_file
{
    if test -f "$1"; then
        echo "Check file $1: TRUE"
    else
        export X_ERROR="true"
        echo "Cannot find file: $1"
    fi
}

function make_init
{
    export X_QT_VERSION=$($QMAKE_PATH -query QT_VERSION)
    export X_QT_INSTALL_BINS=$($QMAKE_PATH -query QT_INSTALL_BINS)
    export X_QT_INSTALL_PLUGINS=$($QMAKE_PATH -query QT_INSTALL_PLUGINS)
    export X_QT_INSTALL_LIBS=$($QMAKE_PATH -query QT_INSTALL_LIBS)
    export X_QMAKE_SPEC=$($QMAKE_PATH -query QMAKE_SPEC)
    mkdir -p "$X_SOURCE_PATH/release"
    mkdir -p "$X_SOURCE_PATH/release/$X_BUILD_NAME"
    
    cp -f $X_SOURCE_PATH/build_tools/build.pri $X_SOURCE_PATH/
}

function make_build
{
    if test -f "Makefile"; then
        make clean
    fi

    $QMAKE_PATH "$1" -spec $X_QMAKE_SPEC CONFIG+=x86_64 CONFIG+=release
    make -f Makefile
}

function make_translate 
{
    "$X_QT_INSTALL_BINS/lupdate" $1
    "$X_QT_INSTALL_BINS/lrelease" $1
    mkdir -p "$X_SOURCE_PATH/release/$X_BUILD_NAME/$2.app/Contents/Resources/lang"
    mv translation/*.qm "$X_SOURCE_PATH/release/$X_BUILD_NAME/$2.app/Contents/Resources/lang/"
}

function make_release
{
    # TODO make dmg function
    #rm -rf $X_SOURCE_PATH/release/${X_BUILD_NAME}_${X_RELEASE_VERSION}.dmg
    #hdiutil create -format UDBZ -quiet -srcfolder $X_SOURCE_PATH/release/$BUILD_NAME $X_SOURCE_PATH/release/${X_BUILD_NAME}_${X_RELEASE_VERSION}.dmg
    
    #if [ -n "$X_PRIVATE_CERT_APP" ]; then
    #    codesign --deep -f -v -s "$X_PRIVATE_CERT_APP" -o runtime $X_SOURCE_PATH/release/${X_BUILD_NAME}/$1.app
    #fi
    
    cd $X_SOURCE_PATH/release/
    rm -rf $X_SOURCE_PATH/release/${X_BUILD_NAME}_portable_${X_RELEASE_VERSION}.zip
    /usr/bin/ditto -c -k --sequesterRsrc --keepParent $X_SOURCE_PATH/release/${X_BUILD_NAME}/$1.app $X_SOURCE_PATH/release/${X_BUILD_NAME}_portable_${X_RELEASE_VERSION}.zip
    
    if [ -n "$X_PRIVATE_CERT_INSTALL" ]; then
        pkgbuild --analyze --root $X_SOURCE_PATH/release/${X_BUILD_NAME}/$1.app $X_SOURCE_PATH/release/${X_BUILD_NAME}/$1.plist
        pkgbuild --root $X_SOURCE_PATH/release/${X_BUILD_NAME}/$1.app --component-plist $X_SOURCE_PATH/release/${X_BUILD_NAME}/$1.plist  $X_SOURCE_PATH/release/${X_BUILD_NAME}_${X_RELEASE_VERSION}.pkg --sign "$X_PRIVATE_CERT_INSTALL" --identifier $X_PRIVATE_NOTARIZE_BUNDLE --install-location /Applications/$1.app
    fi
    
    if [ -n "$X_PRIVATE_NOTARIZE_PWD" ]; then
        xcrun altool --notarize-app -f $X_SOURCE_PATH/release/${X_BUILD_NAME}_portable_${X_RELEASE_VERSION}.zip --primary-bundle $X_PRIVATE_NOTARIZE_BUNDLE -u ${X_PRIVATE_NOTARIZE_LOGIN} -p ${X_PRIVATE_NOTARIZE_PWD}
        xcrun altool --notarize-app -f $X_SOURCE_PATH/release/${X_BUILD_NAME}_${X_RELEASE_VERSION}.pkg --primary-bundle $X_PRIVATE_NOTARIZE_BUNDLE -u ${X_PRIVATE_NOTARIZE_LOGIN} -p ${X_PRIVATE_NOTARIZE_PWD}
    fi
    
    zip -d $X_SOURCE_PATH/release/${X_BUILD_NAME}_portable_${X_RELEASE_VERSION}.zip __MACOSX/\*

    cd $X_SOURCE_PATH
}

function make_clear
{
    rm -rf $X_SOURCE_PATH/release/$X_BUILD_NAME
}

function fixlibrary
{
    install_name_tool -change @rpath/$1.framework/Versions/5/$1 @executable_path/../Frameworks/$1.framework/Versions/5/$1  $2    
}

function fiximport
{
    fixlibrary QtWidgets $1
    fixlibrary QtGui $1
    fixlibrary QtCore $1  
    fixlibrary QtDBus $1
    fixlibrary QtPrintSupport $1
    fixlibrary QtSvg $1
    fixlibrary QtOpenGL $1
    fixlibrary QtConcurrent $1
    fixlibrary QtScript $1
    fixlibrary QtScriptTools $1
    fixlibrary QtNetwork $1
}

function deploy_qt
{
    "$X_QT_INSTALL_BINS/macdeployqt" $X_SOURCE_PATH/release/${X_BUILD_NAME}/$1.app
}

function deploy_qt_sign
{
    "$X_QT_INSTALL_BINS/macdeployqt" $X_SOURCE_PATH/release/${X_BUILD_NAME}/$1.app
    codesign --deep -f -v -s "$X_PRIVATE_CERT_APP" -o runtime $X_SOURCE_PATH/release/${X_BUILD_NAME}/$1.app/Contents/MacOS/$1
    codesign -f -v -s "$X_PRIVATE_CERT_APP" -o runtime $X_SOURCE_PATH/release/${X_BUILD_NAME}/$1.app/Contents/MacOS/$1
}

function deploy_qt_sign_disable_protection
{
    "$X_QT_INSTALL_BINS/macdeployqt" $X_SOURCE_PATH/release/${X_BUILD_NAME}/$1.app
    codesign --deep -f -v -s "$X_PRIVATE_CERT_APP" --entitlements $X_SOURCE_PATH/build_tools/disable_protection.plist -o runtime $X_SOURCE_PATH/release/${X_BUILD_NAME}/$1.app/Contents/MacOS/$1
    codesign -f -v -s "$X_PRIVATE_CERT_APP" --entitlements $X_SOURCE_PATH/build_tools/disable_protection.plist -o runtime $X_SOURCE_PATH/release/${X_BUILD_NAME}/$1.app/Contents/MacOS/$1
}

function deploy_qt_library
{
    mkdir $X_SOURCE_PATH/release/$X_BUILD_NAME/$2.app/Contents/Frameworks
    mkdir $X_SOURCE_PATH/release/$X_BUILD_NAME/$2.app/Contents/Frameworks/$1.framework
    mkdir $X_SOURCE_PATH/release/$X_BUILD_NAME/$2.app/Contents/Frameworks/$1.framework/Versions
    mkdir $X_SOURCE_PATH/release/$X_BUILD_NAME/$2.app/Contents/Frameworks/$1.framework/Versions/5
    
    cp -R $X_QT_INSTALL_LIBS/$1.framework/Versions/5/$1 $X_SOURCE_PATH/release/$X_BUILD_NAME/$2.app/Contents/Frameworks/$1.framework/Versions/5
    
    install_name_tool -id @executable_path/../Frameworks/$1.framework/Versions/5/$1 $X_SOURCE_PATH/release/$X_BUILD_NAME/$2.app/Contents/Frameworks/$1.framework/Versions/5/$1
    fiximport $X_SOURCE_PATH/release/$X_BUILD_NAME/$2.app/Contents/Frameworks/$1.framework/Versions/5/$1
}

function deploy_qt_plugin
{
    mkdir $X_SOURCE_PATH/release/$X_BUILD_NAME/$3.app/Contents/PlugIns/
    mkdir $X_SOURCE_PATH/release/$X_BUILD_NAME/$3.app/Contents/PlugIns/$1/
    cp -R $X_QT_INSTALL_PLUGINS/$1/$2.dylib $X_SOURCE_PATH/release/$X_BUILD_NAME/$3.app/Contents/PlugIns/$1/
    
    install_name_tool -id @executable_path/../PlugIns/$1/$2.dylib $X_SOURCE_PATH/release/$X_BUILD_NAME/$3.app/Contents/PlugIns/$1/$2.dylib
    fiximport $X_SOURCE_PATH/release/$X_BUILD_NAME/$3.app/Contents/PlugIns/$1/$2.dylib
}

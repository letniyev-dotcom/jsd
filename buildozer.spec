[app]

# (str) Title of your application
title = тапок

# (str) Package name
package.name = tapok

# (str) Package domain (needed for android/ios packaging)
package.domain = app.tapok

# (str) Source code where the main.py live
source.dir = .

# (list) Source files to include (let empty to include all the files)
source.include_exts = py,png,jpg,jpeg,webp,kv,atlas,html,js,css,json,txt,xml

# (list) List of inclusions using pattern matching
#source.include_patterns = assets/*,images/*.png

# (list) Source files to exclude (let empty to not exclude anything)
source.exclude_exts = spec

# (list) List of directory to exclude (let empty to not exclude anything)
source.exclude_dirs = tests, bin, .git, .github, __pycache__, .buildozer

# (str) Application versioning (method 1)
version = 1.0.0

# (str) Application versioning (method 2)
# version.regex = __version__ = ['"](.*)['"]
# version.filename = %(source.dir)s/main.py

# (list) Application requirements
# comma separated e.g. requirements = sqlite3,kivy
requirements = python3,kivy==2.3.0,pyjnius,android

# (str) Custom source folders for requirements
# requirements.source.kivy = ../../kivy

# (list) Garden requirements
#garden_requirements =

# (str) Presplash of the application
#presplash.filename = %(source.dir)s/data/presplash.png

# (str) Icon of the application
#icon.filename = %(source.dir)s/data/icon.png

# (str) Supported orientation (landscape, portrait or all)
orientation = portrait

# (list) List of service to declare
#services = NAME:ENTRYPOINT_TO_PY,NAME2:ENTRYPOINT2_TO_PY

#
# OSX Specific
#

#
# author = © Copyright Info

# change the major version of python used by your app
osx.python_version = 3

# Kivy version to use
osx.kivy_version = 2.3.0

#
# Android specific
#

# (bool) Indicate if the application should be fullscreen or not
fullscreen = 1

# (string) Presplash background color (for android toolchain)
# Supported formats are: #RRGGBB #AARRGGBB or one of the following names:
# red, blue, green, black, white, gray, cyan, magenta, yellow, lightgray,
# darkgray, grey, lightgrey, lime, maroon, navy, olive, purple, silver, teal.
android.presplash_color = #0d0d0d

# (list) Permissions
android.permissions = INTERNET, ACCESS_NETWORK_STATE

# (int) Target Android API, should be as high as possible.
android.api = 34

# (int) Minimum API your APK will support.
android.minapi = 24

# (str) Android NDK version to use
android.ndk = 25b

# (int) Android NDK API to use (optional). This is the minimum API your app will support.
#android.ndk_api = 21

# (bool) Use --private data storage (True) or --dir public storage (False)
android.private_storage = True

# (str) Android NDK directory (if empty, it will be automatically downloaded.)
#android.ndk_path =

# (str) Android SDK directory (if empty, it will be automatically downloaded.)
#android.sdk_path =

# (str) ANT directory (if empty, it will be automatically downloaded.)
#android.ant_path =

# (bool) If True, then skip trying to update the Android sdk
# This can be useful to avoid excess Internet downloads or save time
# when an update is due and you just want to test/build your package
# android.skip_update = False

# (bool) If True, then automatically accept SDK license
android.accept_sdk_license = True

# (str) Android entry point, default is ok for Kivy-based app
#android.entrypoint = org.kivy.android.PythonActivity

# (str) Full name including package of the Java class that implements Android Application class from android.app.Application
#android.application = org.kivy.android.PythonApplication

# (str) Android app theme, default is ok for Kivy-based app
# android.apptheme = "@android:style/Theme.NoTitleBar"

# (list) Pattern to whitelist for the whole project
#android.whitelist =

# (str) Path to a custom whitelist file
#android.whitelist_src =

# (str) Path to a custom blacklist file
#android.blacklist_src =

# (list) List of Java .jar files to add to the libs so that pyjnius can access
# their classes. Don't add jars that you do not need, since extra jars can slow
# down the build process. Doesn't accept wildcards (use patterns instead)
#android.add_jars = foo.jar,bar.jar,path/to/more/*.jar

# (list) List of Java files to add to the android project (can be java or a
# directory containing the files)
#android.add_src =

# (list) Android AAR archives to add
#android.add_aars =

# (list) Put these files or directories in the apk assets directory.
# Either form may be used, and they can be combined.
#android.add_assets = path/to/file.ext path/to/dir/
android.add_assets = assets/index.html

# (list) Put these files or directories in the apk res directory.
# The option is using the add-resource called in the ant build system.
#android.add_resources = path/to/file.ext=path/to/dest

# (list) Gradle dependencies to add
#android.gradle_dependencies =

# (bool) Enable AndroidX support. Enable when 'android.gradle_dependencies'
# contains an 'androidx' package, or any package from Android Support Library.
# android.enable_androidx requires android.api >= 28
android.enable_androidx = True

# (list) add java compile options
# this can for example be necessary when importing certain libraries that expect
# some -parameters to be passed to javac.
# android.add_compile_options = -Xlint:deprecation

# (list) Gradle repositories to add {can be necessary for some android.gradle_dependencies}
# please enclose in double quotes 
# e.g. android.gradle_repositories = "maven { url 'https://kotlin.bintray.com/kotlinx' }"
#android.gradle_repositories =

# (list) packaging options to add 
# see https://google.github.io/android-gradle-dsl/current/com.android.build.gradle.internal.dsl.PackagingOptions.html
# can be necessary to solve conflicts in gradle_dependencies
# please enclose in double quotes
# e.g. android.add_packaging_options = "exclude 'META-INF/common.kotlin_module'", "exclude 'META-INF/*.kotlin_module'"
#android.add_packaging_options =

# (list) Java class/activity to add to the AndroidManifest.xml
#android.add_activities = com.example.Activity

# (str) OUYA Console category. Should be one of GAME or APP
# If you leave this blank, OUYA support will not be enabled
#android.ouya.category = GAME

# (str) Filename of OUYA Console icon. It must be a 732x412 png image.
#android.ouya.icon.filename = %(source.dir)s/data/ouya_icon.png

# (str) XML file to include as an intent filters in <activity> tag
#android.manifest.intent_filters =

# (str) launchMode to set for the main activity
#android.manifest.launch_mode = standard

# (list) Android additional libraries to copy into libs/armeabi
#android.add_libs_armeabi = libs/armeabi/*.so
#android.add_libs_armeabi_v7a = libs/armeabi_v7a/*.so
#android.add_libs_arm64_v8a = libs/arm64_v8a/*.so
#android.add_libs_x86 = libs/x86/*.so
#android.add_libs_mips = libs/mips/*.so

# (bool) Indicate whether the screen should stay on while the app is active
#android.wakelock = False

# (list) Android application meta-data to add (key=value format)
#android.meta_data =

# (list) Android library project to add (will be added in the
# project.properties automatically.)
#android.library_references =

# (list) Android shared libraries which will be added to AndroidManifest.xml using <uses-library> tag
#android.uses_library =

# (str) Android logcat filters to use
android.logcat_filters = *:S python:D

# (bool) Copy library instead of making a libpymodules.so
#android.copy_libs = 1

# (str) The Android arch to build for, choices: armeabi-v7a, arm64-v8a, x86, x86_64
android.archs = arm64-v8a, armeabi-v7a

# (bool) enables Android auto backup feature (Android API >=23)
android.allow_backup = True

# (str) XML file for custom backup rules (if available)
#android.backup_rules =

# (str) If you need to insert variables into your AndroidManifest.xml file,
# you can do so with the manifestPlaceholders property.
# This is currently only used for the Google Play Billing library.
#android.manifest_placeholders = [localApplicationId='com.example']

# (bool) Disable the navigation bar, it will use the softkey buttons instead
#android.disable_navigation_bar = False

# (bool) Skip packaging of some assets (e.g. for performance reasons)
#android.skip_packaging = False

# (str) URI for the Android release keystore
#android.keystore = 

# (str) The keystore password
#android.keystore_passwd = 

# (str) The key alias
#android.keyalias = 

# (str) The key alias password
#android.keyalias_passwd = 

# (str) Path to the Android keystore (relative or absolute)
#android.keystore_path = 

# (bool) Indicate if the android.keystore_path is relative or absolute
#android.keystore_relative = False

#
# Python for android (p4a) specific
#

# (str) python-for-android URL to use for checkout
#p4a.url =

# (str) python-for-android fork to use in case if p4a.url is not specified, defaults to master
#p4a.fork = kivy

# (str) python-for-android branch to use, defaults to master
#p4a.branch = master

# (str) python-for-android bootstrap to use, defaults to sdl2
#p4a.bootstrap = sdl2

# (str) python-for-android git clone directory (if empty, it will be automatically cloned from github)
#p4a.source_dir =

# (str) The directory in which python-for-android should look for your own build recipes (if any)
#p4a.local_recipes =

# (str) The name of the folder in the root of the build directory for the intermediate bootstrap files
#p4a.bootstrap_dir =

# (str) The name of the folder in the root of the build directory for the intermediate distribution files
#p4a.dist_dir =

# (bool) Use one AndroidManifest.xml for both the debug and release builds
#p4a.use_single_manifest = False

# (list) The additional AndroidManifest.xml entries
#p4a.extra_manifest_xml =

# (list) The additional Java files to include
#p4a.extra_java =

# (bool) Enable the AndroidX support
#p4a.enable_androidx = True

# (str) The AndroidManifest.xml template to use
#p4a.manifest_template =

# (str) The AndroidManifest.xml template for the release build
#p4a.release_manifest_template =

#
# iOS specific
#

# (str) Path to a custom icon for the application
#ios.icon.filename = %(source.dir)s/data/icon.png

# (str) Path to a custom icon for the application
#ios.icon.filename = %(source.dir)s/data/icon.png

# (str) Path to a custom icon for the application
#ios.icon.filename = %(source.dir)s/data/icon.png

# (str) Path to a custom icon for the application
#ios.icon.filename = %(source.dir)s/data/icon.png

# (str) Path to a custom icon for the application
#ios.icon.filename = %(source.dir)s/data/icon.png

# (str) Path to a custom icon for the application
#ios.icon.filename = %(source.dir)s/data/icon.png

# (str) Path to a custom icon for the application
#ios.icon.filename = %(source.dir)s/data/icon.png

# (str) Path to a custom icon for the application
#ios.icon.filename = %(source.dir)s/data/icon.png

[buildozer]

# (int) Log level (0 = error only, 1 = info, 2 = debug (with command output))
log_level = 2

# (int) Display warning if buildozer is run as root (0 = False, 1 = True)
warn_on_root = 1

# (str) Path to build artifact storage, absolute or relative to spec file
# build_dir = ./.buildozer

# (str) Path to build output (i.e. .apk, .ipa) storage
# bin_dir = ./bin

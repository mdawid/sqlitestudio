set OLDDIR [pwd]

# Find Qt
if {![catch {exec where /q qmake}]} {
	set QT_DIR [file dirname [exec where qmake]]
	puts "INFO: Qt found at $QT_DIR"
} else {
	puts "ERROR: Cannot find Qt"
	exit 1
}

# Find 7zip
set USE_ZIP 0
if {[catch {exec where /q 7z}]} {
	puts "INFO: No 7z.exe. *.zip packages will not be created, only a runnable distribution."
} else {
	set ZIP [exec where 7z]
	puts "INFO: 7zip found at $ZIP"
	set USE_ZIP 1
}

cd $OLDDIR
cd ../..
set parent_dir [pwd]

# Clean up
puts "INFO: Cleaning up..."
cd $parent_dir/output
file delete -force portable

# Create a copy
puts "INFO: Creating a portable distribution"
file mkdir portable
file copy SQLiteStudio portable/

# Remove .a files from app dir
cd portable/SQLiteStudio
foreach f [glob -nocomplain *.a] {
	file delete -force $f
}
set PORTABLE [pwd]

# Remove .a files from plugins dir
cd plugins
foreach f [glob -nocomplain *.a] {
	file delete -force $f
}

# Copy Qt files
cd $PORTABLE
exec $QT_DIR/windeployqt SQLiteStudio.exe

# Copy app-specific deps
cd $parent_dir/../lib
foreach f [glob -nocomplain *.dll] {
	file copy $f $PORTABLE
}

cd $PORTABLE
set APP_VERSION [lindex [exec sqlitestudiocli --version] 1]
cd ..

if {$USE_ZIP} {
	exec $ZIP a -r sqlitestudio-${APP_VERSION}.zip SQLiteStudio
}

# Incremental package
puts "INFO: Creating incremental update package"
cd $PORTABLE/..
file mkdir incremental
file copy SQLiteStudio incremental/

cd incremental/SQLiteStudio
foreach f [concat [glob -nocomplain Qt5*.dll] [glob -nocomplain libgcc*] [glob -nocomplain libstdc*] [glob -nocomplain libwinpthread*]] {
	file delete -force $f
}
foreach f [list iconengines imageformats platforms printsupport plugins] {
	file delete -force $f
}

cd $PORTABLE/../incremental
if {$USE_ZIP} {
	exec $ZIP a -r sqlitestudio-%APP_VERSION%.zip SQLiteStudio
}

# Plugin packages
puts "INFO: Creating plugin updates"

proc preparePlugin {plugin plugin_ver} {
	if {[file exists plugins/$plugin.dll]} {
		puts "INFO: Creating plugin update: $plugin ($plugin_ver)"
		file mkdir ../plugins/$plugin/SQLiteStudio/plugins
		file copy plugins/$plugin.dll ../plugins/$plugin/SQLiteStudio/plugins

		cd ../plugins/$plugin
		if {$::USE_ZIP} {
			exec $::ZIP a -r ../${plugin}-$plugin_ver.zip SQLiteStudio
		}
		cd ../../SQLiteStudio
	}
}

cd $PORTABLE
foreach plug [split [exec SQLiteStudio.exe --list-plugins] \n] {
	preparePlugin {*}$plug
}

cd $OLDDIR
puts "INFO: Portable distribution v$APP_VERSION created at $PORTABLE"

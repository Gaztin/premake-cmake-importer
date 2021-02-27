local p = premake
local m = p.extensions.impcmake

function m.commands.cmake_minimum_required( cmd )
	-- TODO: Throw if higher than @m._LASTEST_CMAKE_VERSION
	m.downloadCMakeModules( m._LASTEST_CMAKE_VERSION )
end

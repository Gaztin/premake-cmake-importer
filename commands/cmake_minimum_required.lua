local p = premake
local m = p.extensions.impcmake

function m.commands.cmake_minimum_required( cmd )
	if( not os.isfile( m.modules.getCacheMarkerPath() ) ) then
		-- TODO: Throw if higher than @m._LATEST_CMAKE_VERSION
		m.modules.download( m._LATEST_CMAKE_VERSION )
	end
end

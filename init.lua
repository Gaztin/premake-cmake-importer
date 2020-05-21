local p               = premake
p.extensions.impcmake = { }

require 'parser/directory'

local m      = premake.extensions.impcmake
local parser = p.extensions.impcmake.parser

function cmake_project( relativePath )
	local prj = parser.directory.parse( relativePath )

	return prj
end

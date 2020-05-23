local p               = premake
p.extensions.impcmake = { }

require 'parser/directory'

local m      = premake.extensions.impcmake
local parser = p.extensions.impcmake.parser

function cmake_project( filePath )
	parser.directory.parse( path.rebase( filePath, '.', 'parser' ) )
end

local p               = premake
p.extensions.impcmake = { }

require 'utility'

require 'parser/directory'

local m      = premake.extensions.impcmake
local parser = p.extensions.impcmake.parser

-- Constants
m.ON       = 'ON'
m.YES      = 'YES'
m.TRUE     = 'TRUE'
m.Y        = 'Y'
m.OFF      = 'OFF'
m.NO       = 'NO'
m.FALSE    = 'FALSE'
m.N        = 'N'
m.IGNORE   = 'IGNORE'
m.NOTFOUND = 'NOTFOUND'

function cmake_project( filePath )
	parser.directory.parse( path.rebase( filePath, '.', 'parser' ) )
end

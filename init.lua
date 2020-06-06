local p               = premake
p.extensions.impcmake = { }
local m               = premake.extensions.impcmake

require 'api'
require 'utility'
require 'cmake_modules_cache'

require 'parser/script'
require 'parser/directory'

m._VERSION               = '1.0.0'
m._LASTEST_CMAKE_VERSION = '3.17.3'

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
	m.parseDirectory( path.rebase( filePath, '.', 'parser' ) )
end

local p                 = premake
p.extensions.impcmake   = { }
local m                 = p.extensions.impcmake
m.aliases               = { }
m.cache_entries         = { }
m.cache_entries_allowed = { }

require 'cmake_commands'
require 'cmake_conditions'
require 'cmake_groups'
require 'cmake_modules'
require 'cmake_scope'
require 'cmake_script'
require 'cmake_utils'

m._VERSION              = '1.0.0'
m._LATEST_CMAKE_VERSION = '3.17.3'

-- Variables that stay the same throughout the entire configuration, but are expensive to fetch

m.HOST_SYSTEM_NAME      = os.outputof( 'uname -s' ) or os.host()
m.HOST_SYSTEM_PROCESSOR = os.getenv( 'PROCESSOR_ARCHITECTURE' ) or os.outputof( 'uname -m' ) or os.outputof( 'arch' )

-- Global constants
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
	m.scope.push()
	m.loadScript( filePath )
	m.scope.pop()
end

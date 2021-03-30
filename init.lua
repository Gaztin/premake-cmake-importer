local p               = premake
p.extensions.impcmake = { }
local m               = p.extensions.impcmake
m.aliases             = { }
m.cache_entries       = { }
m.options             = { }

require 'cmake_commands'
require 'cmake_conditions'
require 'cmake_groups'
require 'cmake_modules'
require 'cmake_properties'
require 'cmake_scope'
require 'cmake_script'
require 'cmake_utils'

if( _OPTIONS.verbose ) then
	require 'cmake_profiling'
end

m._VERSION              = '1.0.0'
m._LATEST_CMAKE_VERSION = '3.17.3'

-- Variables that stay the same throughout the entire configuration, but are expensive to fetch

m.HOST_SYSTEM_NAME      = os.outputof( 'uname -s' ) or os.host()
m.HOST_SYSTEM_PROCESSOR = os.getenv( 'PROCESSOR_ARCHITECTURE' ) or os.outputof( 'uname -m' ) or os.outputof( 'arch' )
m.ENV_SEPARATOR         = os.ishost( 'windows' ) and ';' or ':'

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

function cmakeproject( filePath )
	if( os.isdir( filePath ) ) then
		filePath = path.join( filePath, 'CMakeLists.txt' )
	end

	local scope = m.scope.push()
	scope.variables[ 'PROJECT_SOURCE_DIR' ]        = path.getdirectory( filePath )
	scope.variables[ 'CMAKE_CONFIGURATION_TYPES' ] = table.implode( p.api.scope.workspace.configurations, '"', '"', ' ' )

	-- Add all predefined options as variables in root scope
	for name,value in pairs( m.options ) do
		scope.variables[ name ] = value
	end

	m.loadScript( filePath )

	m.scope.pop()

	if( _OPTIONS.verbose ) then
		m.profiling.printReport()
	end
end

function cmakeoption( name, value )
	-- Allow usage: cmakeoption( 'FOO', true )
	if( type( value ) == 'boolean' ) then
		value = ( value and m.ON or m.OFF )
	end

	m.options[ name ] = value
end

-- Allow camelCase usages of functions
p.api.alias( 'cmakeproject', 'cmakeProject' )
p.api.alias( 'cmakeoption', 'cmakeOption' )

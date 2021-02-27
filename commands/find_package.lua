local p = premake
local m = p.extensions.impcmake

function m.commands.find_package( cmd )
	if( os.isfile( m.CMAKE_MODULES_CACHE_AVAILABLE ) ) then
		-- TODO: Full signature
		-- TODO: COMPONENTS and OPTIONAL_COMPONENTS
		local arguments        = table.arraycopy( cmd.arguments )
		local possible_options = { 'EXACT', 'QUIET', 'MODULE', 'REQUIRED', 'NO_POLICY_SCOPE' }
		local packageName      = table.remove( arguments, 1 )
		local version          = ( arguments[ 1 ] and not table.contains( possible_options, arguments[ 1 ] ) ) and table.remove( arguments, 1 ) or '0.0.0'
		local options          = table.intersect( possible_options, arguments )

		if( table.contains( options, 'EXACT' ) ) then
			-- TODO: EXACT
		end
		if( table.contains( options, 'QUIET' ) ) then
			-- TODO: QUET
		end
		if( table.contains( options, 'MODULE' ) ) then
			-- TODO: MODULE
		end
		if( table.contains( options, 'REQUIRED' ) ) then
			-- TODO: REQUIRED
		end
		if( table.contains( options, 'NO_POLICY_SCOPE' ) ) then
			-- TODO: NO_POLICY_SCOPE
		end

		local fileName = string.format( 'Find%s.cmake', packageName )
		local filePath = path.join( m.CMAKE_MODULES_CACHE, fileName )

		if( os.isfile( filePath ) ) then
			local prevPackage = m.currentPackage
			m.currentPackage = packageName

			cmakecache {
				[ packageName .. '_ROOT' ] = path.getdirectory( filePath ),
			}

			-- Load module script
			m.parseScript( filePath )

			m.currentPackage = prevPackage
		end

	else
		p.error( 'CMake module cache is not available for command "%s"', cmd.name )
	end
end

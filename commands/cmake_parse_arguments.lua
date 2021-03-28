local p = premake
local m = p.extensions.impcmake

function m.commands.cmake_parse_arguments( cmd )
	local args = { }
	local prefix
	local options
	local oneValueKeywords
	local multiValueKeywords

	-- Construct arg list depending on function signature
	if( cmd.arguments[ 1 ] == 'PARSE_ARGV' ) then
		local scope        = m.scope.current()
		local n            = cmd.arguments[ 2 ]
		local argc         = scope.variables.ARGC
		prefix             = cmd.arguments[ 3 ]
		options            = string.explode( cmd.arguments[ 4 ], '[; ]' )
		oneValueKeywords   = string.explode( cmd.arguments[ 5 ], '[; ]' )
		multiValueKeywords = string.explode( cmd.arguments[ 6 ], '[; ]' )

		for i=n,#argc do
			local arg = scope.variables[ 'ARGV' .. ( i - 1 ) ]
			table.insert( args, arg )
		end
	else
		prefix             = cmd.arguments[ 1 ]
		options            = string.explode( cmd.arguments[ 2 ], '[; ]' )
		oneValueKeywords   = string.explode( cmd.arguments[ 3 ], '[; ]' )
		multiValueKeywords = string.explode( cmd.arguments[ 4 ], '[; ]' )

		for i=5,#cmd.arguments do
			args = table.join( args, string.explode( cmd.arguments[ i ], '[; ]' ) )
		end
	end

	local scope = m.scope.current()

	-- For all options, set them to TRUE if they are in the argument list. FALSE otherwise.
	for i,option in ipairs( options ) do
		local index = table.indexof( args, option )
		if( index ) then
			table.remove( args, index )
			scope.variables[ prefix .. '_' .. option ] = m.TRUE
		else
			scope.variables[ prefix .. '_' .. option ] = m.FALSE
		end
	end

	local keywordsMissingValues = { }
	local i                     = 1
	while( i <= #args ) do
		local keyword = args[ i ]
		local next    = i + 1

		if( table.contains( oneValueKeywords, keyword ) ) then
			if( next > #args or table.contains( oneValueKeywords, args[ next ] ) or table.contains( multiValueKeywords, args[ next ] ) ) then
				table.insert( keywordsMissingValues, keyword )
			else
				scope.variables[ prefix .. '_' .. keyword ] = args[ next ]
				table.remove( args, next )
			end

			table.remove( args, i )
			
		elseif( table.contains( multiValueKeywords, keyword ) ) then
			local multiValues = { }
			while( next <= #args and not table.contains( oneValueKeywords, args[ next ] ) and not table.contains( multiValueKeywords, args[ next ] ) ) do
				table.insert( multiValues, args[ next ] )
				table.remove( args, next )
			end

			if( table.isempty( multiValues ) ) then
				table.insert( keywordsMissingValues, keyword )
			else
				scope.variables[ prefix .. '_' .. keyword ] = table.concat( multiValues, ';' )
			end

			table.remove( args, i )
			
		else
			i = next
		end
	end

	-- value keywords that were given no values at all are collected
	if( table.isempty( keywordsMissingValues ) ) then
		scope.variables[ prefix .. '_KEYWORDS_MISSING_VALUES' ] = nil
	else
		scope.variables[ prefix .. '_KEYWORDS_MISSING_VALUES' ] = table.concat( keywordsMissingValues, ';' )
	end

	-- All remaining arguments are collected
	if( table.isempty( args ) ) then
		scope.variables[ prefix .. '_UNPARSED_ARGUMENTS' ] = nil
	else
		scope.variables[ prefix .. '_UNPARSED_ARGUMENTS' ] = table.concat( args, ';' )
	end
end

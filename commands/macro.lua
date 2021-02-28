local p = premake
local m = p.extensions.impcmake

m.commands[ 'macro' ] = function( cmd )
	local macroName = cmd.arguments[ 1 ]
	
	m.commands[ macroName ] = function( cmd )
		m.functions.invoke( cmd )
	end

	m.functions.startRecording( macroName )
end

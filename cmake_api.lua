local p = premake
local m = p.extensions.impcmake

p.api.register {
	name  = 'cmakecache',
	scope = 'workspace',
	kind  = 'key-string',
}

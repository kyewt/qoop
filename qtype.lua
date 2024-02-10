local insert, remove, find, unpack = table.insert, table.remove, table.find, table.unpack

local qtypes = {}
local qtypeProxy = {}

local getTypes = function()
	local qtypesCopy = {}
	for _, qtype in ipairs(qtypes) do insert(qtypesCopy, qtype) end
	return qtypesCopy
end
local tryGet = function(object)
	if type(object) ~= "table" then return false, "bad type to object expected table" end
	local mt = getmetatable(object)
	if not mt then return false, "object has no metatable" end
	local qtype = mt.qtype
	if qtype == nil then return false, "object's metatable has no key \"qtype\"" end
	if not find(qtypes, qtype) then return false, "object's qtype does not exist" end
	return true, nil, qtype
end
local get = function(object)
	local success, err, qtype = tryGet(object)
	if not success then error(err) end
	return qtype
end
local getTypeTree = function(object)
	local success, err, qtype = tryGet(object)
	if not success then error(err) end
	local typeTree = {qtype}
	local getInherited getInherited = function(qtype)
		for _, inheritedType in ipairs(qtype.getInheritedTypes()) do
			insert(typeTree, inheritedType)
			getInherited(inheritedType)
		end
	end
	getInherited(qtype)
	return typeTree
end
local isOf = function(compareType, compareToType)
	if not find(qtypes, compareType) then error("bad type to compareType expected qtype") end
	if not find(qtypes, compareToType) then error("bad type to compareToType expected qtype") end
	if compareType == compareToType then return true end
	local checkTree checkTree = function(inheriteds)
		for _, inherited in ipairs(inheriteds) do
			if inherited == compareToType then return true end
			return checkTree(inherited:getInheritedTypes())
		end
		return false
	end
	return checkTree(compareType:getInheritedTypes())
end
local isA = function(object, varCompareToType)
	local compareToType
	if find(qtypes, varCompareToType) then
		compareToType = varCompareToType
	else
		if type(varCompareToType) ~= "string" then error("bad type to varCompareToType expected string or qtype") end
		for _, qtype in ipairs(qtypes) do
			if qtype.name == varCompareToType then compareToType = qtype end
		end
		if not compareToType then error("no qtype by the name \""..varCompareToType.."\" exists") end
	end
	--if type(typeName) ~= "string" then error("bad type to typeName expected string") end
	local success, err, compareType = tryGet(object)
	if not success then error(err) end
	if not compareType then error("object has no qtype") end
	--local compareToType = nil
	--for _, qtype in ipairs(qtypes) do if qtype.name == typeName then compareToType = qtype end end
	--if not compareToType then error("no qtype by the name \""..typeName.."\" exists") end
	local checkTree checkTree = function(qtype)
		if qtype == compareToType then return true end
		for _, inheritedType in ipairs(qtype.getInheritedTypes()) do
			if checkTree(inheritedType) then return true end
		end
		return false
	end
	return checkTree(compareType)
end
local isInt = function(object)
	if type(object) == 'number' and object == math.floor(object) then return true end
	return false
end
local isPosInt = function(object)
	if type(object) == 'number' and object == math.floor(object) and object > 0 then return true end
	return false
end
local methods = {
	getTypes = getTypes,
	tryGet = tryGet,
	get = get,
	getTypeTree = getTypeTree,
	isOf = isOf,
	isA = isA,
	isInt = isInt,
	isPosInt = isPosInt
}
local qtypeMT = {
	__index = function(self, k)
		for methodName, method in pairs(methods) do
			if methodName ~= k then continue end
			return function(...)
				local args = {...}
				if args[1] == self then remove(args, 1) end
				return method(unpack(args))
			end
		end
		for _, qtype in ipairs(qtypes) do
			if qtype.name == k then return qtype end
		end
		error(tostring(k).." is not a member of qtype")
	end,
	__newindex = function(self) error("cannot set member of qtype") end,
	__tostring = function() return "qtype" end,
	__call = function(self, typeName, ...)
		if type(typeName) ~= "string" then error("bad type to typeName expected string") end
		local typesInherited = {}
		do
			local varInheriteds = {...}
			for _, inherited in ipairs(varInheriteds) do
				if find(qtypes, inherited) then
					insert(typesInherited, inherited)
				elseif type(inherited) == "string" then
					local inheritedType = nil
					for _, qtype in ipairs(qtypes) do if qtype.name == inherited then inheritedType = qtype end end
					if not inheritedType then error("no qtype by the name \""..inherited.."\" exists") end
					insert(typesInherited, inheritedType)
				else
					error("bad contents of varInheriteds expected string or qtype")
				end
			end
		end
		local qtypeProxy = {}
		local fields = {
			name = typeName
		}
		local methods = {
			getInheritedTypes = function()
				local inherited = {}
				for _, qtypeInherited in ipairs(typesInherited) do insert(inherited, qtypeInherited) end
				return inherited
			end,
		}
		local qtypeMT = {
			__index = function(self, k)
				for fieldName, field in pairs(fields) do
					if fieldName == k then return field end
				end
				for methodName, method in pairs(methods) do
					if methodName ~= k then continue end
					return function(...)
						local args = {...}
						if args[1] == self then remove(args, 1) end
						return method(self, unpack(args))
					end
				end
				error(tostring(k).." is not a member of qtype "..tostring(self))
			end,
			__newindex = function(self) error("cannot set member of qtype "..tostring(self)) end,
			__tostring = function() return typeName end
		}
		setmetatable(qtypeProxy, qtypeMT)
		insert(qtypes, qtypeProxy)
		return qtypeProxy
	end,
}

setmetatable(qtypeProxy, qtypeMT)
return qtypeProxy
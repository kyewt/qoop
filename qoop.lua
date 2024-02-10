-- Config
local isRoblox = true
local spillContentsTo_G = true
-- End Config

local qtype = _G.qtype
local insert, remove, find, unpack = table.insert, table.remove, table.find, table.unpack
local math_abs = math.abs

local getModuleName = function(module)
	if isRoblox then return module.Name end
	local splitStr = string.split(module, "/")
	return splitStr[#splitStr]
end

local qclass, qenum, qinterface

local classes = {}
local classModules = {}
local enums = {}
local enumModules = {}
local interfaceType = qtype("qinterface")
local interfaces = {}
local interfaceModules = {}

do -- Classes
	local qclassProxy, fields, methods = {}, {}, {}
	local qclassType, qclassUnfinalizedType, qInstanceType, baseAccessorType, fviType = qtype("qclass"), qtype("qclassUnfinalized"), qtype("qinstance"), qtype("baseAccessor"), qtype("fieldValueInitializer")
	local classInheriteds = {}
	local classDatas = {}
	local memberDatas = {}
	local classModules = {}
	local classesAccessor = setmetatable({}, {
		__metatable = {},
		__index = function(_, k)
			local class = classes[k]
			if not class then
				local module = classModules[k]
				if module then return require(module) end
			end
			return class
		end,
		__newindex = function() error('cannot set member of \'classes\'') end
	})

	local abstract__call = function(self) error('cannot instantiate abstract class \''..type(self)..'\'') end
	local nilProxy = setmetatable({}, {__tostring = function() tostring(nil) end})
	local badReturn = {}
	local destroyedMT = {
		__index = function() error('cannot read index of destroyed instance') end,
		__newindex = function() error('cannot set index of destroyed instance') end,
		__call = function() error('cannot call destroyed instance') end,
		__tostring = function() return 'destroyed instance' end
	}

	local doesMemberExist = function(memberData, name)
		while memberData do
			for _, memberName in pairs(memberData.memberNames) do
				if memberName == name then return true end
			end
			memberData = memberData.inheritedMemberData
		end
		return false
	end

	local makeProperty = function(className, propertyName, getter, setter, init)
		if not setter and not init then setter = function() error('cannot set '..className..'.'..propertyName) end end
		return {getter = getter, setter = setter, init = init}
	end
	
	local translations = {
		instanceFields = "nearestIFields",
		readonlyInstanceFields = "nearestIRFields",
		staticFields = "nearestSFields",
		readonlyStaticFields = "nearestSRFields",
		instanceProperties = "nearestIProperties",
		staticProperties = "nearestSProperties",
		instanceMethods = "nearestIMethods",
		staticMethods = "nearestSMethods",
		constructors = "constructor",
		destructors = "destructor"
	}

	local extend = function(className, inheritedClassName, abstract, ...)
		if type(className) ~= 'string' then error('bad type: expected \'string\', got \''..type(className)..'\'') end
		if classes[className] then error("a qclass by the name \""..className.."\" already exists") end
		if enums[className] then error("a qenum by the name \""..className.."\" already exists") end
		if interfaces[className] then error("a qinterface by the name \""..className.."\" already exists") end
		if inheritedClassName then
			if type(inheritedClassName) ~= 'string' then error('bad type: expected \'string\' or \'nil\' or \'false\', got \''..type(inheritedClassName)..'\'') end
			
			if not classesAccessor[inheritedClassName] then error('inherited class does not exist') end
		end
		local interfaces = {...}
		do
			local counts = {}
			for _, interface in ipairs(interfaces) do
				if not qtype.isA(interface, interfaceType) then error("bad contents of interfaces expected "..tostring(interfaceType)) end
				counts[interface] = 0
			end
			for _, interface in ipairs(interfaces) do
				counts[interface] = counts[interface] + 1
				if counts[interface] > 1 then error("duplicate of "..tostring(interface).." was found in interfaces") end
			end
		end
		
		local interfaceClassTypes = {}
		local interfaceInstanceTypes = {}
		for _, interface in ipairs(interfaces) do
			insert(interfaceClassTypes, interface.classType)
			insert(interfaceInstanceTypes, interface.instanceType)
		end
		
		local classType = false
		local instanceType = false
		local inheritedClass = false
		local inheritedClassData = false
		local inheritedMemberData = false
		if inheritedClassName then
			inheritedClass = classesAccessor[inheritedClassName]
			for _, interface in ipairs(interfaces) do
				if qtype.isA(inheritedClass, interface.classType) then error(className.."\'s inherited qclass "..tostring(inheritedClass).." already implements qinterface "..tostring(interface)) end
			end
			inheritedClassData = classDatas[inheritedClassName]
			inheritedMemberData = inheritedClassData.memberData
			classType = qtype("qclass<"..className..">", qtype.get(inheritedClass), unpack(interfaceClassTypes))
			instanceType = qtype(className, inheritedClassData.instanceType, unpack(interfaceInstanceTypes))
		else
			classType = qtype("qclass<"..className..">", qclassType, unpack(interfaceClassTypes))
			instanceType = qtype(className, qInstanceType, unpack(interfaceInstanceTypes))
		end

		local memberNames = {}
		local categorizedMemberNames = {
			instanceFields = {},
			staticFields = {},
			readonlyInstanceFields = {},
			readonlyStaticFields = {},
			instanceProperties = {},
			staticProperties = {},
			instanceMethods = {},
			staticMethods = {},
			constructors = {},
			destructors = {}
		}
		local constructor = {}
		local destructor = {}
		local nearestConstructor = {}
		local nearestDestructor = {}
		local sFieldContainers = {}
		local srFieldContainers = {}
		local nearestMembers = {}
		local nearestIFields = {}
		local nearestSFields = {}
		local nearestIRFields = {}
		local nearestSRFields = {}
		local nearestIProperties = {}
		local nearestSProperties = {}
		local nearestIMethods = {}
		local nearestSMethods = {}
		local memberData = {
			inheritedMemberData = inheritedMemberData,
			memberNames = memberNames,
			categorizedMemberNames = categorizedMemberNames,
			constructor = constructor,
			destructor = destructor,
			nearestConstructor = nearestConstructor,
			nearestDestructor = nearestDestructor,
			sFieldContainers = sFieldContainers,
			srFieldContainers = srFieldContainers,
			nearestMembers = nearestMembers,
			nearestIFields = nearestIFields,
			nearestSFields = nearestSFields,
			nearestIRFields = nearestIRFields,
			nearestSRFields = nearestSRFields,
			nearestIProperties = nearestIProperties,
			nearestSProperties = nearestSProperties,
			nearestIMethods = nearestIMethods,
			nearestSMethods = nearestSMethods
		}
		
		if memberData.inheritedMemberData then
			local fillNearest = function(inherited, nearestMembers)
				for name, value in pairs(inherited) do
					if nearestMembers[name] ~= nil then continue end
					nearestMembers[name] = value
				end
			end
			local inherited = inheritedMemberData
			fillNearest(inherited.nearestConstructor, nearestConstructor)
			fillNearest(inherited.nearestDestructor, nearestDestructor)
			fillNearest(inherited.nearestIFields, nearestIFields)
			fillNearest(inherited.nearestIRFields, nearestIRFields)
			fillNearest(inherited.nearestSFields, nearestSFields)
			fillNearest(inherited.nearestSRFields, nearestSRFields)
			fillNearest(inherited.nearestIProperties, nearestIProperties)
			fillNearest(inherited.nearestSProperties, nearestSProperties)
			fillNearest(inherited.nearestIMethods, nearestIMethods)
			fillNearest(inherited.nearestSMethods, nearestSMethods)
		end
		memberDatas[className] = memberData

		local classData = {
			className = className,
			inheritedClassName = inheritedClassName,
			inheritedClass = inheritedClass,
			classType = classType,
			instanceType = instanceType,
			memberData = memberData
		}
		classDatas[className] = classData

		--Predefining finalized class proxy
		local cProxy = {}
		local static__index = function(self, k)
			for name, value in pairs(nearestSFields) do
				if name ~= k then continue end
				local returnVal = value()[1]
				if returnVal == nilProxy then returnVal = nil end
				return returnVal
			end
			for name, value in pairs(nearestSRFields) do
				if name ~= k then continue end
				local returnVal = value()[1]
				if returnVal == nilProxy then returnVal = nil end
				return returnVal
			end
			for name, value in pairs(nearestSProperties) do
				if name ~= k then continue end
				local value = value.getter
				if not value then continue end
				return value(cProxy)
			end
			for name, value in pairs(nearestSMethods) do
				if name ~= k then continue end
				return function(...)
					local args = {...}
					if args[1] == self then remove(args, 1) end
					local returnValue = value(cProxy, unpack(args))
					return returnValue
				end 
			end
			error(k.." is not a readable static member of "..className)
		end
		local static__newindex = function(self, k, v)
			for name, sField in pairs(nearestSFields) do
				if name ~= k then continue end
				sField()[1] = v
				return
			end
			for name, property in pairs(nearestSProperties) do
				if name ~= k then continue end
				property.setter(cProxy, v)
			end
			error(tostring(k).." is not a settable static member of "..className)
		end
		--Defining unfinalized class proxy
		local finalized = false
		do
			local definitionFuncs = {
				setField = function(self, name, value, readonly)
					if finalized then error('cannot call this method on finalized class \''..className..'\'') end -- these might be completely unnecessary
					if self ~= cProxy then error('function must be called as a method using the \':\' operator') end
					if type(name) ~= 'string' then error('bad type: expected \'string\', got \''..type(name)..'\'') end
					if name == "Destroy" then error("member name \"Destroy\" reserved for destructor") end
					if doesMemberExist(memberData, name) then error('a member with the name \''..name..'\' already exists in class \''..className..'\'') end
					if value == nil then value = nilProxy end
					if readonly then
						nearestIRFields[name] = value
						insert(categorizedMemberNames.readonlyInstanceFields, name)
					else
						nearestIFields[name] = value
						insert(categorizedMemberNames.instanceFields, name)
					end
					insert(memberNames, name)
				end,
				setStaticField = function(self, name, value, readonly)
					if finalized then error('cannot call this method on finalized class \''..className..'\'') end
					if self ~= cProxy then error('function must be called as a method using the \':\' operator') end
					if type(name) ~= 'string' then error('bad type: expected \'string\', got \''..type(name)..'\'') end
					if name == "Destroy" then error("member name \"Destroy\" reserved for destructor") end
					if doesMemberExist(memberData, name) then error('a member with the name \''..name..'\' already exists in class \''..className..'\'') end
					if value == nil then value = nilProxy end
					if readonly then
						srFieldContainers[name] = {value}
						nearestSRFields[name] = function() return srFieldContainers[name] end
						insert(categorizedMemberNames.readonlyStaticFields, name)
					else
						sFieldContainers[name] = {value}
						nearestSFields[name] = function() return sFieldContainers[name] end
						insert(categorizedMemberNames.staticFields, name)
					end
					insert(memberNames, name)
				end,
				setProperty = function(self, name, getter, setter, init)
					if finalized then error('cannot call this method on finalized class \''..className..'\'') end
					if self ~= cProxy then error('function must be called as a method using the \':\' operator') end
					if type(name) ~= 'string' then error('bad type: expected \'string\', got \''..type(name)..'\'') end
					if name == "Destroy" then error("member name \"Destroy\" reserved for destructor") end
					if doesMemberExist(memberData, name) then error('a member with the name \''..name..'\' already exists in class \''..className..'\'') end
					if getter ~= nil and type(getter) ~= 'function' then error('bad type: expected \'nil\' or \'function\', got \''..type(getter)..'\'') end
					if setter ~= nil and type(setter) ~= 'function' then error('bad type: expected \'nil\' or \'function\', got \''..type(setter)..'\'') end
					if init ~= nil and type(init) ~= 'function' then error('bad type: expected \'nil\' or \'function\', got \''..type(init)..'\'') end
					if setter and init then error('property \''..name..'\' of class \''..className..'\' cannot be asigned both a setter and an init') end
					local property = makeProperty(className, name, getter, setter, init)
					nearestIProperties[name] = property
					insert(categorizedMemberNames.instanceProperties, name)
					insert(memberNames, name)
				end,
				setStaticProperty = function(self, name, getter, setter)
					if finalized then error('cannot call this method on finalized class \''..className..'\'') end
					if self ~= cProxy then error('function must be called as a method using the \':\' operator') end
					if type(name) ~= 'string' then error('bad type: expected \'string\', got \''..type(name)..'\'') end
					if name == "Destroy" then error("member name \"Destroy\" reserved for destructor") end
					if doesMemberExist(memberData, name) then error('a member with the name \''..name..'\' already exists in class \''..className..'\'') end
					if getter ~= nil and type(getter) ~= 'function' then error('bad type: expected \'nil\' or \'function\', got \''..type(getter)..'\'') end
					if setter ~= nil and type(setter) ~= 'function' then error('bad type: expected \'nil\' or \'function\', got \''..type(setter)..'\'') end
					local property = makeProperty(className, name, getter, setter)
					nearestSProperties[name] = property
					insert(categorizedMemberNames.staticProperties, name)
					insert(memberNames, name)
				end,
				setMethod = function(self, name, func)
					if finalized then error('cannot call this method on finalized class \''..className..'\'') end
					if self ~= cProxy then error('function must be called as a method using the \':\' operator') end
					if type(name) ~= 'string' then error('bad type: expected \'string\', got \''..type(name)..'\'') end
					if name == "Destroy" then error("member name \"Destroy\" reserved for destructor") end
					if type(func) ~= 'function' then error('bad type: expected \'function\', got \''..type(func)..'\'') end
					if doesMemberExist(memberData, name) then error('a member with the name \''..name..'\' already exists in class \''..className..'\'') end
					nearestIMethods[name] = func
					insert(categorizedMemberNames.instanceMethods, name)
					insert(memberNames, name)
				end,
				setStaticMethod = function(self, name, func)
					if finalized then error('cannot call this method on finalized class \''..className..'\'') end
					if self ~= cProxy then error('function must be called as a method using the \':\' operator') end
					if type(name) ~= 'string' then error('bad type: expected \'string\', got \''..type(name)..'\'') end
					if name == "Destroy" then error("member name \"Destroy\" reserved for destructor") end
					if type(func) ~= 'function' then error('bad type: expected \'function\', got \''..type(func)..'\'') end
					if doesMemberExist(memberData, name) then error('a member with the name \''..name..'\' already exists in class \''..className..'\'') end
					nearestSMethods[name] = func
					insert(categorizedMemberNames.staticMethods, name)
					insert(memberNames, name)
				end,
				setConstructor = function(self, func)
					if finalized then error('cannot call this method on finalized class \''..className..'\'') end
					if self ~= cProxy then error('function must be called as a method using the \':\' operator') end
					if type(func) ~= 'function' then error('bad type: expected \'function\', got \''..type(func)..'\'') end
					if constructor[1] then error('constructor of class \''..className..'\' already exists') end
					constructor[1] = func
					nearestConstructor[1] = func
				end,
				setDestructor = function(self, func)
					if finalized then error('cannot call this method on finalized class \''..className..'\'') end
					if self ~= cProxy then error('function must be called as a method using the \':\' operator') end
					if type(func) ~= 'function' then error('bad type: expected \'function\', got \''..type(func)..'\'') end
					if destructor[1] then error('destructor of class \''..className..'\' already exists') end
					destructor[1] = func
					nearestDestructor[1] = func
				end,
				overrideMethod = function(self, name, func)
					if finalized then error('cannot call this method on finalized class \''..className..'\'') end
					if self ~= cProxy then error('function must be called as a method using the \':\' operator') end
					if type(name) ~= 'string' then error('bad type: expected \'string\', got \''..type(name)..'\'') end
					if name == "Destroy" then error("member name \"Destroy\" reserved for destructor") end
					if type(func) ~= 'function' then error('bad type: expected \'function\', got \''..type(func)..'\'') end
					if memberNames[name] then error ("a member by the name \""..name.."\" exists in superclasses of class \""..className.."\"") end
					if not nearestIMethods[name] then error('no instance method with the name \''..name..'\' exists in superclasses of class \''..className..'\'') end
					nearestIMethods[name] = func
					insert(categorizedMemberNames.instanceMethods, name)
					insert(memberNames, name)
				end,
				overrideProperty = function(self, name, getter, setter)
					if finalized then error('cannot call this method on finalized class \''..className..'\'') end
					if self ~= cProxy then error('function must be called as a method using the \':\' operator') end
					if type(name) ~= 'string' then error('bad type: expected \'string\', got \''..type(name)..'\'') end
					if name == "Destroy" then error("member name \"Destroy\" reserved for destructor") end
					if getter ~= nil and type(getter) ~= 'function' then error('bad type: expected \'nil\' or \'function\', got \''..type(getter)..'\'') end
					if setter ~= nil and type(setter) ~= 'function' then error('bad type: expected \'nil\' or \'function\', got \''..type(setter)..'\'') end
					if memberNames[name] then error ("a member by the name \""..name.."\" exists in superclasses of class \""..className.."\"") end
					if not nearestIProperties[name] then error('no instance property with the name \''..name..'\' exists in superclasses of class \''..className..'\'') end
					local property = makeProperty(className, name, getter, setter)
					nearestIProperties[name] = property
					insert(categorizedMemberNames.instanceProperties, name)
					insert(memberNames, name)
				end,
				overrideField = function(self, name, value, readonly)
					if finalized then error('cannot call this method on finalized class \''..className..'\'') end
					if self ~= cProxy then error('function must be called as a method using the \':\' operator') end
					if type(name) ~= 'string' then error('bad type: expected \'string\', got \''..type(name)..'\'') end
					if name == "Destroy" then error("member name \"Destroy\" reserved for destructor") end
					if memberNames[name] then error ("a member by the name \""..name.."\" exists in superclasses of class \""..className.."\"") end
					if not nearestIFields[name] and not nearestIRFields[name] then error('no field with the name \''..name..'\' exists in superclasses of class \''..className..'\'') end
					if value == nil then value = nilProxy end
					if readonly then
						nearestIRFields[name] = value
						insert(categorizedMemberNames.readonlyInstanceFields, name)
					else
						nearestIFields[name] = value
						insert(categorizedMemberNames.instanceFields, name)
					end
					insert(memberNames, name)
				end,
				--Defining and setting finalized class proxy
				finalize = function()
					if finalized then error('cannot call this method on finalized class \''..className..'\'') end
					
					
					for _, interface in ipairs(interfaces) do
						for memberType, names in pairs(interface:getMembers()) do
							local members = memberData[translations[memberType]]
							for _, name in ipairs(names) do
								if not members[name] then error("qclass "..className.." does not contain member \""..name.."\" of qinterface "..tostring(interface)) end
							end
						end
					end
					
					
					local cProxyMT = {
						qtype = classType,
						__index = static__index,
						__newindex = static__newindex,
						__tostring = function() return className end
					}
					classes[className] = cProxy
					classInheriteds[className] = classes[inheritedClassName]
					if abstract then
						cProxyMT.__call = abstract__call 
					else
						cProxyMT.__call = function(self, ...)
							--Instance data
							local fields, readonlyFields = {}, {}
							for name, value in pairs(nearestIFields) do
								local mt = getmetatable(value)
								if mt and mt.qtype == fviType then value = value() end
								if value == nil then value = nilProxy end
								fields[name] = value
							end
							for name, value in pairs(nearestIRFields) do
								local mt = getmetatable(value)
								if mt and mt.qtype == fviType then value = value() end
								if value == nil then value = nilProxy end
								readonlyFields[name] = value
							end
							--Proxy
							local iProxy = {}
							local iProxyMT
							local instance__index = function(self, k)
								for name, value in pairs(fields) do
									if name ~= k then continue end
									if value == nilProxy then value = nil end
									return value
								end
								for name, value in pairs(readonlyFields) do
									if name ~= k then continue end
									if value == nilProxy then value = nil end
									return value
								end
								for name, value in pairs(nearestIProperties) do
									if name ~= k then continue end
									local value = value.getter
									if not value then continue end
									return value(self)
								end
								for name, value in pairs(nearestIMethods) do
									if name ~= k then continue end
									return function(...)
										local args = {...}
										if args[1] == iProxy then remove(args, 1) end
										local rv = {value(iProxy, unpack(args))}
										return unpack(rv)
									end
								end
								for name, value in pairs(nearestSFields) do
									if name ~= k then continue end
									local returnVal = value()[1]
									if returnVal == nilProxy then returnVal = nil end
									return returnVal
								end
								for name, value in pairs(nearestSRFields) do
									if name ~= k then continue end
									local returnVal = value()[1]
									if returnVal == nilProxy then returnVal = nil end
									return returnVal
								end
								for name, value in pairs(nearestSProperties) do
									if name ~= k then continue end
									local value = value.getter
									if not value then continue end
									return value(cProxy)
								end
								for name, value in pairs(nearestSMethods) do
									if name ~= k then continue end
									return function(...)
										local args = {...}
										if args[1] == self then remove(args, 1) end
										local returnValue = value(cProxy, unpack(args))
										return returnValue
									end 
								end
								if k == "Destroy" then
									local destructor = nearestDestructor[1]
									if destructor then return destructor end
								end
								error(k.." is not a readable member of "..tostring(iProxy))
							end
							local instance__newindex = function(self, k, v)
								if fields[k] ~= nil then
									if v == nil then v = nilProxy end
									fields[k] = v
									return
								end
								for name, property in pairs(nearestIProperties) do
									if name ~= k then continue end
									property.setter(self, v)
									return
								end
								for name, sField in pairs(nearestSFields) do
									if name ~= k then continue end
									if v == nil then v = nilProxy end
									sField()[1] = v
									return
								end
								for name, property in pairs(nearestSProperties) do
									if name ~= k then continue end
									property.setter(cProxy, v)
								end
								error(tostring(k).." is not a settable member of "..tostring(iProxy))
							end
							local constructor__newindex = function(self, k, v)
								if v == nil then v = nilProxy end
								if fields[k] ~= nil then fields[k] = v return end
								if readonlyFields[k] ~= nil then readonlyFields[k] = v return end
								for name, property in pairs(nearestIProperties) do
									if name ~= k then continue end
									property.setter(self, v)
									return
								end
								for name, sField in pairs(nearestSFields) do
									if name ~= k then continue end
									sField()[1] = v
									return
								end
								for name, property in pairs(nearestSProperties) do
									if name ~= k then continue end
									property.setter(cProxy, v)
								end
							end
							local instance__tostring = function(self)
								for name, method in pairs(nearestIMethods) do
									if name ~= "tostring" then continue end
									local returnValue = method(iProxy)
									if type(returnValue) ~= "string" then error("bad return value from \"tostring\" expected string") end
									return returnValue
								end
								return className
							end
							iProxyMT = {
								qtype = instanceType,
								baseMemberData = memberData,
								__index = instance__index,
								__newindex = constructor__newindex,
								__tostring = instance__tostring
							}
							setmetatable(iProxy, iProxyMT)
							local constructor = nearestConstructor[1]
							if constructor then constructor(iProxy, ...) end
							iProxyMT.__newindex = instance__newindex
							return iProxy
						end
					end
					finalized = true
					setmetatable(cProxy, cProxyMT)
				end,
			}
			local unfinalizedCProxyMT = {
				qtype = qclassUnfinalizedType,
				__index = function(self, k)
					for funcName, func in pairs(definitionFuncs) do
						if funcName ~= k then continue end
						return func
					end
					error(tostring(k).." is not a member of unfinalized class \""..tostring(self).."\"")
				end,
				__newindex = function(self) error("Cannot set index of unfinalized class "..tostring(self)) end,
				__tostring = function() return className end
			}
			setmetatable(cProxy, unfinalizedCProxyMT)
		end

		--Define base accessor
		if inheritedClassName then
			--local baseAccessorType = "baseAccessor<"..className..">"
			local thisBaseAccessorType = qtype("baseAccessor<"..className..">", baseAccessorType)
			--qtype.create(baseAccessorType)
			insert(memberNames, "base")
			insert(categorizedMemberNames.instanceProperties, "base")
			nearestIProperties["base"] = makeProperty(className, "base",
				function(inst)
					local instMT = getmetatable(inst)
					if not instMT.baseMemberData.inheritedMemberData then error("no base class of "..tostring(inst).." was found") end
					return setmetatable(
						{},
						{
							qtype = thisBaseAccessorType,
							__index = function(self, k)
								local memberData = instMT.baseMemberData
								local inheritedMemberData = memberData.inheritedMemberData
								instMT.baseMemberData = inheritedMemberData
								for name, property in pairs(inheritedMemberData.nearestIProperties) do
									if name ~= k then continue end
									local returnValue = property.getter(inst)
									instMT.baseMemberData = memberData
									return returnValue
								end
								for name, method in pairs(inheritedMemberData.nearestIMethods) do
									if name ~= k then continue end
									return function(...)
										local args = {...}
										if args[1] == self then remove(args, 1) end
										local methodReturnValue = method(inst, unpack(args))
										instMT.baseMemberData = memberData
										return methodReturnValue
									end
								end
								for name, sField in pairs(inheritedMemberData.nearestSFields) do
									if name ~= k then continue end
									local returnVal = sField()[1]
									if returnVal == nilProxy then returnVal = nil end
									instMT.baseMemberData = memberData
									return returnVal
								end
								for name, sField in pairs(inheritedMemberData.nearestSRFields) do
									if name ~= k then continue end
									local returnVal = sField()[1]
									if returnVal == nilProxy then returnVal = nil end
									instMT.baseMemberData = memberData
									return returnVal
								end
								for name, property in pairs(inheritedMemberData.nearestSProperties) do
									if name ~= k then continue end
									local returnValue = property.getter(cProxy)
									instMT.baseMemberData = memberData
									return returnValue
								end
								for name, method in pairs(inheritedMemberData.nearestSMethods) do
									if name ~= k then continue end
									return function(...)
										local args = {...}
										if args[1] == self then remove(args, 1) end
										local methodReturnValue = method(cProxy, unpack(args))
										instMT.baseMemberData = memberData
										return methodReturnValue
									end
								end
								if k == "Destroy" then
									local destructor = inheritedMemberData.nearestDestructor[1]
									if destructor then
										return function(...)
											local args = {...}
											if args[1] == self then remove(args, 1) end
											local methodReturnValue = destructor(inst, unpack(args))
											instMT.baseMemberData = memberData
											return methodReturnValue
										end
									end
								end
								error("base class of "..tostring(inst).." does not contain readable member "..tostring(k))
							end,
							__call = function(self, ...)
								local memberData = instMT.baseMemberData
								local inheritedMemberData = memberData.inheritedMemberData
								instMT.baseMemberData = inheritedMemberData
								inheritedMemberData.nearestConstructor[1](inst, ...)
								instMT.baseMemberData = memberData
							end,
							__newindex = function(self, k, v)
								local memberData = instMT.baseMemberData
								local inheritedMemberData = memberData.inheritedMemberData
								instMT.baseMemberData = inheritedMemberData
								for name, sField in pairs(inheritedMemberData.nearestSFields) do
									if name ~= k then continue end
									if v == nil then v = nilProxy end
									sField()[1] = v
									instMT.baseMemberData = memberData
									return
								end
								for name, property in pairs(inheritedMemberData.nearestIProperties) do
									if name ~= k then continue end
									property.setter(inst, v)
									instMT.baseMemberData = memberData
									return
								end
								for name, property in pairs(inheritedMemberData.nearestSProperties) do
									if name ~= k then continue end
									property.setter(cProxy, v)
									instMT.baseMemberData = memberData
									return
								end
								error("base class of "..tostring(inst).." does not contain settable member "..tostring(k))
							end,
						}
					)
				end,
				function(inst)
					error("cannot set "..tostring(inst)..".base")
				end
			)
		end

		return cProxy
	end
	
	local fieldValueInitializer = function(callable)
		local ty = type(callable)
		if not (ty == 'function' or ty == 'table') then error('bad type to \'callable\', expected \'function\' or \'table\', got \''..typeof(callable)..'\'') end
		if ty == 'table' then
			local mt = getmetatable(callable)
			if not mt then error('bad callable table: could not find metatable') end
			if not mt.__call and type(mt.__call) == 'function' then error('bad callable table: metatable does not contain __call function') end
		end
		return setmetatable({}, {
			qtype = fviType,
			__call = function() return callable() end,
			__index = function() error('cannot index \'fieldValueInitializer\'') end,
			__newindex = function() error('cannot set member of \'fieldValueInitializer\'') end
		})
	end
	
	fields.classes = classesAccessor
	fields.fieldValueInitializer = fieldValueInitializer
	methods.extend = extend
	methods.addModule = function(module)
		if isRoblox and (typeof(module) ~= "Instance" or not module:IsA("ModuleScript")) then
			error("bad type to module expected ModuleScript")
		elseif not isRoblox and type(module) ~= "string" then
			error("bad type to module expected string")
		end
		local moduleName = getModuleName(module)
		if classModules[moduleName] then error("a module by the name \""..moduleName.."\" already exists") end
		classModules[moduleName] = module
	end
	
	local qclassMT = {
		__call = function(self, ...) return extend(...) end,
		__index = function(self, k)
			for fieldName, field in pairs(fields) do
				if fieldName == k then return field end
			end
			for methodName, method in pairs(methods) do
				if methodName ~= k then continue end
				return function(...)
					local args = {...}
					if args[1] == self then remove(args, 1) end
					return method(unpack(args))
				end
			end
			error(tostring(k).." is not a member of qclass "..tostring(self))
		end,
		__newindex = function(self) error("cannot set member of qclass "..tostring(self)) end,
		__tostring = function(self) return "qclass" end
	}
	setmetatable(qclassProxy, qclassMT)
	qclass = qclassProxy
end

do -- Enums
	local qenumsType, qenumType, qenumItemType = qtype("qenums"), qtype("qenum"), qtype("qenumItem")
	local qenumItemCount = 0

	local makeEnum = function(name, ...)
		local members = {...}
		do
			if type(name) ~= "string" then error("bad type to name expected string") end
			if enums[name] then error("a qenum by the name \""..name.."\" already exists") end
			if classes[name] then error("a qclass by the name \""..name.."\" already exists") end
			if interfaces[name] then error("a qinterface by the name \""..name.."\" already exists") end
			
			local allMembers = {}
			for _, member in pairs(members) do
				if type(member) ~= "string" then error("bad type to member expected string") end
				if find(allMembers, member) then error("duplicate member in members") end
				insert(allMembers, member)
			end
		end

		local enumProxy = {}
		local enumItems = {}
		local methods = {
			GetEnumItems = function()
				local t = {}
				for _, enumItem in pairs(enumItems) do insert(t, enumItem) end
				return t
			end,
		}
		local makeEnumItem = function(name)
			qenumItemCount = qenumItemCount + 1
			local fields = {
				Name = name,
				Value = qenumItemCount,
				EnumType = enumProxy
			}
			local methods = {
				IsA = function(self, str)
					if str == name then return true end
					return false
				end,
			}
			local enumItemProxy = {}
			local enumItemMT = {
				qtype = qenumItemType,
				__index = function(self, k)
					for fieldName, fieldVal in pairs(fields) do
						if fieldName ~= k then continue end
						return fieldVal
					end
					for methodName, method in pairs(methods) do
						if methodName ~= k then continue end
						return function(...)
							local args = {...}
							if args[1] == self then remove(args, 1) end
							return method(self, unpack(args))
						end
					end
					error(tostring(k).." is not a member of qenumItem "..tostring(self))
				end,
				__newindex = function(self) error("cannot set member of qenumItem "..tostring(self)) end,
				__tostring = function() return name end
			}
			setmetatable(enumItemProxy, enumItemMT)
			enumItems[name] = enumItemProxy
			return enumItemProxy
		end
		local enumMT = {
			qtype = qenumType,
			__index = function(self, k)
				for _, enumItem in pairs(enumItems) do
					if enumItem.Name ~= k then continue end
					return enumItem
				end
				for methodName, method in pairs(methods) do
					if methodName ~= k then continue end
					return function(...)
						local args = {...}
						if args[1] == self then remove(args, 1) end
						return method(self, unpack(args))
					end
				end
				error(tostring(k).." is not a member of qenum "..tostring(self))
			end,
			__newindex = function(self) error("cannot set member of qenum "..tostring(self)) end,
			__tostring = function(self) return name end
		}
		setmetatable(enumProxy, enumMT)
		for _, member in ipairs(members) do makeEnumItem(member) end
		enums[name] = enumProxy
		return enumProxy
	end

	local qenumsProxy
	do
		local methods = {
			GetEnums = function()
				local t = {}
				for _, qenum in pairs(enums) do
					insert(t, qenum)
				end
				return t
			end,
		}
		qenumsProxy = setmetatable({}, {
			qtype = qenumsType,
			__call = function(self, ...) return makeEnum(...) end,
			__index = function(self, k)
				for qenumName, qenum in pairs(enums) do
					if qenumName ~= k then continue end
					return qenum
				end
				for methodName, method in pairs(methods) do
					for methodName, method in pairs(methods) do
						if methodName ~= k then continue end
						return function(...)
							local args = {...}
							if args[1] == self then remove(args, 1) end
							return method(self, unpack(args))
						end
					end
					error(tostring(k).." is not a member of qenums "..tostring(self))
				end
			end,
			__newindex = function(self) error("cannot set member of qenums "..tostring(self)) end,
			__tostring = function(self) return tostring(qenumsType) end
		})
	end
	
	qenum = qenumsProxy
end

do -- Interfaces
	interfaceAccessor = setmetatable({}, {
		__metatable = {},
		__index = function(_, k)
			local interface = interfaces[k]
			if not interface then
				local module = interfaceModules[k]
				if module then return require(module) end
			end
			return interface
		end,
		__newindex = function() error('cannot set member of \'interfaces\'') end
	})
	
	local unfinalizedType = qtype("qinterfaceUnfinalized")
	
	local makeInterface = function(iName)
		if type(iName) ~= "string" then error("bad type to name expected string") end
		if interfaces[iName] then error("a qinterface by the name \""..iName.."\" already exists") end
		if classes[iName] then error("a qclass by the name \""..iName.."\" already exists") end
		if enums[iName] then error("a qenum by the name \""..iName.."\" already exists") end
		
		local categorizedMemberNames = {
			instanceFields = {},
			staticFields = {},
			readonlyInstanceFields = {},
			readonlyStaticFields = {},
			instanceProperties = {},
			staticProperties = {},
			instanceMethods = {},
			staticMethods = {},
			constructors = {},
			destructors = {}
		}
		
		local ifProxy = {}
		local fields = {
			classType = qtype("qclass<"..iName..">"),
			instanceType = qtype(iName)
		}
		local methods = {
			getMembers = function()
				local members = {}
				for memberType, memberNames in pairs(categorizedMemberNames) do
					local newNames = {}
					for _, name in ipairs(memberNames) do insert(newNames, name) end
					members[memberType] = newNames
				end
				return members
			end,
		}
		local ifProxyMT = {
			qtype = qtype("interface<"..iName..">", interfaceType),
			__index = function(self, k)
				for fieldName, field in pairs(fields) do
					if fieldName == k then return field end
				end
				for methodName, method in pairs(methods) do
					if methodName ~= k then continue end
					return function(...)
						local args = {...}
						if args[1] == self then remove(args, 1) end
						return method(unpack(args))
					end
				end
				error(tostring(k).." is not a member of qinterface "..tostring(self))
			end,
			__newindex = function(self) error("cannot set member of "..tostring(self)) end,
			__tostring = function(self) return tostring(qtype.get(self)) end
		}
		do
			local doesMemberExist = function(name)
				for _, category in pairs(categorizedMemberNames) do
					for _, existingName in ipairs(category) do if existingName == name then return true end end
				end
				return false, "a member by the name of \""..name.."\" already exists in qinterface "..iName
			end
			
			local finalize = function()
				setmetatable(ifProxy, ifProxyMT)
				interfaces[iName] = ifProxy
			end
			
			local methods = {
				setField = function(name)
					local memberExists, err = doesMemberExist(name)
					if memberExists then error(err) end
					insert(categorizedMemberNames.instanceFields, name)
				end,
				setReadonlyField = function(name)
					local memberExists, err = doesMemberExist(name)
					if memberExists then error(err) end
					insert(categorizedMemberNames.readonlyInstanceFields, name)
				end,
				setProperty = function(name)
					local memberExists, err = doesMemberExist(name)
					if memberExists then error(err) end
					insert(categorizedMemberNames.instanceProperties, name)
				end,
				setMethod = function(name)
					local memberExists, err = doesMemberExist(name)
					if memberExists then error(err) end
					insert(categorizedMemberNames.instanceMethods, name)
				end,
				setStaticField = function(name)
					local memberExists, err = doesMemberExist(name)
					if memberExists then error(err) end
					insert(categorizedMemberNames.staticFields, name)
				end,
				setReadonlyStaticField = function(name)
					local memberExists, err = doesMemberExist(name)
					if memberExists then error(err) end
					insert(categorizedMemberNames.readonlyStaticFields, name)
				end,
				setStaticProperty = function(name)
					local memberExists, err = doesMemberExist(name)
					if memberExists then error(err) end
					insert(categorizedMemberNames.staticProperties, name)
				end,
				setStaticMethod = function(name)
					local memberExists, err = doesMemberExist(name)
					if memberExists then error(err) end
					insert(categorizedMemberNames.staticMethods, name)
				end,
				setConstructor = function()
					if categorizedMemberNames.constructors[1] then error("a constructor already exists in qinterface "..iName) end
					insert(categorizedMemberNames.constructors, 1)
				end,
				setDestructor = function()
					if categorizedMemberNames.destructors[1] then error("a destructor already exists in qinterface "..iName) end
					insert(categorizedMemberNames.destructors, 1)
				end,
			}
			methods.finalize = finalize
			local unfinalizedIfMT = {
				qtype = unfinalizedType,
				__index = function(self, k)
					for methodName, method in pairs(methods) do
						for methodName, method in pairs(methods) do
							if methodName ~= k then continue end
							return function(...)
								local args = {...}
								if args[1] == self then remove(args, 1) end
								return method(unpack(args))
							end
						end
						error(tostring(k).." is not a member of "..tostring(self))
					end
				end,
				__newindex = function(self) error("cannot set member of "..tostring(self)) end,
				__tostring = function() return tostring(unfinalizedType) end
			}
			setmetatable(ifProxy, unfinalizedIfMT)
		end
		return ifProxy
	end
	
	local qinterfaceProxy = {}
	local fields = {
		interfaces = interfaceAccessor
	}
	local methods = {}
	local qinterfaceMT = {
		__call = function(self, ...) return makeInterface(...) end,
		__index = function(self, k)
			for fieldName, field in pairs(fields) do
				if fieldName == k then return field end
			end
			for methodName, method in pairs(methods) do
				if methodName ~= k then continue end
				return function(...)
					local args = {...}
					if args[1] == self then remove(args, 1) end
					return method(unpack(args))
				end
			end
			error(tostring(k).." is not a member of qinterface")
		end,
		__newindex = function() error("cannot set member of qinterface") end,
		__tostring = function() return "qinterface" end
	}
	setmetatable(qinterfaceProxy, qinterfaceMT)
	qinterface = qinterfaceProxy
end




--[[
local qclass = {
	extend = extend,
	class = extend,
	classes = classesAccessor,
	classModules = classModules,
	fieldValueInitializer = fieldValueInitializer
}]]

local qoop = {
	qclass = qclass,
	qenum = qenum,
	qinterface = qinterface,
}

if spillContentsTo_G then
	for k, v in pairs(qoop) do
		_G[k] = v
	end
end

return qoop
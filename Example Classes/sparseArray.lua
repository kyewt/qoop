local isPosInt = _G.qtype.isPosInt
local floor, min = math.floor, math.min
local create, insert, remove, sort, find = table.create, table.insert, table.remove, table.sort, table.find

local sparseArray = _G.qclass.extend("sparseArray")

sparseArray:setStaticField("_placeholder", {"sparseArrayPlaceholder"}, true)

sparseArray:setField("_table", nil, true)
sparseArray:setField("_holes", nil, true)
sparseArray:setField("_peakIndex", 0)

sparseArray:setProperty(
    "size",
    function(inst)
        return #inst._table
    end,
    function(inst)
        error("cannot set ".._G.qtype.get(inst)..".size")
    end
)

sparseArray:setProperty(
    "space",
    function(inst)
        return inst.size - inst._peakIndex + #inst._holes
    end,
    function(inst)
        error("cannot set ".._G.qtype.get(inst)..".space")
    end
)

sparseArray:setMethod("_increaseSize", function(inst, amount)
    if not isPosInt(amount) then
        error("bad type to amount expected positive integer")
    end
    local size = inst.size
    local tab = inst._table
    local placeholder = inst._placeholder
    for i = 1, amount do
        local index = size + i
        tab[index] = placeholder
    end
end)

sparseArray:setMethod("_sortHoles", function(inst)
    local sortFunc = function(a, b)
        return a < b
    end
    sort(inst._holes, sortFunc)
end)

sparseArray:setMethod("get", function(inst, index)
    if not isPosInt(index) then
        error("bad type to index expected positive integer")
    end
    if index < 0 or index > inst.size then
        error("integer out of range")
    end
    local value = inst._table[index]
    if value == inst._placeholder then
        return nil
    end
    return value
end)

sparseArray:setMethod("find", function(inst, value)
    for index, existingValue in ipairs(inst._table) do
        if existingValue == value then
            return index
        end
    end
    return nil
end)

sparseArray:setMethod("getIndicesUpToPeak", function(inst)
    local indices = {}
    for i = 1, inst._peakIndex do
        insert(indices, i)
    end
    return indices
end)

sparseArray:setMethod("getAllIndicesWithoutHoles", function(inst)
    local indices = {}
    for i = 1, inst._peakIndex do
        insert(indices, i)
    end
    for _, hole in ipairs(inst._holes) do
        remove(indices, hole)
    end
    return indices
end)

sparseArray:setMethod("set", function(inst, index, value)
    if not isPosInt(index) then
        error("bad type to index expected positive integer")
    end
    local size = inst.size
    if index > size then
        local dif = index - size
        inst._increaseSize(dif)
    end
    local placeholder = inst._placeholder
    if value == nil then
        value = placeholder
    end
    local tab = inst._table
    if tab[index] ~= placeholder then
        insert(inst._holes, index)
        inst._sortHoles()
    end
    tab[index] = value
end)

sparseArray:setMethod("insert", function(inst, value)
    if value == nil then
        error("bad type to value expected a non-nil type")
    end
    local index
    local tab = inst._table
    local holes = inst._holes
    if inst.space ~= 0 then
        local hole = holes[1]
        if hole then
            index = hole
        else
            index = inst._peakIndex + 1
        end
        if tab[index] ~= inst._placeholder then
            error("insert should only place in empty slots")
        end
    else
        inst._increaseSize(1)
        local size = inst.size
        index = size
        inst._peakIndex = size
    end
    local holeIndex = find(holes, index)
    if holeIndex then
        remove(holes, index)
    end
    tab[index] = value
    return index
end)

sparseArray:setMethod("remove", function(inst, index)
    if not isPosInt(index) or index < 1 or index > inst.size then
        error("bad index expected positive integer within array range")
    end
    local tab = inst._table
    local placeholder = inst._placeholder
    local removed = false
    if tab[index] ~= placeholder then
        insert(inst._holes, index)
        inst._sortHoles()
        removed = true
        tab[index] = placeholder
    end
    return removed
end)

sparseArray:setMethod("print", function(inst)
    print(inst._table)
end)

sparseArray:setConstructor(function(inst, size)
    if size == nil then
        size = 0
    end
    if type(size) ~= "number" or size < 0 or size ~= floor(size) then
        error("bad size expected non-negative integer")
    end
    inst._table = create(size, inst._placeholder)
    inst._holes = {}
end)

sparseArray:finalize()
return sparseArray
local isPosInt = _G.qtype.isPosInt
local floor, min = math.floor, math.min
local create, insert, remove, find = table.create, table.insert, table.remove, table.find

local fixedSparseArray = _G.qclass.extend("fixedSparseArray", "sparseArray")

fixedSparseArray:setField("_size", nil, true)

fixedSparseArray:overrideProperty(
    "size",
    function(inst)
        return inst._size
    end,
    function(inst, v)
        inst.base.size = v
    end
)

fixedSparseArray:overrideMethod("_increaseSize", function(inst)
    error("cannot change size of ".._G.qtype.get(inst))
end)

fixedSparseArray:overrideMethod("set", function(inst, index, value)
    if index < 1 or index > inst.size or index ~= floor(index) then
        error("bad index expected positive integer within array range")
    end
    local placeholder = inst._placeholder
    if value == nil then
        value = placeholder
    end
    local tab = inst._table
    if tab[index] ~= placeholder then
        insert(inst._holes, index)
    end
    tab[index] = value
end)

fixedSparseArray:setMethod("setAll", function(inst, values)
    local size = inst.size
    if #values ~= size then
        error("values count and size mismatch")
    end
    local tab = inst._table
    for i = 1, size do
        tab[i] = values[i]
    end
    inst._peakIndex = size
end)

fixedSparseArray:overrideMethod("insert", function(inst, value)
    if inst.space == 0 then
        error(tostring(inst).." out of space")
    end
    if value == nil then
        error("bad type to value expected a non-nil type")
    end
    local index
    local holes = inst._holes
    local hole = holes[1]
    if hole then
        index = hole
        remove(holes, 1)
    else
        index = inst._peakIndex + 1
        inst._peakIndex = index
    end
    local tab = inst._table
    if tab[index] ~= inst._placeholder then
        insert(holes, index)
    end
    tab[index] = value
    inst._sortHoles()
    return index
end)

fixedSparseArray:setConstructor(function(inst, size, fillValue)
    if not isPosInt(size) then
        error("bad type to size expected positive integer")
    end
    if fillValue == nil then
        fillValue = inst._placeholder
    else
        inst._peakIndex = size
    end
    inst._size = size
    inst._table = create(size, fillValue)
    inst._holes = {}
end)

fixedSparseArray:finalize()
return fixedSparseArray
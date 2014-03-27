local UnitIsUnit = UnitIsUnit
local canCast = jps.canCast


local function fnMessageEval(message)
    if message == nil then
        return ""
    elseif type(message) == "string" then
        return message
    end
end

local function fnTargetEval(target)
    if target == nil then
        return "target"
    elseif type(target) == "function" then
        return target()
    else
        return target
    end
end

local function fnConditionEval(conditions)
    if conditions == nil then
        return true
    elseif type(conditions) == "boolean" then
        return conditions
    elseif type(conditions) == "number" then
        return conditions ~= 0
    elseif type(conditions) == "function" then
        return conditions()
    else
        return false
    end
end

-- { {"macro","/cast Sanguinaire"} , conditions , "target" }
-- fnParseMacro(spellTable[1][2], fnConditionEval(spellTable[2]), fnTargetEval(spellTable[3]))
local function fnParseMacro(macro, conditions, target)
    if conditions then
    	if target == nil then target = "target" end 
        -- Workaround for TargetUnit is still PROTECTED despite goblin active
        local changeTargets = UnitIsUnit(target,"target")~=1 and jps.UnitExists(target)
        if changeTargets then jps.Macro("/target "..target) end

        if type(macro) == "string" then
            local macroSpell = macro
            if string.find(macro,"%s") == nil then -- {"macro","/startattack"}
                macroSpell = macro
            else
                macroSpell = select(3,string.find(macro,"%s(.*)")) -- {"macro","/cast Sanguinaire"}
            end
            if not jps.Casting then jps.Macro(macro) end -- Avoid interrupt Channeling with Macro
            if jps.Debug then macrowrite(macroSpell,"|cff1eff00",target,"|cffffffff",jps.Message) end
            
        -- CASTSEQUENCE WORKS ONLY FOR INSTANT CAST SPELL
		-- "#showtooltip\n/cast Frappe du colosse\n/cast Sanguinaire"
		else
			jps.Macro("/cast " .. tostring(GetSpellInfo(macro)))
		end
		if changeTargets and not jps.Casting then jps.Macro("/targetlasttarget") end
	end
end

-------------------------
-- PARSE DYNAMIC
-------------------------

--[[ -- MultiTable
function jps.IsCastingPoly( unit )
	if ... then return false end
	return true
end
parseMultiUnitTable( { "shadow word: death", jps.IsCastingPoly, {"arena1","arena2","arena3"} } )

the code is equivalent to:

parseSpellTable(
 {
	 { "shadow word: death", jps.IsCastingPoly("arena1") , "arena1" },
	 { "shadow word: death", jps.IsCastingPoly("arena2") , "arena2" },
	 { "shadow word: death", jps.IsCastingPoly("arena3") , "arena3" },
 }
)
--]]

local function parseMultiUnitTable( spellTable )
	local spell = spellTable[1]
	local unitFunction = spellTable[2]
	local targets = spellTable[3]
	local message = spellTable[4]
	if message == nil then message = "" end
	local sirenTable = {}

	for _, unit in pairs(targets) do
		local unitTable = {}
		table.insert( unitTable, 1, spell )
		table.insert( unitTable, 2, unitFunction(unit) )
		table.insert( unitTable, 3, unit )
		table.insert( unitTable, 4, message..unit )
		table.insert( sirenTable, unitTable )
	end

	return parseSpellTable(sirenTable)
end

------------------------
-- PARSE
------------------------

-- rawset() and table.insert can still be used to directly modify a read-only table

--local readOnly = function(t)
--        local mt = {
--                __index=t,
--                __newindex=function(t, k, v) error("Attempt to modify read-only table", 2) end,
--                __pairs=function() return pairs(t) end,
--                __ipairs=function() return ipairs(t) end,
--                __len=function() return #t end,
--                __metatable=false
--        }
--        return setmetatable({}, mt)
--end

--local readOnly = function(t)
--        local proxy = {}
--        local mt = {
--                __index=t,
--                __newindex=function(t, k, v) error("Attempt to modify read-only table", 2) end,
--        }
--        setmetatable(proxy, mt)
--        return proxy
--end

--local readOnly = function(t)
--    local mt = setmetatable(t, {
--    	__index = function(t, index) return index end,
--    	__newindex=function(t, k, v) print("Attempt to modify read-only table") end,
--    })
--    return mt
--end

--local readOnly = function(t)
--    local mt = {
--    	__index = function(t, index) return index end, -- return rawset(t,index)
--    	__newindex=function(t, k, v) print("Attempt to modify read-only table") end,
--    }
--    return setmetatable(t, mt)
--end

parseSpellTable = function( hydraTable )
	
	local spell = nil
	local conditions = nil
	local target = nil
	local message = ""

--	proxy = setmetatable(hydraTable, {__index = function(t, index) return index end})
--	proxy = setmetatable(hydraTable, proxy) -- sets proxy to be spellTable's metatable

--	myListOfObjects = {}  
--	setmetatable(myListOfObjects, { __mode = 'v' }) --myListOfObjects is now weak  
--	myListOfObjects = setmetatable({}, {__mode = 'v' }) --creation of a weak table

	for i, spellTable in ipairs( hydraTable ) do

        if type(spellTable) == "function" then spellTable = spellTable() end
		spell = spellTable[1] 
		conditions = fnConditionEval(spellTable[2])
		target = fnTargetEval(spellTable[3])
        message = fnMessageEval(spellTable[4])
        if jps.Message ~= message then jps.Message = message end

		-- MACRO -- BE SURE THAT CONDITION TAKES CARE OF CANCAST -- TRUE or FALSE NOT NIL
		if type(spell) == "table" and spell[1] == "macro" then
			fnParseMacro(spell[2], fnConditionEval(conditions), fnTargetEval(target))
			
		-- NESTED TABLE
		elseif spell == "nested" and type(target) == "table" then
			if fnConditionEval(conditions) then
				spell,target = parseSpellTable(target)
			end

		-- MULTITARGET -- { spell , function_unit , table_unit }
		elseif type(conditions) == "function" and type(target) == "table" then
			spell,target = parseMultiUnitTable(spellTable)
			
		-- DEFAULT {spell[[, condition[, target]]}
		end

		-- Return spell if conditions are true and spell is castable.
		if spell ~= nil and conditions and canCast(spell,target) then
			return spell,target
		end
	end
end

-------------------------
-- MULTIPLE ROTATIONS
-------------------------

--function hideDropdown()
--	rotationDropdownHolder:Hide()
--end
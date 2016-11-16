
local spells = jps.spells.priest
local canDPS = jps.canDPS
local canHeal = jps.canHeal
local canAttack = jps.canAttack
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs
local strfind = string.find
local UnitClass = UnitClass
local UnitChannelInfo = UnitChannelInfo
local GetSpellInfo = GetSpellInfo
local UnitAffectingCombat = UnitAffectingCombat
local UnitIsUnit = UnitIsUnit
local spells = jps.spells.shaman


jps.registerRotation("SHAMAN","ELEMENTAL",function()

local spell = nil
local target = nil

-- Config FOCUS with MOUSEOVER
if not jps.UnitExists("focus") and canDPS("mouseover") and UnitAffectingCombat("mouseover") then
	-- set focus an enemy targeting you
	if UnitIsUnit("mouseovertarget","player") and not UnitIsUnit("target","mouseover") then
		jps.Macro("/focus mouseover")
	-- set focus an enemy in combat
	elseif canDPS("mouseover") and not UnitIsUnit("target","mouseover") and not jps.myDebuff(spells.flameShock,"mouseover") then
		jps.Macro("/focus mouseover")
		--print("Enemy COMBAT|cff1eff00 "..name.." |cffffffffset as FOCUS not DEBUFF")
	elseif canDPS("mouseover") and not UnitIsUnit("target","mouseover") then
		jps.Macro("/focus mouseover")
	end
end

if jps.UnitExists("focus") and UnitIsUnit("target","focus") then
	jps.Macro("/clearfocus")
elseif jps.UnitExists("focus") and not canDPS("focus") then
	jps.Macro("/clearfocus")
end

if canDPS("target") and jps.canAttack("target") then rangedTarget =  "target"
elseif canDPS(TankTarget) and jps.canAttack(TankTarget) then rangedTarget = TankTarget
elseif canDPS("targettarget") and jps.canAttack("targettarget") then rangedTarget = "targettarget"
end
if canDPS(rangedTarget) then jps.Macro("/target "..rangedTarget) end

local spellTable = {

	-- heals
	{spells.giftNaaru, jps.hp("player") < 0.80 , "player" , "giftNaaru"},
	{spells.healingSurge, jps.UseCDs and jps.hp("player") < 0.50 , "player" , "healingSurge"},
	{spells.astralShift, jps.hp("player") < 0.50 , "player" },

	-- Apply Flame Shock
	{spells.flameShock , not jps.myDebuff(spells.flameShock) },
	-- Cast Fire Elemental if it is off cooldown.
	{spells.fireElemental},
	-- Cast Earth Shock Icon Earth Shock if Maelstrom is 90 or greater.
	{spells.earthShock , jps.isUsableSpell(spells.earthShock) and jps.maelstom() > 90 },
	-- Cast Ascendance (if talented) if it is off cooldown.
	{spells.ascendance  },
	-- Cast Elemental Mastery on cooldown where appropriate.
	{spells.elementalMastery },
	-- Cast Icefury (if talented) and priority damage is necessary, or predictable movement is incoming.
	{spells.icefury , jps.hasTalent(5,3) and jps.Moving },
	-- Cast Lava Burst whenever available and Flame Shock is applied to the target.
	{spells.lavaBurst , jps.myDebuff(spells.flameShock) },
	-- Frost Shock if Icefury buff is active.
	{spells.frostShock, jps.buff(spells.icefury) },
	-- Stormkeeper whenever available if you are not about to use Ascendance
	{spells.stormkeeper },
	-- Maintain Totem Mastery buff.
	{spells.totemMastery, jps.hasTalent(1,3) },
	
	{"nested", jps.MultiTarget , {
		-- Cast Earthquake if there are at least 4 targets present. -- 77478
		{spells.earthquakeTotem }, 
		-- Cast Chain Lightning as a filler on 2 or more targets.
		{spells.chainLightning },
	}},
	
	-- Cast Lightning Bolt as a filler on a single target.
	{spells.lightningBolt},



}

	local spell,target = parseSpellTable(spellTable)
	return spell,target

end,"shaman_elemental")

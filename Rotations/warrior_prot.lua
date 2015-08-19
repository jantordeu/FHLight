-- jps.UseCDs for "Charge"
-- jps.Interrupts for "Pummel"
-- jps.Defensive for "Provocation"

local L = MyLocalizationTable
local canDPS = jps.canDPS
local canHeal = jps.canHeal
local strfind = string.find
local UnitClass = UnitClass
local UnitAffectingCombat = UnitAffectingCombat
local canAttack = jps.CanAttack
local GetSpellInfo = GetSpellInfo
local UnitIsUnit = UnitIsUnit
local toSpellName = jps.toSpellName

-- "Shield Charge" 156321 "Charge de bouclier"
warrior.spells["ShieldCharge"] = toSpellName(156321)

local ClassEnemy = {
	["WARRIOR"] = "cac",
	["PALADIN"] = "caster",
	["HUNTER"] = "cac",
	["ROGUE"] = "cac",
	["PRIEST"] = "caster",
	["DEATHKNIGHT"] = "cac",
	["SHAMAN"] = "caster",
	["MAGE"] = "caster",
	["WARLOCK"] = "caster",
	["MONK"] = "caster",
	["DRUID"] = "caster"
}

local EnemyCaster = function(unit)
	if not jps.UnitExists(unit) then return false end
	local _, classTarget, classIDTarget = UnitClass(unit)
	return ClassEnemy[classTarget]
end

----------------------------------------------------------------------------------------------------------------
-------------------------------------------------- ROTATION ----------------------------------------------------
----------------------------------------------------------------------------------------------------------------

jps.registerRotation("WARRIOR","PROTECTION",function()

local spell = nil
local target = nil

local playerAggro = jps.FriendAggro("player")
local playerIsStun = jps.StunEvents(2) -- return true/false ONLY FOR PLAYER -- "ROOT" was removed of Stuntype
-- {"STUN_MECHANIC","STUN","FEAR","CHARM","CONFUSE","PACIFY","SILENCE","PACIFYSILENCE"}
local playerIsInterrupt = jps.InterruptEvents() -- return true/false ONLY FOR PLAYER
local playerWasControl = jps.ControlEvents() -- return true/false Player was interrupt or stun 2 sec ago ONLY FOR PLAYER

local inMelee = jps.IsSpellInRange(20243,"target") -- "Dévaster" 20243 "Devastate"
local inRanged = jps.IsSpellInRange(57755,"target") -- "Heroic Throw" 57755 "Lancer héroïque"
-- currentCharges, maxCharges, cooldownStart, cooldownDuration = GetSpellCharges(spellId or "spellName")
local ShieldCharge  = GetSpellCharges(156321)

local myTank,TankUnit = jps.findTankInRaid() -- default "focus"
local TankTarget = "target"
if UnitCanAssist("player",myTank) then TankTarget = myTank.."target" end
	
----------------------
-- TARGET ENEMY
----------------------

-- rangedTarget returns "target" by default, sometimes could be friend
local rangedTarget, EnemyUnit, TargetCount = jps.LowestTarget()
local EnemyCount = jps.RaidEnemyCount()
local isBoss = (UnitLevel("target") == -1) or (UnitClassification("target") == "elite")

-- Config FOCUS with MOUSEOVER
local name = GetUnitName("focus") or ""
if not jps.UnitExists("focus") and canDPS("mouseover") and UnitAffectingCombat("mouseover") then
	-- set focus an enemy targeting you
	if UnitIsUnit("mouseovertarget","player") and not UnitIsUnit("target","mouseover") then
		jps.Macro("/focus mouseover")
		--print("Enemy DAMAGER|cff1eff00 "..name.." |cffffffffset as FOCUS")
	-- set focus an enemy healer
	elseif jps.EnemyHealer("mouseover") then
		jps.Macro("/focus mouseover")
		--print("Enemy HEALER|cff1eff00 "..name.." |cffffffffset as FOCUS")
	-- set focus an enemy in combat
	elseif canDPS("mouseover") and not UnitIsUnit("target","mouseover") then
		jps.Macro("/focus mouseover")
		--print("Enemy COMBAT|cff1eff00 "..name.." |cffffffffset as FOCUS")
	end
end

-- CONFIG jps.getConfigVal("keep focus") if you want to keep focus
if jps.UnitExists("focus") and UnitIsUnit("target","focus") then
	jps.Macro("/clearfocus")
elseif jps.UnitExists("focus") and not canDPS("focus") then
	if jps.getConfigVal("keep focus") == false then jps.Macro("/clearfocus") end
end

if canAttack("target") then rangedTarget =  "target"
elseif jps.buff(156291) and canAttack(TankTarget) then rangedTarget = TankTarget -- "Gladiator Stance" 156291
elseif canAttack("targettarget") then rangedTarget = "targettarget"
elseif canAttack("mouseover") then rangedTarget = "mouseover"
end
if canDPS(rangedTarget) then jps.Macro("/target "..rangedTarget) end
local TargetMoving = select(1,GetUnitSpeed(rangedTarget)) > 0

--if jps.buff(156291) and UnitIsUnit("targettarget","player") then
--	SpellStopCasting()
--	spell = 20243;
--	target = "target";
--	if jps.combatStart > 0 then write("AGGRO_STOPCASTING") end
--return spell,target end

------------------------
-- SPELL TABLE ---------
------------------------

local spellTable = {

	-- "Heroic Leap" 6544 "Bond héroïque"
	{ warrior.spells["HeroicLeap"] , IsControlKeyDown() , "player" },
	
	-- BUFFS
	-- "Gladiator Stance" 156291 -- Talent "Gladiator's Resolve" 152276
	{ 156291, jps.IsSpellKnown(152276) and not jps.buff(156291) and not jps.buff(71) , "player" },
	-- "Defensive Stance" 71
	{ warrior.spells["DefensiveStance"] , not jps.buff(71) and not jps.buff(156291), "player" },
	-- "Battle Shout" 6673 "Cri de guerre"
	{ warrior.spells["BattleShout"] , not jps.hasAttackPowerBuff("player") , "player" },
	-- "Commanding Shout" 469 "Cri de commandement"
	{ warrior.spells["CommandingShout"] , jps.hasAttackPowerBuff("player") and jps.myBuffDuration(6673,"player") == 0 and not jps.buff(469) , "player" },

	-- INTERRUPTS --
	-- "Spell Reflection" 23920 "Renvoi de sort" --renvoyez le prochain sort lancé sur vous. Dure 5 s. Buff same spellId
	{ warrior.spells["SpellReflection"] , jps.ShouldKick(rangedTarget) and UnitIsUnit("targettarget","player") , rangedTarget , "SpellReflection" },
	{ warrior.spells["SpellReflection"] , jps.ShouldKick("focus") and UnitIsUnit("focustarget","player") , "focus" , "SpellReflection" },
	-- "Mass Spell Reflection" 114028 "Renvoi de sort de masse"
	{ warrior.spells["MassSpellReflection"] , UnitIsUnit("targettarget","player") and jps.IsCasting(rangedTarget) , rangedTarget , "MassSpell" },
	{ warrior.spells["MassSpellReflection"] , UnitIsUnit("focustarget","player") and jps.IsCasting("focus") , "focus" , "MassSpell" },
	-- "Pummel" 6552 "Volée de coups"
	{ warrior.spells["Pummel"] , jps.Interrupts and jps.ShouldKick(rangedTarget) , rangedTarget , "Pummel" },
	{ warrior.spells["Pummel"] , jps.Interrupts and jps.ShouldKick("focus") , "focus" , "Pummel" },

	-- DEFENSIVE
	-- "Shield Wall" 871 "Mur protecteur" -- cd 2 min
	{ warrior.spells["ShieldWall"] , jps.hp("player") < 0.50 , rangedTarget , "|cff1eff00ShieldWall" },
	-- "Last Stand" 12975 "Dernier rempart" -- 3 min
	{ warrior.spells["LastStand"] , jps.hp("player") < 0.30 , rangedTarget , "|cff1eff00LastStand" },
	
	-- "Impending Victory" 103840 "Victoire imminente" -- Talent Replaces Victory Rush.
	{ warrior.spells["ImpendingVictory"] , jps.buff(32216) and jps.hp("player") < 0.80 , rangedTarget , "|cff1eff00ImpendingVictory_Health" },
	{ warrior.spells["VictoryRush"] , jps.buff(32216) and jps.hp("player") <  0.80 , rangedTarget , "|cff1eff00VictoryRush_Health" },
	-- "Victory Rush" 34428 "Ivresse de la victoire" -- "Victorious" 32216 "Victorieux" -- Ivresse de la victoire activée.
	{ warrior.spells["ImpendingVictory"] , jps.buff(32216) and jps.buffDuration(32216) < 4 , rangedTarget , "|cff1eff00ImpendingVictory_Duration" },
	{ warrior.spells["VictoryRush"] , jps.buff(32216) and jps.buffDuration(32216) < 4 , rangedTarget , "|cff1eff00VictoryRush_Duration" },
	
	-- "Pierre de soins" 5512
	{ {"macro","/use item:5512"}, jps.hp("player") < 0.80 and jps.itemCooldown(5512) == 0 , "player" , "Item5512" },
	-- "Stoneform" 20594 "Forme de pierre"
	{ warrior.spells["Stoneform"] , playerAggro and jps.hp() < 0.80 , rangedTarget , "|cff1eff00Stoneform_Health" },
	{ warrior.spells["Stoneform"] , jps.canDispel("player",{"Magic","Poison","Disease","Curse"}) , rangedTarget , "|cff1eff00Stoneform_Dispel" },
	-- "Proteger" 114029 -- "Intervention" 3411
	{ 3411, not UnitIsUnit(myTank,"player") and jps.hp(myTank) < 0.30 and jps.hp("player") > 0.85 and UnitCanAssist("player",myTank) , myTank , "Intervention_myTank" },
	{ 114029, not UnitIsUnit(myTank,"player") and jps.hp(myTank) < 0.30 and jps.hp("player") > 0.85 and UnitCanAssist("player",myTank) , myTank , "Proteger_myTank" },
	{ 3411, not UnitIsUnit("targettarget","player") and jps.hp("targettarget") < 0.30 and jps.hp("player") > 0.85 , "targettarget" , "Intervention_Aggro" },
	{ 114029, not UnitIsUnit("targettarget","player") and jps.hp("targettarget") < 0.30 and jps.hp("player") > 0.85 , "targettarget" , "Proteger_Aggro" },
	-- "Provocation" 355
	{ 355, jps.Defensive and jps.buff(71) and not UnitIsUnit("targettarget","player") , "target" , "Provocation" },
	-- "Demoralizing Shout" 1160 "Cri démoralisant"
	{ 1160, playerAggro and not jps.debuff(1160,rangedTarget) , rangedTarget , "Demoralizing" },
	
	-- TRINKETS -- jps.useTrinket(0) est "Trinket0Slot" est slotId  13 -- "jps.useTrinket(1) est "Trinket1Slot" est slotId  14
	--{ jps.useTrinket(0), jps.useTrinketBool(0) and not playerWasControl and jps.combatStart > 0 },
	{ jps.useTrinket(0), jps.useTrinketBool(0) and not playerWasControl and jps.buffDuration(12880) > 4 }, -- "Enrage" 12880 "Enrager"
	{ jps.useTrinket(1), jps.PvP and jps.useTrinketBool(1) and playerIsStun },
	{ jps.useTrinket(1), not jps.PvP and jps.useTrinketBool(1) and not playerWasControl and jps.combatStart > 0 },

	-- DAMAGE
	-- "Shield Charge" 156321 "Charge de bouclier" -- Buff "Shield Charge" 169667 -- "Bloodbath" 12292 "Bain de sang"
	-- Increasing the damage of Shield Slam, Revenge, and Heroic Strike by 25% for 7 sec.
	{ warrior.spells["ShieldCharge"], not jps.buff(169667) and jps.buff(156291) and inMelee and jps.buffStacks(169686) == 6 , rangedTarget , "|cffa335eeShieldCharge_6_Strikes" },
	{ warrior.spells["ShieldCharge"], not jps.buff(169667) and jps.buff(156291) and inMelee and jps.buff(12292) , rangedTarget , "|cffa335eeShieldCharge_Bloodbath" },
	-- "Revenge" 6572 "Revanche"
	{ warrior.spells["Revenge"] , inMelee , rangedTarget , "Revenge" },
	-- "Shield Slam" 23922 "Heurt de bouclier" -- Buff "Sword and Board" 50227 "Epée et bouclier"
	{ warrior.spells["ShieldSlam"] , jps.buff(50227) , rangedTarget , "ShieldSlam_SwordBoard" },
	{ warrior.spells["ShieldSlam"] , true , rangedTarget , "ShieldSlam" },
	-- "Heroic Strike" 78 "Frappe héroïque" -- Buff "Ultimatum" 122509 -- HS cost no rage & crtique
	{ warrior.spells["HeroicStrike"] , jps.buff(122509) , rangedTarget , "HeroicStrike_Ultimatum" },
	{ warrior.spells["HeroicStrike"] , jps.buffStacks(169686) == 6 and jps.buff(156291) , rangedTarget , "HeroicStrike_6_Strikes" },
	{ warrior.spells["HeroicStrike"] , jps.buffStacks(169686) == 6 and jps.buff(71) and jps.hp("player") > 0.50 , rangedTarget , "HeroicStrike_6_Strikes" },
	{ warrior.spells["HeroicStrike"] , jps.rage() > 89 and jps.hp(rangedTarget) > 0.20 and jps.buff(156291) , rangedTarget , "HeroicStrike_DumpRage" },
	{ warrior.spells["HeroicStrike"] , jps.rage() > 89 and jps.hp(rangedTarget) > 0.20 and jps.buff(71) and jps.hp("player") > 0.50 , rangedTarget , "HeroicStrike_DumpRage" },
	-- "Execute" 5308 "Exécution" -- Buff "Mort soudaine" 29725
	{ warrior.spells["Execute"], jps.buff(29725) , rangedTarget , "Execute_SuddenDeath" },
	{ warrior.spells["Execute"], jps.rage() > 89 and jps.hp(rangedTarget) < 0.20 and jps.buff(156291) , rangedTarget , "Execute_DumpRage" },
	{ warrior.spells["Execute"], jps.rage() > 89 and jps.hp(rangedTarget) < 0.20 and jps.buff(71) and jps.hp("player") > 0.50 , rangedTarget , "Execute_DumpRage" },
	
	-- MULTITARGET --
	{"nested", jps.MultiTarget and inMelee ,{
		-- "Bladestorm" 46924 "Tempête de lames"
		{ warrior.spells["Bladestorm"] , jps.IsSpellKnown(46924) , rangedTarget , "Bladestorm" },
		-- "Shockwave" 46968 "Onde de choc"
		{ warrior.spells["Shockwave"] , jps.IsSpellKnown(46968) , rangedTarget , "Shockwave" },
		-- "Thunder Clap" 6343 "Coup de tonnerre"
		{ warrior.spells["ThunderClap"] , true , rangedTarget , "ThunderClap" },
	}},

	-- DEFENSIVE
	-- "Enraged Regeneration" 55694 "Régénération enragée"
	{ warrior.spells["EnragedRegeneration"] , playerAggro and jps.hp() < 0.80 , rangedTarget , "|cff1eff00EnragedRegeneration" },
	{ warrior.spells["EnragedRegeneration"] , jps.MagicDamage and jps.hp() < 0.80 , rangedTarget , "|cff1eff00EnragedRegeneration_Magic" },
	{ warrior.spells["EnragedRegeneration"] , jps.PhysicalDamage and jps.hp() < 0.80 , rangedTarget , "|cff1eff00EnragedRegeneration_Physiq" },
	-- "Shield Block" 2565 "Maîtrise du blocage" -- works against physical attacks, it does nothing against magic -- Buff "Shield Block" 132404 -- 60 rage
	{ warrior.spells["ShieldBlock"] , jps.buff(71) and jps.PhysicalDamage and not jps.buff(132404) and jps.hp("player") < 0.80 , rangedTarget , "|cff1eff00ShieldBlock_PhysicalDmg" },
	-- "Shield Barrier" 112048 "Barrière protectrice" -- Shield Barrier works against all types of damage (excluding fall damage) -- 20 + 40 rage
	{ warrior.spells["ShieldBarrier"] , jps.buff(71) and jps.MagicDamage and not jps.buff(112048) and jps.hp("player") < 0.80 , rangedTarget , "|cff1eff00ShieldBarrier_MagicDmg" },
	{ warrior.spells["ShieldBarrier"] , playerAggro and not jps.buff(112048) and jps.hp("player") < 0.50 , rangedTarget , "|cff1eff00ShieldBarrier" },

	-- "Heroic Throw" 57755 "Lancer héroïque"
	{ warrior.spells["HeroicThrow"] , inRanged and not inMelee , rangedTarget , "Heroic Throw" },
	-- "Charge" 100
	{ warrior.spells["Charge"], jps.UseCDs and jps.IsSpellInRange(100,rangedTarget) , rangedTarget , "Charge"},
	-- "Intimidating Shout" 5246
	{ warrior.spells["IntimidatingShout"] , playerAggro and not jps.debuff(5246,rangedTarget) , rangedTarget , "IntimidatingShout"},
	-- "Berserker Rage" 18499 "Rage de berserker" -- "Enrage" 12880 "Enrager"
	{ warrior.spells["BerserkerRage"] , not jps.buff(12880) and jps.buff(169667) , rangedTarget , "|cFFFF0000BerserkerRage" },
	{ warrior.spells["BerserkerRage"] , not jps.buff(12880) and jps.buff(12292) , rangedTarget , "|cFFFF0000BerserkerRage" },

	-- TALENTS --
	-- "Bloodbath" 12292 "Bain de sang" -- Buff 12292
	{ warrior.spells["Bloodbath"], inMelee and jps.rage() > 29 and jps.MultiTarget , rangedTarget , "|cFFFF0000Bloodbath" },
	{ warrior.spells["Bloodbath"], inMelee and jps.rage() > 89 , rangedTarget , "|cFFFF0000Bloodbath_DumpRage" },
	{ warrior.spells["Bloodbath"], inMelee and jps.rage() > 59 and jps.buffStacks(169686) > 3 , rangedTarget , "|cFFFF0000Bloodbath_4_Strikes" },
	-- "Storm Bolt" 107570 "Eclair de tempete" -- 30 yd range
	{ warrior.spells["StormBolt"] , jps.IsSpellKnown(107570) , rangedTarget ,"StormBolt" },
	-- "Dragon Roar " 118000 -- 8 yards
	{ warrior.spells["DragonRoar"] , jps.IsSpellKnown(118000) and inMelee , rangedTarget , "DragonRoar" },
	-- "Bladestorm" 46924 "Tempête de lames"
	{ warrior.spells["Bladestorm"] , jps.IsSpellKnown(46924) and inMelee , rangedTarget , "Bladestorm" },
	-- "Ravager" 152277 -- 40 yd range
	{ warrior.spells["Ravager"] , jps.IsSpellKnown(152277) , rangedTarget , "Ravager" },

	-- "Shield Charge" 156321 "Charge de bouclier" -- Buff "Shield Charge" 169667 -- "Bloodbath" 12292 "Bain de sang"
	-- Increasing the damage of Shield Slam, Revenge, and Heroic Strike by 25% for 7 sec. -- "Revenge" 6572 "Revanche"
	{"nested", jps.buff(156291) and inMelee and not jps.buff(169667) ,{
		{ warrior.spells["ShieldCharge"], inMelee and ShieldCharge == 2 , rangedTarget , "|cffa335eeShieldCharge_2" },
		{ warrior.spells["ShieldCharge"], inMelee and jps.rage() > 29 and jps.cooldown(23922) < 2 and jps.cooldown(6572) < 6 , rangedTarget , "|cffa335eeShieldCharge_ShieldSlam" },
	}},
	
	-- "Dévaster" 20243 "Devastate" -- Buff "Unyielding Strikes" 169686 "Frappes inflexibles" 169686 -- Cumulable jusqu’à 6 fois
	{ warrior.spells["Devastate"] , jps.buffDuration(169686) < 2 , rangedTarget , "Devastate_BuffDuration" },
	-- "Execute" 5308 "Exécution" -- Buff "Shield Charge" 169667
	{ warrior.spells["Execute"] , not jps.buff(169667) and jps.hp(rangedTarget) < 0.20 , rangedTarget , "Execute_UnBuff" },
	-- "Heroic Strike" 78 "Frappe héroïque" -- Buff "Shield Charge" 169667
	{ warrior.spells["HeroicStrike"] , jps.buff(169667) , rangedTarget , "HeroicStrike_ShieldCharge" },
	{ warrior.spells["HeroicStrike"] , jps.rage() > 29 and jps.buffStacks(169686) > 3 , rangedTarget , "HeroicStrike_4_Strikes" },
	-- "Dévaster" 20243 "Devastate" -- Dévaster réduit le coût en rage de Frappe héroïque de 5 pendant 5 s.
	{ warrior.spells["Devastate"] , true , rangedTarget , "Devastate" },

}

	local spell,target = parseSpellTable(spellTable)
	return spell,target
end, "Default")

----------------------------------------------------------------------------------------------------------------
-------------------------------------------------- ROTATION OOC ------------------------------------------------
----------------------------------------------------------------------------------------------------------------


jps.registerStaticTable("WARRIOR","PROTECTION",{

	-- "Heroic Leap" 6544 "Bond héroïque"
	{ warrior.spells["HeroicLeap"] , 'IsControlKeyDown()' , "player" },
	-- "Battle Shout" 6673 "Cri de guerre"
	{ warrior.spells["BattleShout"] , 'not jps.hasAttackPowerBuff("player")' , "player" },
	-- "Commanding Shout" 469 "Cri de commandement"
	{ warrior.spells["CommandingShout"] , 'jps.hasAttackPowerBuff("player") and jps.myBuffDuration(6673,"player") == 0 and not jps.buff(469)' , "player" },
	-- "Oralius' Whispering Crystal" 118922 "Cristal murmurant d’Oralius" -- buff 176151
	{ {"macro","/use item:118922"}, 'not jps.buff(176151) and jps.itemCooldown(118922) == 0 and not jps.buff(156080) and not jps.buff(156071)' , "player" , "Item_Oralius"},
	-- "Flacon d’Intelligence draenique" jps.buff(156070)
	-- "Flacon d’Intelligence supérieure draenique" jps.buff(156079)
	-- "Flacon de Force supérieure draenique" jps.buff(156080)
	-- "Flacon de Force draenique" jps.buff(156071)

}
, "OOC Warrior Protection",false,false,true)
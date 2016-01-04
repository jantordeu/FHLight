-- jps.UseCDs for RACIAL COUNTERS
-- jps.UseCDs for "Nova" 132157 "Words of Mending" 155362 "Mot de guérison" When OOC
-- jps.UseCDs for Dispel
-- jps.Interrupts for "Semblance spectrale" 112833 "Spectral Guise" -- PvP it loses the orb in Kotmogu Temple
-- jps.Defensive changes the LowestImportantUnit to table = {"player","mouseover","target","focus","targettarget","focustarget"} with table.insert TankUnit  = jps.findTankInRaid()
-- jps.MultiTarget to DPS
-- IsControlKeyDown() for "Angelic Feather" 121536 "Plume angélique"

local L = MyLocalizationTable
local canDPS = jps.canDPS
local canHeal = jps.canHeal
local canAttack = jps.CanAttack
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs
local strfind = string.find
local UnitClass = UnitClass
local UnitChannelInfo = UnitChannelInfo
local GetSpellInfo = GetSpellInfo
local UnitAffectingCombat = UnitAffectingCombat
local UnitIsUnit = UnitIsUnit

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

-- Debuff EnemyTarget NOT DPS
local DebuffUnitCyclone = function (unit)
	local i = 1
	local auraName = select(1,UnitDebuff(unit, i))
	while auraName do
		if strfind(auraName,L["Polymorph"]) then
			return true
		elseif strfind(auraName,L["Cyclone"]) then
			return true
		elseif strfind(auraName,L["Hex"]) then
			return true
		end
		i = i + 1
		auraName = select(1,UnitDebuff(unit, i))
	end
	return false
end

----------------------------------------------------------------------------------------------------------------
---------------------------------------------- ROTATION PVP & PVP ----------------------------------------------
----------------------------------------------------------------------------------------------------------------

local priestDisc = function()

	local spell = nil
	local target = nil

----------------------------
-- LOWESTIMPORTANTUNIT
----------------------------

	local CountInRange, AvgHealthLoss, FriendUnit = jps.CountInRaidStatus()
	local LowestImportantUnit = jps.LowestImportantUnit()
	local countFriendNearby = jps.FriendNearby(12)
	local POHTarget, groupToHeal, groupHealth = jps.FindSubGroupHeal(0.70) -- Target to heal with POH in RAID with AT LEAST 3 RAID UNIT of the SAME GROUP IN RANGE
	--local POHTarget, groupToHeal = jps.FindSubGroupTarget(0.70) -- Target to heal with POH in RAID with AT LEAST 3 RAID UNIT of the SAME GROUP IN RANGE
	local CountFriendLowest = jps.CountInRaidLowest(0.80)
	local CountFriendEmergency = jps.CountInRaidLowest(0.50)

	local Tank,TankUnit = jps.findTankInRaid() -- default "focus"
	local TankTarget = "target"
	if canHeal(Tank) then TankTarget = Tank.."target" end
	local TankThreat = jps.findThreatInRaid()

	local playerAggro = jps.FriendAggro("player")
	local playerIsStun = jps.StunEvents(2) -- return true/false ONLY FOR PLAYER -- "ROOT" was removed of Stuntype
	-- {"STUN_MECHANIC","STUN","FEAR","CHARM","CONFUSE","PACIFY","SILENCE","PACIFYSILENCE"}
	local playerIsInterrupt = jps.InterruptEvents() -- return true/false ONLY FOR PLAYER
	local playerWasControl = jps.ControlEvents() -- return true/false Player was interrupt or stun 2 sec ago ONLY FOR PLAYER
	local playerTTD = jps.TimeToDie("player")
	local ShellTarget = jps.FindSubGroupAura(114908) -- buff target Spirit Shell 114908 need SPELLID

	local BodyAndSoul = jps.IsSpellKnown(64129) -- "Body and Soul" 64129
	local isArena, _ = IsActiveBattlefieldArena()

---------------------
-- ENEMY TARGET
---------------------

	local isBoss = UnitLevel("target") == -1 or UnitClassification("target") == "elite"
	-- rangedTarget returns "target" by default, sometimes could be friend
	local rangedTarget, EnemyUnit, TargetCount = jps.LowestTarget()

	if canDPS("target") and not DebuffUnitCyclone(rangedTarget) then rangedTarget =  "target"
	elseif canDPS(TankTarget) and not DebuffUnitCyclone(rangedTarget) then rangedTarget = TankTarget
	elseif canDPS("targettarget") and not DebuffUnitCyclone(rangedTarget) then rangedTarget = "targettarget"
	elseif canAttack("mouseover") then rangedTarget = "mouseover"
	end
	-- if your target is friendly keep it as target
	if not canHeal("target") and canDPS(rangedTarget) then jps.Macro("/target "..rangedTarget) end
	
	local playerIsTargeted,arenaTarget = jps.playerIsTargetedInArena()

----------------------------
-- LOCAL FUNCTIONS FRIENDS
----------------------------

	local MendingFriend = nil
	local MendingFriendHealth = 100
	for i=1,#FriendUnit do -- for _,unit in ipairs(FriendUnit) do
		local unit = FriendUnit[i]
		if priest.unitForMending(unit) then
			local unitHP = jps.hp(unit)
			if unitHP < MendingFriendHealth then
				MendingFriend = unit
				MendingFriendHealth = unitHP
			end
		end
	end
	
	-- priest.unitForLeap includes jps.FriendAggro and jps.LoseControl
	local LeapFriend = nil
	for i=1,#FriendUnit do -- for _,unit in ipairs(FriendUnit) do
		local unit = FriendUnit[i]
		if priest.unitForLeap(unit) and jps.hpInc(unit) < 0.30 then 
			LeapFriend = unit
		break end
	end
	
	-- priest.unitForShield includes jps.FriendAggro
	local ShieldFriend = nil
	local ShieldFriendHealth = 100
	for i=1,#FriendUnit do -- for _,unit in ipairs(FriendUnit) do
		local unit = FriendUnit[i]
		if UnitGetTotalAbsorbs(unit) == 0 and not jps.buff(17,unit) and not jps.debuff(6788,unit) then
			local unitHP = jps.hp(unit)
			if unitHP < ShieldFriendHealth then
				ShieldFriend = unit
				ShieldFriendHealth = unitHP
			end
		end
	end
	
	local ShieldArenaFriend = nil
	local ShieldArenaFriendHealth = 100
	for i=1,#arenaTarget do
		if not jps.buff(17,unit) and not jps.debuff(6788,unit) then
			local unitHP = jps.hp(unit)
			if unitHP < ShieldArenaFriendHealth then
				ShieldArenaFriend = unit
				ShieldArenaFriendHealth = unitHP
			end
		end
	end

	-- DISPEL --
	
	local DispelFriendPvE = jps.FindMeDispelTarget( {"Magic"} ) -- {"Magic", "Poison", "Disease", "Curse"}
	local DispelFriendPvP = nil
	local DispelFriendHealth = 100
	for i=1,#FriendUnit do -- for _,unit in ipairs(FriendUnit) do
		local unit = FriendUnit[i]
		local unitHP = jps.hp(unit)
		if jps.DispelFriendly(unit) then -- jps.DispelFriendly includes UnstableAffliction
			if unitHP < DispelFriendHealth then
				DispelFriendPvP = unit
				DispelFriendHealth = unitHP
			end
		elseif jps.DispelLoseControl(unit) then
			if unitHP < DispelFriendHealth then
				DispelFriendPvP = unit
				DispelFriendHealth = unitHP
			end
		end
	end

	local DispelFriendRole = nil
	for i=1,#TankUnit do -- for _,unit in ipairs(TankUnit) do
		local unit = TankUnit[i]
		if jps.canDispel(unit,{"Magic"}) then -- jps.canDispel includes UnstableAffliction
			DispelFriendRole = unit
		elseif jps.PvP and jps.RoleInRaid(unit) == "HEALER" then
			DispelFriendRole = unit
		break end
	end

	-- PAIN SUPPRESSION
	local PainFriend = nil
	for i=1,#FriendUnit do -- for _,unit in ipairs(FriendUnit) do
		local unit = FriendUnit[i]
		if jps.cooldown(33206) == 0 then break end 
		if jps.buff(33206,unit) then
			PainFriend = unit
		break end
	end

	-- FACING ANGLE -- jps.PlayerIsFacing(LowestImportantUnit,45) -- angle value between 10-180
	local CountFriendIsFacing = 0
	local FriendIsFacingLowest = nil
	local FriendIsFacingHeath = 100
	for i=1,#FriendUnit do -- for _,unit in ipairs(FriendUnit) do
		local unit = FriendUnit[i]
		if jps.hp(unit) < 0.90 and canHeal(unit) then
			if jps.Distance(unit) < 30 and jps.PlayerIsFacing(unit,90) then
				CountFriendIsFacing = CountFriendIsFacing + 1
				local unitHP = jps.hp(unit)
				if unitHP < FriendIsFacingHeath then
					FriendIsFacingLowest = unit
					FriendIsFacingHeath = unitHP
				end
			end
		end
	end
	
	-- BOSS DEBUFF
	local TankBossDebuff = nil
	for i=1,#TankUnit do
		if jps.BossDebuff(TankUnit[i]) and not jps.debuff(6788,TankUnit[i]) then TankBossDebuff = TankUnit[i]
		break end
	end
	
	-- INCOMING DAMAGE
	local IncomingDamageFriend = jps.HighestIncomingDamage()
	
	-- LOWEST TTD
	local LowestFriendTTD = jps.LowestFriendTimeToDie(5)

------------------------
-- LOCAL FUNCTIONS ENEMY
------------------------

	local EnemyIsCastingControl = nil
	for i=1,#EnemyUnit do -- for _,unit in ipairs(EnemyUnit) do
		local unit = EnemyUnit[i]
		if jps.IsCastingSpellControl(unit) then EnemyIsCastingControl = unit
		break end
	end

	local SilenceEnemyTarget = nil
	for i=1,#EnemyUnit do -- for _,unit in ipairs(EnemyUnit) do
		local unit = EnemyUnit[i]
		if jps.IsSpellInRange(15487,unit) then
			if jps.ShouldKick(unit) then
				SilenceEnemyTarget = unit
			break end
		end
	end

	local FearEnemyTarget = nil
	for i=1,#EnemyUnit do -- for _,unit in ipairs(EnemyUnit) do
		local unit = EnemyUnit[i]
		if priest.canFear(unit) and not jps.LoseControl(unit) then
			FearEnemyTarget = unit
		break end
	end

	local DispelOffensiveEnemyTarget = nil
	for i=1,#EnemyUnit do -- for _,unit in ipairs(EnemyUnit) do
		local unit = EnemyUnit[i]
		if jps.DispelOffensive(unit) and jps.hp(LowestImportantUnit) > 0.85 then
			DispelOffensiveEnemyTarget = unit
		break end
	end

------------------------
-- LOCAL TABLES
------------------------

	local parseShell = {
	--TANK not Buff Spirit Shell 114908
		{ 2061, jps.buff(114255) , LowestImportantUnit , "Carapace_FlashHeal_Light" },
		{ 596, canHeal(ShellTarget) , ShellTarget , "Carapace_Shell_Target" },
		{ 2061, not jps.buffId(114908,LowestImportantUnit) , LowestImportantUnit , "Carapace_NoBuff_FlashHeal" },
	--TANK Buff Spirit Shell 114908
		{ 2060, jps.buffId(114908,LowestImportantUnit) , LowestImportantUnit , "Carapace_Buff_Soins" },
	}
	
	local parseControl = {
		-- "Silence" 15487
		{ 15487, jps.IsSpellInRange(15487,rangedTarget) and EnemyCaster(rangedTarget) == "caster" , rangedTarget },
		-- "Psychic Scream" "Cri psychique" 8122 -- debuff same ID 8122
		{ 8122, priest.canFear(rangedTarget) , rangedTarget },
		-- "Void Tendrils" 108920 -- debuff "Void Tendril's Grasp" 114404
		{ 108920, priest.canFear(rangedTarget) , rangedTarget },
	}
	
	local parseDispel = {
		-- "Dispel" "Purifier" 527
		{ 527, DispelFriendRole ~= nil , DispelFriendRole , "|cff1eff00DispelFriend_Role" },
		{ 527, DispelFriendPvP ~= nil , DispelFriendPvP , "|cff1eff00DispelFriend_PvP" },
		{ 527, DispelFriendPvE ~= nil , DispelFriendPvE , "|cff1eff00DispelFriend_PvE" },
	}

	local RacialCounters = {
		-- Undead "Will of the Forsaken" 7744 -- SNM priest is undead ;)
		{ 7744, jps.debuff("psychic scream","player") }, -- Fear
		{ 7744, jps.debuff("fear","player") }, -- Fear
		{ 7744, jps.debuff("intimidating shout","player") }, -- Fear
		{ 7744, jps.debuff("howl of terror","player") }, -- Fear
		{ 7744, jps.debuff("mind control","player") }, -- Charm
		{ 7744, jps.debuff("seduction","player") }, -- Charm
		{ 7744, jps.debuff("wyvern sting","player") }, -- Sleep
	}

------------------------------------------------------
-- OVERHEAL -- OPENING -- CANCELAURA -- STOPCASTING --
------------------------------------------------------

	-- "Archange surpuissant" 172359  100 % critique POH or FH
	-- "Power Infusion" 10060 "Infusion de puissance"
	local InterruptTable = {
		{priest.Spell.FlashHeal, 0.80, jps.buffId(priest.Spell.SpiritShellBuild) or jps.buff(172359) },
		{priest.Spell.Heal, 1, jps.buffId(priest.Spell.SpiritShellBuild) },
		{priest.Spell.PrayerOfHealing, 0.80, jps.buff(10060) or jps.buff(172359) or jps.buffId(priest.Spell.SpiritShellBuild) or jps.PvP },
		{priest.Spell.HolyCascade, 3 , false}
	}
	  
	-- AVOID OVERHEALING
	priest.ShouldInterruptCasting(InterruptTable , groupHealth , CountFriendLowest)

	-- FAKE CAST -- 6948 -- "Hearthstone"
	local FakeCast = UnitCastingInfo("player")
	if FakeCast == GetItemInfo(6948) then
		if jps.CastTimeLeft() < 4 then
			SpellStopCasting()
		elseif jps.hp(LowestImportantUnit) < 0.80 then
			SpellStopCasting()
		end
	end

-- SNM Trinket 1 use function to avoid blowing trinket when not needed
-- False if rooted, not moving, and lowest friendly unit in range
-- False if stunned/incapacitated but lowest friendly unit is good health
-- False if stunned/incapacitated and playerAggro but player health is good

if jps.hp("player") < 0.25 then CreateMessage("LOW HEALTH!") end -- CreateFlasher()

------------------------
-- SPELL TABLE ---------
------------------------

spellTable = {

	-- SNM RACIAL COUNTERS -- share 30s cd with trinket
	{"nested", jps.PvP and jps.UseCDs , RacialCounters },
	-- SNM "Chacun pour soi" 59752 "Every Man for Himself" -- Human
	{ 59752, playerIsStun , "player" , "Every_Man_for_Himself" },
	-- TRINKETS -- jps.useTrinket(0) est "Trinket0Slot" est slotId  13 -- "jps.useTrinket(1) est "Trinket1Slot" est slotId  14
	{ jps.useTrinket(0), jps.useTrinketBool(0) and not playerWasControl and jps.combatStart > 0 },
	{ jps.useTrinket(1), jps.useTrinketBool(1) and playerIsStun and jps.combatStart > 0 },

	-- "Suppression de la douleur" 33206 "Pain Suppression" -- Buff "Pain Suppression" 33206
	{ 33206, jps.hp("player") < 0.40 and UnitAffectingCombat("player") , "player" , "StunPain_player" },
	{ 33206, jps.hp(LowestImportantUnit) < 0.40 and UnitAffectingCombat(LowestImportantUnit) , LowestImportantUnit , "StunPain_Lowest" },
	
	-- "Spectral Guise" 112833 "Semblance spectrale" gives buff 119032
	{ 112833, jps.Interrupts and EnemyIsCastingControl ~= nil and jps.IsSpellKnown(112833) and not jps.buff(159630) , "player" , "Control_Spectral" },
	-- "Fade" 586 "Oubli" -- "Glyph of Shadow Magic" 159628 -- gives buff "Shadow Magic" 159630 "Magie des Ténèbres"
	{ 586, EnemyIsCastingControl ~= nil and jps.glyphInfo(159628) and not jps.buff(119032), "player" , "Control_Oubli" },
	-- PLAYER AGGRO PVP
	{ "nested", playerAggro or playerWasControl or playerIsTargeted ,{
		-- "Spectral Guise" 112833 "Semblance spectrale" gives buff 119032
		{ 112833, jps.Interrupts and jps.IsSpellKnown(112833) and not jps.buff(159630) , "player" , "Aggro_Spectral" },
		-- "Fade" 586 "Oubli" -- "Glyph of Shadow Magic" 159628 -- gives buff "Shadow Magic" 159630 "Magie des Ténèbres"
		{ 586, jps.glyphInfo(159628) and not jps.buff(119032), "player" , "Aggro_Oubli" },
		-- "Oubli" 586 -- Fantasme 108942 -- vous dissipez tous les effets affectant le déplacement sur vous-même
		{ 586, jps.IsSpellKnown(108942) , "player" , "Aggro_Oubli" },
		-- "Oubli" 586 -- Glyphe d'oubli 55684 -- Votre technique Oubli réduit à présent tous les dégâts subis de 10%.
		{ 586, jps.glyphInfo(55684) , "player" , "Aggro_Oubli" },
		-- "Power Word: Shield" 17
		{ 17, not jps.buff(17,"player") and not jps.debuff(6788,"player") , "player" , "Aggro_Shield" },
	}},
	
	-- "Soins rapides" 2061 -- "Vague de Lumière" 114255 "Surge of Light"
	{ 2061, jps.buff(114255) and jps.hp(LowestImportantUnit) < 0.80 , LowestImportantUnit , "FlashHeal_Light" },
	{ 2061, jps.buff(114255) and jps.buffDuration(114255) < 4 , LowestImportantUnit , "FlashHeal_Light" },	
	-- "Saving Grace" 152116 "Grâce salvatrice"
	{ 152116, jps.hp("player") < 0.40 and jps.debuffStacks(155274,"player") < 2 , "player" , "Emergency_SavingGrace" },
	{ 152116, jps.hp(LowestImportantUnit) < 0.40 and jps.debuffStacks(155274,"player") < 2 , LowestImportantUnit , "Emergency_SavingGrace" },

	-- CONTROL --
	{ 15487, SilenceEnemyTarget ~= nil , SilenceEnemyTarget , "Silence_MultiUnit" },
	{ "nested", jps.PvP and not jps.LoseControl(rangedTarget) and canDPS(rangedTarget) , parseControl },
	-- "Leap of Faith" 73325 -- "Saut de foi"
	{ 73325, jps.PvP and LeapFriend ~= nil , LeapFriend , "|cff1eff00Leap_MultiUnit" },
	-- "Gardien de peur" 6346
	{ 6346, jps.PvP and not jps.buff(6346,"player") and jps.hp() > 0.80 , "player" },
	
	-- DISPEL -- "Glyph of Purify" 55677 Your Purify spell also heals your target for 5% of maximum health
	-- "Dispel" 527 "Purifier"
	{ 527, jps.canDispel("player",{"Magic"}) , "player" , "Aggro_Dispel" },
	{ 527, jps.canDispel("mouseover") , "mouseover" , "Dispel_Mouseover"},
	{ "nested", jps.UseCDs , parseDispel },

	-- SNM "Levitate" 1706 -- "Dark Simulacrum" debuff 77606
	{ 1706, jps.PvP and jps.fallingFor() > 1.5 and not jps.buff(111759) , "player" },
	{ 1706, jps.PvP and jps.debuff(77606,"player") , "player" , "DarkSim_Levitate" },
	-- "Angelic Feather" 121536 "Plume angélique"
	{ 121536, IsControlKeyDown() },
	-- "Power Word: Shield" 17 -- Keep Buff "Borrowed" 59889 always
	{ 17, ShieldArenaFriend ~= nil and not jps.buff(59889) , ShieldArenaFriend , "Emergency_ShieldArenaFriend" },
	{ 17, ShieldFriend ~= nil and not jps.buff(59889) , ShieldFriend , "Emergency_ShieldFriend" },
	{ 17, canHeal("targettarget") and not jps.buff(17,"targettarget") and not jps.debuff(6788,"targettarget") , "targettarget" , "Shield_targettarget" },
	-- "Power Word: Shield" 17 -- "Body and Soul" 65081 buff -- Glyph of Reflective Shield 33202
	{ 17, jps.glyphInfo(33202) and not jps.buff(17,"player") and not jps.debuff(6788,"player") , "player" , "Defensive_Shield" },
	{ 17, not jps.buff(65081,"player") and jps.Moving and BodyAndSoul and not jps.debuff(6788,"player") , "player" , "Shield_Moving" },

	-- "Power Infusion" 10060 "Infusion de puissance"
	{ 10060, jps.hp(LowestImportantUnit) < 0.60 , "player" , "POWERINFUSION_Lowest" },
	{ 10060, CountFriendLowest > 1 , "player" , "POWERINFUSION_Count" },
	-- SNM Troll "Berserker" 26297 -- haste buff
	{ 26297, CountFriendEmergency > 2 , "player" },
	
	-- EMERGENCY HEAL --
	{ "nested", jps.hp(LowestImportantUnit) < 0.50 ,{
		-- "Power Word: Shield" 17 -- Keep Buff "Borrowed" 59889 always
		{ 17, not jps.buff(17,LowestImportantUnit) and not jps.debuff(6788,LowestImportantUnit) , LowestImportantUnit , "Emergency_Shield" },
		-- "Pénitence" 47540
		{ 47540, true , LowestImportantUnit , "Emergency_Penance" },
		-- "Soins rapides" 2061
		{ 2061, not jps.Moving , LowestImportantUnit , "Emergency_FlashHeal" },
	}},
	
	{ "nested", jps.hp("player") < 1 ,{
		-- "Saving Grace" 152116 "Grâce salvatrice"
		{ 152116, jps.hp() < 0.60 and jps.debuffStacks(155274,"player") < 2 , "player" , "Aggro_SavingGrace" },
		-- "Prière du désespoir" 19236
		{ 19236, jps.hp() < 0.60 and jps.IsSpellKnown(19236) , "player" , "Aggro_DESESPERATE" },
		-- "Power Word: Shield" 17
		{ 17, not jps.buff(17,"player") and not jps.debuff(6788,"player") , "player" , "Aggro_Shield" },
		-- "Pierre de soins" 5512
		{ {"macro","/use item:5512"}, jps.hp() < 0.60 and jps.itemCooldown(5512) == 0 , "player" , "Aggro_Item5512" },
		-- "Pénitence" 47540
		{ 47540, jps.hp() < 0.80 , "player" , "Aggro_Penance" },
		-- "Don des naaru" 59544
		{ 59544, jps.hp() < 0.80 , "player" , "Aggro_Naaru" },
		-- "Nova" 132157 -- "Words of Mending" 155362 "Mot de guérison"
		{ 132157, jps.Moving and jps.hp() < 0.90 , "player" , "Aggro_Nova" },
	}},
	
	-- OFFENSIVE Dispel -- "Dissipation de la magie" 528
	{ 528, jps.castEverySeconds(528,8) and jps.DispelOffensive(rangedTarget) , rangedTarget , "|cff1eff00DispelOffensive" },
	
	-- DAMAGE
	-- "Mot de pouvoir : Réconfort" -- "Power Word: Solace" 129250 -- REGEN MANA
	{ 129250, jps.IsSpellInRange(129250,rangedTarget) and canDPS(rangedTarget) , rangedTarget, "|cFFFF0000Solace" },
	-- "Flammes sacrées" 14914  -- "Evangélisme" 81661
	{ 14914, jps.IsSpellInRange(14914,rangedTarget) and canDPS(rangedTarget) , rangedTarget , "|cFFFF0000Flammes" },

	-- PAIN FRIEND
	{ "nested", PainFriend ~= nil and jps.hpInc(PainFriend) < 0.80 ,{
		-- "Power Word: Shield"
		{ 17, not jps.buff(17,PainFriend) and not jps.debuff(6788,PainFriend) , PainFriend , "Bubble_PainFriend" },
		-- "Pénitence" 47540
		{ 47540, jps.hpInc(PainFriend) < 0.60 , PainFriend , "Penance_PainFriend" },
		-- "Soins rapides" 2061
		{ 2061, not jps.Moving and jps.hpInc(PainFriend) < 0.60 , PainFriend, "FlashHeal_PainFriend" },
	}},
	
	-- LOWEST TTD -- LowestFriendTTD friend unit in raid with TTD < 6 sec 
	{ "nested", LowestFriendTTD ~= nil and jps.hpInc(LowestFriendTTD) < 0.80 ,{
		-- "Power Word: Shield" -- "Egide divine" 47515 "Divine Aegis"
		{ 17, jps.hpSum(LowestFriendTTD) < 0.80 and not jps.buff(17,LowestFriendTTD) and not jps.debuff(6788,LowestFriendTTD) , LowestFriendTTD , "Bubble_Lowest_TTD" },
		-- "Pénitence" 47540
		{ 47540, jps.hp(LowestFriendTTD) < 0.60 , LowestFriendTTD , "Penance_Lowest_TTD" },
		-- "Soins rapides" 2061
		{ 2061, not jps.Moving and groupHealth > 0.80 and jps.hp(LowestFriendTTD) < 0.60 , LowestFriendTTD , "FlashHeal_Lowest_TTD" },
	}},
	
	-- HIGHEST DAMAGE -- Highest Damage Friend with Lowest Health
	{ "nested", IncomingDamageFriend ~= nil and jps.hpInc(IncomingDamageFriend) < 0.80 ,{
		-- "Power Word: Shield" -- "Egide divine" 47515 "Divine Aegis"
		{ 17, jps.hpSum(IncomingDamageFriend) < 0.80 and not jps.buff(17,IncomingDamageFriend) and not jps.debuff(6788,IncomingDamageFriend) , IncomingDamageFriend , "Bubble_Lowest_DAMAGE" },
		-- "Pénitence" 47540
		{ 47540, jps.hp(IncomingDamageFriend) < 0.60 , IncomingDamageFriend , "Penance_Lowest_DAMAGE" },
		-- "Soins rapides" 2061
		{ 2061, not jps.Moving and groupHealth > 0.80 and jps.hp(IncomingDamageFriend) < 0.60 , IncomingDamageFriend , "FlashHeal_Lowest_DAMAGE" },
	}},

	-- "Divine Star" Holy 110744 Shadow 122121
	{ 110744, FriendIsFacingLowest ~= nil and CountFriendIsFacing > 3 , FriendIsFacingLowest ,  "DivineStar_Count" },
	{ 110744, FriendIsFacingLowest ~= nil and jps.hp(FriendIsFacingLowest) < 0.80 , FriendIsFacingLowest ,  "DivineStar_Lowest" },
	-- "Cascade" Holy 121135 Shadow 127632
	{ 121135, not jps.Moving and CountFriendLowest > 2 , LowestImportantUnit ,  "Cascade_Count" },
	{ 121135, not jps.Moving and POHTarget ~= nil and canHeal(POHTarget) , POHTarget ,  "Cascade_POH" },

	-- TIMER POM
	-- "Prière de guérison" 33076 -- Buff POM 41635 -- 
	{ "nested", not jps.Moving and CountFriendLowest > 2 and jps.hpSum(LowestImportantUnit) > 0.50 ,{
		{ 33076,  MendingFriend ~= nil , MendingFriend ,  "Mending_CountFriendLowest" },
		{ 33076, not jps.buff(41635,LowestImportantUnit) , LowestImportantUnit ,  "Mending_CountFriendLowest" },
	}},
	{ "nested", not jps.Moving and not jps.buffTracker(41635) ,{
		{ 33076, MendingFriend ~= nil , MendingFriend , "Tracker_Mending_Friend" },
		{ 33076, not jps.buff(41635,LowestImportantUnit) , LowestImportantUnit , "Tracker_Mending_Lowest" },
	}},

	-- "Archange" 81700 -- Buff 81700 -- "Archange surpuissant" 172359  100 % critique POH or FH
	{ 81700, jps.buffStacks(81661) == 5 and  groupHealth < 0.80 , "player", "ARCHANGE_POH" },
	{ 81700, jps.buffStacks(81661) == 5 and  jps.hp(LowestImportantUnit) < 0.80 , "player", "ARCHANGE_Lowest" },

	-- GROUP HEAL --
	{ "nested", not jps.Moving and POHTarget ~= nil and canHeal(POHTarget) ,{
		-- "POH" 596 -- "Archange surpuissant" 172359  100 % critique POH or FH
		{ 596, jps.buff(172359) , POHTarget , "Archange_POH" },
		-- "POH" 596 -- "Power Infusion" 10060 "Infusion de puissance"
		{ 596, jps.buff(10060) , POHTarget , "PowerInfusion_POH" },
		-- "POH" 596 -- Buff "Borrowed" 59889
		{ 596, jps.buff(59889) and jps.hpSum(LowestImportantUnit) > 0.40 , POHTarget , "Borrowed_POH" },
	}},
	
	-- FAKE CAST -- 6948 -- "Hearthstone"
	--{ {"macro","/use item:6948"}, jps.PvP and jps.hp(LowestImportantUnit) > 0.80 and not jps.Moving and jps.itemCooldown(6948) == 0 , "player" , "Aggro_FAKECAST" },
	
	-- DAMAGE
	{ "nested", jps.hp(LowestImportantUnit) > 0.80 and jps.MultiTarget and canDPS(rangedTarget) ,{
		-- "Mot de l'ombre: Douleur" 589
		{ 589, jps.myDebuffDuration(589,rangedTarget) == 0 and jps.PvP , rangedTarget , "|cFFFF0000Douleur" },
		{ 589, jps.myDebuffDuration(589,rangedTarget) == 0 and not IsInGroup() , rangedTarget , "|cFFFF0000Douleur" },
		-- "Châtiment" 585
		{ 585, not jps.Moving and jps.buffStacks(81661) < 5 , rangedTarget , "|cFFFF0000Chatiment_Stacks" },
		{ 585, not jps.Moving and jps.buffDuration(81661) < 9 , rangedTarget , "|cFFFF0000Chatiment_Stacks" },
		{ 585, not jps.Moving and jps.hp(LowestImportantUnit) < 1 and jps.mana() > 0.60 , rangedTarget , "|cFFFF0000Chatiment_Health" },
		-- "Pénitence" 47540 -- jps.glyphInfo(119866) -- allows Penance to be cast while moving.
		{ 47540, jps.PvP , rangedTarget ,"|cFFFF0000Penance_PvP" },
		{ 47540, not IsInGroup() , rangedTarget ,"|cFFFF0000Penance_Solo" },
		-- "Châtiment" 585
		{ 585, not jps.Moving and jps.PvP , rangedTarget , "|cFFFF0000Chatiment_PvP" },
		{ 585, not jps.Moving and not IsInGroup() , rangedTarget , "|cFFFF0000Chatiment_Solo" },
	}},

	-- GROUP HEAL --
	-- "Carapace spirituelle" spell & buff "player" 109964 buff target 114908
	{ "nested", jps.buffId(109964) and not jps.Moving , parseShell },
	-- "Carapace spirituelle" spell & buff "player" 109964 buff target 114908
	{ 109964, jps.IsSpellKnown(109964) and POHTarget ~= nil and canHeal(POHTarget) , POHTarget , "Carapace_POH" },
	-- "Prière de soins" 596 "Prayer of Healing"
	{ 596, not jps.Moving and POHTarget ~= nil and canHeal(POHTarget) , POHTarget , "POH" },

	-- HEAL --
	-- "Pénitence" 47540
	{ 47540, jps.hp(LowestImportantUnit) < 0.80 , LowestImportantUnit , "Top_Penance" },
	-- "Don des naaru" 59544
	{ 59544, jps.hp(LowestImportantUnit) < 0.80 , LowestImportantUnit , "Top_Naaru" },
		
	{ "nested", not jps.Moving and jps.hp(LowestImportantUnit) < 0.80 ,{	
		-- "Flash Heal" top off -- Less important to be conservative with mana in PvP
		{ 2061, jps.PvP and jps.mana() > 0.50 and jps.hpSum(LowestImportantUnit) < 0.80 , LowestImportantUnit , "Top_FlashHeal" },
		-- "Soins" 2060 -- Buff "Borrowed" 59889 -- Buff "Clarity of Will" 152118
		{ 2060, jps.buff(17,LowestImportantUnit) , LowestImportantUnit , "Top_Soins_Shield"  },
		{ 2060, jps.buff(59889) , LowestImportantUnit , "Top_Soins_Borrowed"  },
		{ 2060, jps.buff(10060) , LowestImportantUnit , "Top_Soins_Infusion"  },
		-- "Soins" 2060
		{ 2060, true , LowestImportantUnit , "Top_Soins"  },
	}},
	
	-- "Nova" 132157 -- "Words of Mending" 155362 "Mot de guérison"
	{ 132157, jps.Moving and countFriendNearby > 2 , "player" , "Nova" },
	-- "Torve-esprit" 123040 -- "Ombrefiel" 34433 "Shadowfiend"
	{ 34433, priest.canShadowfiend("target") , "target" },
	{ 123040, priest.canShadowfiend("target") , "target" },
	-- "Châtiment" 585
	{ 585, not jps.Moving and jps.buffStacks(81661) < 5 and canDPS(rangedTarget) , rangedTarget , "|cFFFF0000Chatiment_Stacks" },
	{ 585, not jps.Moving and jps.buffDuration(81661) < 9 and canDPS(rangedTarget) , rangedTarget , "|cFFFF0000Chatiment_Stacks" }

}

	spell,target = parseSpellTable(spellTable)
	return spell,target
end

jps.registerRotation("PRIEST","DISCIPLINE", priestDisc , "Disc Priest PvP", false, true)
----------------------------------------------------------------------------------------------------------------
-------------------------------------------------- ROTATION OOC ------------------------------------------------
----------------------------------------------------------------------------------------------------------------

jps.registerRotation("PRIEST","DISCIPLINE",function()

	local LowestImportantUnit = jps.LowestImportantUnit()
	local POHTarget, _, _ = jps.FindSubGroupHeal(0.50)
	local Tank,TankUnit = jps.findTankInRaid() -- default "focus"
	local rangedTarget, _, _ = jps.LowestTarget() -- default "target"
	local BodyAndSoul = jps.IsSpellKnown(64129) -- "Body and Soul" 64129

	if canDPS("target") then rangedTarget =  "target"
	elseif canDPS("targettarget") then rangedTarget = "targettarget"
	elseif canDPS("focustarget") then rangedTarget = "focustarget"
	end
	-- if your target is friendly keep it as target
	if not canHeal("target") and canDPS(rangedTarget) then jps.Macro("/target "..rangedTarget) end
	
	if jps.ChannelTimeLeft() > 0 then return nil end
	if jps.CastTimeLeft() > 0 then return nil end
	
	local spellTableOOC = {

	-- SNM "Levitate" 1706
	{ 1706, jps.fallingFor() > 1.5 and not jps.buff(111759) , "player" },
	{ 1706, IsSwimming() and not jps.buff(111759) , "player" },

	-- "Fortitude" 21562 -- "Commanding Shout" 469 -- "Blood Pact" 166928
	{ 21562, jps.buffMissing(21562) and jps.buffMissing(469) and jps.buffMissing(166928) , "player" },
	-- "Gardien de peur" 6346
	{ 6346, not jps.buff(6346,"player") , "player" },
	-- "Don des naaru" 59544
	{ 59544, jps.hp("player") < 0.75 , "player" },
	-- "Shield" 17 "Body and Soul" 64129 -- figure out how to speed buff everyone as they move
	{ 17, jps.Moving and BodyAndSoul and not jps.debuff(6788,"player") , "player" , "Shield_BodySoul" },
	-- "Pénitence" 47540
	{ 47540, jps.hp(LowestImportantUnit) < 0.50  , LowestImportantUnit , "Penance" },
	-- "Prière de soins" 596 "Prayer of Healing"
	{ 596, not jps.Moving and canHeal(POHTarget) , POHTarget , "POH" },
	-- "Soins" 2060
	{ 2060, not jps.Moving and jps.hp(LowestImportantUnit) < 0.90 , LowestImportantUnit , "Soins"  },
	
	-- "Nova" 132157 -- buff "Words of Mending" 155362 "Mot de guérison"
	{ 132157, jps.IsSpellKnown(152117) and jps.UseCDs and jps.buffDuration(155362) < 9 , "player" , "Nova_WoM" },
	
	-- TIMER POM -- "Prière de guérison" 33076 -- Buff POM 41635
	{ 33076, jps.UseCDs and not jps.Moving and not jps.buff(41635,Tank) and canHeal(Tank) , Tank , "Mending_Tank" },
	-- ClarityTank -- "Clarity of Will" 152118 shields with protective ward for 20 sec
	{ 152118, not jps.Moving and canHeal(Tank) and not jps.buff(152118,Tank) and not jps.isRecast(152118,Tank) , Tank , "Clarity_Tank" },
	
	-- "Oralius' Whispering Crystal" 118922 "Cristal murmurant d’Oralius"
	{ {"macro","/use item:118922"}, not jps.buff(105691) and not jps.buff(156070) and not jps.buff(156079) and jps.itemCooldown(118922) == 0 and not jps.buff(176151) , "player" , "Item_Oralius"},

}

	local spell,target = parseSpellTable(spellTableOOC)
	return spell,target

end,"OOC Disc Priest PvP",false,false,true)


-- REMOVED -- http://fr.wowhead.com/guide=2298/warlords-of-draenor-priest-changes#specializations-removed
-- Borrowed Time has been redesigned. It now increases the Priest's stat gains to Haste from all sources by 40% for 6 seconds.
-- Void Shift
-- Inner Focus has been removed.
-- Inner Will has been removed.
-- Rapture has been removed.( Removes the cooldown on Power Word: Shield)
-- Hymn of Hope has been removed.
-- Heal has been removed.

-- CHANGED --
-- Greater has been renamed to Heal.
-- Renew Holy -- HOLY
-- Binding Heal -- HOLY
-- Mot de l'ombre : Mort 32379 -- SHADOW
-- Divine Insight -- HOLY

-------------------
-- TO DO --
-------------------
-- jpevents.lua: jps.whoIsCapping.
   -- Look for flag capture event and honorable defender buff 68652 on player?
      -- Buff 68652 only for AB, EotS and IoC
      -- Maybe use subzone location for others?
   -- if both == true target flag capper and attack
   -- if both == true and attack cast on cd cast HN
     
-- jpevents.lua: look for long lasting and channeled ccs being cast(cyclone).
   -- if caster targeting player, target caster
      -- silence 3/4 of way through cast
     
-- OOC ACTIONS ON ENTERING INSTANCE, TALENT/GLYPH SWAP ACCORDING TO ENEMY COMP --
-- http://www.wowinterface.com/downloads/info22148-GlyphKeeper-TalentGlyphMgmt.html#info
-- http://www.wowinterface.com/downloads/info23452-AutoConfirmTalents.html
-- Should be universal function to use with all classes.
-- Announce
   -- "Swapping talent to TalentName."
   -- "Swapping glyph to GlyphName."

-- Enemy Team Comps: 1 or 2 of same in 2s, 2 or 3 in 3s, 3 or > in 5s.
   -- MeleeTeam = melee classes: Warrior, FDK, BDK, enshaman, rpally.
   -- DOTTeam = dot classes: Lock, spriest, boomkin, UDK. Maybe arcane and fire mage?
   -- StealthTeam = stealth classes: Rogue, fdruid.
   -- RangeTeam = ranged classes: Hunter, boomkin, mage, spriest, lock, elshaman.
   -- RootTeam = root/slow/snare classes: Hunter, frmage. May not need.

-- Talents --
-- http://wow.gamepedia.com/World_of_Warcraft_API#Talent_Functions
-- http://wow.gamepedia.com/API_LearnTalent -- Is now LearnTalents
-- http://wowprogramming.com/docs/api/LearnTalent -- Is now LearnTalents
-- LearnTalents( tabIndex, talentIndex )
-- Tab top = 1(primary spec), bottom = 2(secondary spec).
-- TalentIndex counts from top left, left to right, top to bottom, 1-21.
-- If tab top, Desperate Prayer = LearnTalents(1, 2), Saving Grace = LearnTalents(1, 21).
-- Only do if have Tome of the Clear Mind in bags. Give count on use.
   -- "You have TomeCount of Tome of the Clear Mind remaining."
-- Alert if <= 1 Tome of the Clear Mind when accept queue or leave instance.

-- PvP Arena/BG Talent Swaps --
-- T1 --
-- Desperate Prayer, default.
-- Spectral Guise vs RangeTeam. Mage + hunter + boomkin, etc.
-- Angelic Bulwark vs teams likely to focus player. MeleeTeam or warrior + dk + hunter, etc.

-- T2 --
-- Body and Soul, default.
-- Phantasm vs root/slow teams or in capture the flag maps.
   -- WSG, TP.

-- T3 --
-- Surge of Light vs StealthTeam.
   -- Spam Holy Nova and/or PW:S to get proc.
      -- Random spam timer for HN when OOC to keep enemy off rhythm?
         -- Do not spam if stealthed
-- Power Word: Solace, default.

-- T4 --
-- Void Tendrils vs MeleeTeam & on capture the flag maps (WSG, SotA).
-- Psychic Scream, default & resource defense maps.
   -- AB, AV, EotS, BfG, DG, SM, ToK, IoC, Ashran

-- T5 --
-- Power Infusion, default.
-- Spirit Shell vs MeleeTeam.
   -- Pop @ beginning of arena. Stack 2x with quick or insta heals.
   -- Teammate(s) in trouble/dying & enemy pops offensive cds.
   -- When teammate(s) @ full health and on offensive.

-- T6 --
-- Cascade if > 5 in raid or if in bg.
-- Divine Star if < 6 in raid or if in arena.

-- T7 --
-- Clarity of Will vs dps teams likely to focus player.
   -- PW:S to get borrowed time then stack CoW x 2 + PoM if getting trained.
   -- Watch enemy offensive cds. Reapply CoW when timer(s) is/are about to be up.
      -- New jpevents.lua function, jps.enemyCooldownWatch.
         -- Need table of major offensive cds and cd durations.
            -- Celestial Alignment 112071, 360s
            -- Druid Berserk
-- Words of Mending vs DOTTeams.
-- Saving Grace, default.
   -- When enemy pops offensive cds.
   
-- Glyphs --
-- http://wow.gamepedia.com/MACRO_castglyph
   -- /castglyph glyph slot
      -- /castglyph Glyph of the Inquisitor major3 or maybe /castglyph Inquisitor major3
-- Glyph of the Inquisitor if enemy arena team has mage and/or shaman.
   -- Wait just before poly cast is finished, attack with PW:Sol(LowestTarget).
-- Glyph of Purify vs DOT cleave teams? Lock + spriest, boomkin + DK, etc.
-- Glyph of Reflective Shield vs MeleeTeam and 2s.? -- Caution, will break poly/cc.
-- Glyph of Shadow Magic vs interrupt teams.
   -- Bait interrupt with fake cast, stop 1/2 way, fade, cast spell.
   
-- Double melee that will more than likely sit on you: penance, shadow magic, weakened soul
-- Double caster with Mage: shadow magic, inquisitor, penance
-- Mage + pally of any kind: shadow magic, inquisitor, mass dispell
-- Any sort of other pally team: shadow magic, mass dispell, penance
-- 1 range 1 melee: shadow magic, penance, weakened soul.
-- Mending with WoM.

-- TRICKS & STRATEGIES --
-- Fear ward right before player is feared. Don't fear ward on cd. Easily dispelled.
   -- Look for fear cast event of EnemyCaster, wait for 3/4 cast time, cast Fear Ward.
-- Levitate when ooc for extra debuff to dispel.
-- Levitate when dark sim debuff is on player.

-- Best Comps for Disc
-- Feral + Hunter + Disc, Pala + Hunter + Disc, Feral + Mage + Disc
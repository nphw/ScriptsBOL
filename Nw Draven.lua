--[[
NEPHEW - Draven's  0.1
   Created by NepheW - Christianlb
   
    
    ==================================
    |            Summary             |
    ==================================
        -Use "shift" in game for options and keybindings
    
    ==================================
    |           Change Log           |
    ==================================
    Version info:
        x.y.z
        x = major release
        y = major feature changes
        z = feature tweaks and bug fixes
        
    1.1.0:
        -Updated to use AllClass
        -Added second target selector for "e" range, always uses low hp selector
        -Updated picking up axes so it won't pick up axes if an enemy is between AA max range and E max range.
            This allows you to chase instead of running back to pick up and axe and enemy getting away
        -Updated Q prediction to be more accurate
        
    1.1.2:
        -Added "autoBuffChampsOnAttack" option
        -Fixed bug with W buff using the clearMinionsHK
        -General cleanup
        
    1.2.0:
        -Recoded most of the script
        -Added orbwalking
        -Additional checks for safe zone (based on reticle position and player position)
        -Additional check for enemy turret zones
        -Modified E logic and changed it to target closest target
        
    1.2.1:
        -Fixed second reticle bug, readded logic
    
    1.3.0:
        -Fixed bug with safe zones. Was picking up reticle if enemy was in player safe zone
        -Fixed bug with not picking up axes in ally turret range
        -Added "stand" zone around player
        -Added autocast of w if enemy is within safe zone (easier escaping and kiting) if autoBuffChamps is enabled
        -Changed reticle tracking to use table
        
    1.3.1
		--Changed FindMinions() since it was causing some people to crash
    ==================================
    |   Various Useful Draven Info   |
    ==================================
        buff names
            -buff name = dravenspinningattack  -- this is Q's buff
            -dravenfurybuff   -- this is the Attack speed part of the buff
            -dravenFury  -- this is the movement speed part of the buff

        spell names
            -DravenBasicAttack
            -DravenBasicAttack2
            -DravenCritAttack
            -DravenCritAttack2
            -dravenspinning  --this is casting Q
            -dravenspinningattack  this is attacking with Q
            -dravenspinningattack2  this is attacking with Q on a 2nd attack
            -DravenFury  -- this is casting W
            -DravenDoubleShot  --casting E
            -DravenRCast -- cast R
            -dravendoublecast -- cast R again when deployed
  ]]

if GetMyHero().charName == "Draven" then
    function OnLoad()
        player = GetMyHero()
        
        --[[ Hotkeys ]]
        moveAndAttackHK	= 	32		-- spacebar
        clearMinionsHK	= 	88		--"X"
        EHK				= 	84		--"T"
        catchAxesHK		= 	67		--"C"
        
        
        --[[ Options ]]
        playerSafeZone = 100
        reticleSafeZone = 100
        
        drawAttackRange			=	true
        drawAttackRangeColor	=	0x00FF0000

        drawERange				=	true
        drawERangeColor			=	0x00FF0000

        drawStandRange			= 	true
        standRange				=	220
        drawStandRangeColor		=	0xAA333333
        
        --[[ 
        =============================================
        == Below this line is for developers only! == 
        =============================================
        ]]
        
        --[[ Draven Attributes ]]
        hitboxAvg = 200				--AA ranges are calculated from edge of hitboxes (varies slightly based on enemy hitbox)
        aaRange = 550 + hitboxAvg
        aaDelay = 300
        startAttackSpeed = 0.679
        
        qRadius = 90
        
        eRange = 1100
        eVelocity = 1.37
        eCastDelay = 300

        --[[ Objects and Buffs ]]
        aaParticles = {"Draven_BasicAttack_mis",
                "Draven_BasicAttack_mis_bloodless",				--untested
                "Draven_BasicAttack_mis_shadow",				--untested
                "Draven_BasicAttack_mis_shadow_bloodless",		--untested
                "Draven_crit_mis",
                "Draven_crit_mis_bloodless",					--untested
                "Draven_crit_mis_shadow",						--untested
                "Draven_crit_mis_shadow_bloodless" }			--untested
        qParticles = {"Draven_Q_mis",
                "Draven_Q_mis_bloodless",						--untested
                "Draven_Q_mis_shadow",							--untested
                "Draven_Q_mis_shadow_bloodless",				--untested
                "Draven_Qcrit_mis",
                "Draven_Qcrit_mis_bloodless",					--untested
                "Draven_Qcrit_mis_shadow",						--untested
                "Draven_Qcrit_mis_shadow_bloodless" }
        qreticleName = "Draven_Q_reticle_self.troy"
        qHitName = "Draven_Q_tar.troy"	-- Q hit target, right before another _mis is generated
        --qreticleCatchName = "Draven_Q_ReticleCatchSuccess.troy"  --not currently used, may use in future
        qBuffName = "dravenspinningattack"
        qbuffEndName = "draven_spinning_buff_end_sound.troy"
        wBuffAttackSpeed = "dravenfurybuff" 					--attack speed buff
        wBuffMovement = "DravenFury" 							--movement speed buff
        
        --[[ Misc Globals ]]
        reticleDetectionRange = 1200							-- will not track reticles outside this range
		lastTarget = nil										-- last target that was attacked
        shotFiredAt = GetTickCount()							-- tracks last shot to allow orbwalking
        shotFired = false										-- if false, assumes we can attack
        towers = {}												-- array of all enemy turrets
        reticles = {}                                           -- array of all reticles
        qMis = {}                                               -- all q missile objects currently on the way to target
        qStacks = 0
        maxStacks = 2
        mouseFlag = false										-- used for choosing when to hold position if mouse is near hero

        --[[ Script Menu ]]
        DravenConfig = scriptConfig("Draven's Combo","dravencombo")
        DravenConfig:addParam("moveAndAttack","Move and Attack",SCRIPT_PARAM_ONKEYDOWN, false, moveAndAttackHK)
        DravenConfig:addParam("clearMinions","Clear Minions",SCRIPT_PARAM_ONKEYDOWN, false, clearMinionsHK)
        DravenConfig:addParam("castE","Cast E on Target",SCRIPT_PARAM_ONKEYDOWN, false, EHK)
        DravenConfig:addParam("catchAxes","Auto Catch Axes",SCRIPT_PARAM_ONKEYTOGGLE,false,catchAxesHK)
        DravenConfig:addParam("autoBuffChamps","Auto Cast W (Champs)",SCRIPT_PARAM_ONOFF,true)
		DravenConfig:addParam("autoBuffMinion","Auto Cast W (Minion)",SCRIPT_PARAM_ONOFF,false)
        DravenConfig:permaShow("moveAndAttack")
        DravenConfig:permaShow("clearMinions")
        DravenConfig:permaShow("catchAxes")
        
        ts = TargetSelector(TARGET_LOW_HP, aaRange, DAMAGE_PHYSICAL)
        minionArray = minionManager(1, aaRange, player, MINION_SORT_HEALTH_ASC)
		
        DravenConfig:addTS(ts)
        
        --[[ Build Towers Array ]]
        for i = 1, objManager.iCount, 1 do
            local obj = objManager:getObject(i)
            if obj ~= nil and string.find(obj.type, "obj_Turret") ~= nil and string.find(obj.name, "_A") == nil and obj.health > 0 then
                if not string.find(obj.name, "TurretShrine") and obj.team ~= player.team then
                    table.insert(towers, obj)
                end
            end
        end
    end

--[[
        API :
        ----- Local Functions -----
        FindMinion()							-- return lowest hp minion in q range				
        InTurretRange(v)						-- return true if vector is in range of a turret
        TimeToShoot()							-- return true if basic attack is ready to be shot
        GetClosestHero(int)						-- returns closest valid enemy hero within range
        IsZoneSafe(v, int)						-- returns false if enemy is in "x" range of "v"
]]
    
    --[[ Local Functions ]]
    local function FindMinion()
		minionArray:update()
		returnMinion = nil
		for i,minionObject in ipairs(minionArray.objects) do
			if minionObject.team ~= player.team then
				returnMinion = minionObject
				break
			end
		end
		
		return returnMinion
	end

    local function InTurretRange(v)
        local flag = false
        for i, tow in ipairs(towers) do
            if tow.health > 0 then
                if math.sqrt((tow.x - v.x) ^ 2 + (tow.z - v.z) ^ 2) < 975 then
                    flag = true
                end
            else
                table.remove(towers, i)
            end
        end
        return flag
    end
    
    local function TimeToShoot()
        if GetTickCount() >= (shotFiredAt + (1000/(player.attackSpeed/(1/startAttackSpeed))) - aaDelay) then return true
        else return false end
    end
    
    local function GetClosestHero(range)
		local closestTarget = nil
	
        for i = 1, heroManager.iCount, 1 do
            local curHero = heroManager:GetHero(i)
            if curHero ~= nil and ValidTarget(curHero, range, true) then
                if closestTarget == nil then
                    closestTarget = curHero
                else
                    if player:GetDistance(curHero) < player:GetDistance(closestTarget) then
                        closestTarget = curHero
                    end
                end
            end
        end
        
        return closestTarget
    end
    
    local function IsZoneSafe(v, rng)
        local flag = true
        
        for i=1, heroManager.iCount, 1 do
            local curHero = heroManager:GetHero(i)
            if curHero ~= nil and curHero.team ~= player.team 
                and not curHero.dead and GetDistance(curHero, v) < (rng) then
                flag = false
            end
        end
        
        return flag
    end
    
	local function InStandRange()
		return (GetDistanceFromMouse(player) < standRange)
	end
	
    --[[ Global Functions ]]
    function OnTick()
        ts:update()
        
        local qTarget = nil
        local qPrediction
        
        if shotFired and TimeToShoot() then
            shotFired = false
        end
            
        -- set q target if a keybind is held
        if DravenConfig.moveAndAttack and ts.target ~= nil and ValidTarget(ts.target, aaRange, true) then
            qTarget = ts.target
        elseif DravenConfig.clearMinions then
            qTarget = FindMinion()
        else
            qTarget = nil
        end
        
        
        
        --[[ Begin Axe Catching Logic ]]
        if DravenConfig.catchAxes and not DravenConfig.moveAndAttack and not DravenConfig.clearMinions then
            if next(reticles) then
                if GetDistance(player, reticles[1]) > qRadius and IsZoneSafe(reticles[1], reticleSafeZone) and not InTurretRange(reticles[1]) then
                    player:MoveTo(reticles[1].x, reticles[1].z)
                end
            end
        end
        --[[ End Axe Catching Logic ]]
        
        
        
        --[[ Begin E Logic ]]
        if DravenConfig.castE and player:CanUseSpell(_E) == READY then
            local eTarget = nil
            
            if qTarget ~= nil then
                eTarget = qTarget
            else
                eTarget = GetClosestHero(eRange)
            end
            
            if eTarget ~= nil then
                qPrediction = GetPredictionPos(eTarget,math.floor(player:GetDistance(eTarget)/eVelocity) + eCastDelay)
                if qPrediction and GetDistance(player, qPrediction) < eRange - 50 then -- sub 50 for margin of error
                    CastSpell(_E, qPrediction.x, qPrediction.z)
                end
            end
        end
        --[[ End E Logic ]]
        
        
        
        --[[ Begin Auto-buff in Enemy In Safe Zone ]]
        if DravenConfig.autoBuffChamps and not IsZoneSafe(player, playerSafeZone)
            and player:CanUseSpell(_W) == READY and not TargetHaveBuff(wBuffAttackSpeed, player) then
            CastSpell(_W)
        end
        --[[End Auto-buff if Enemy In Safe Zone ]]
        
        
        --[[  Begin Main Hotkey Logic ]]
        if DravenConfig.clearMinions or DravenConfig.moveAndAttack then
            local curMouseRange = GetDistance(mousePos, player)
            if not shotFired and qTarget ~= nil then
                if ValidTarget(qTarget, aaRange, true) then
                    if ((DravenConfig.autoBuffChamps and DravenConfig.moveAndAttack) or (DravenConfig.autoBuffMinion and DravenConfig.clearMinions))
					  and player:CanUseSpell(_W) == READY and not TargetHaveBuff(wBuffAttackSpeed, player) then
                        CastSpell(_W)
                    elseif player:CanUseSpell(_Q) == READY and qStacks < maxStacks 
                    and (IsZoneSafe(player, playerSafeZone) or curMouseRange < standRange) then
                        CastSpell(_Q)
                    else
                        if InStandRange() and mouseFlag == false then
                            player:HoldPosition()
                            mouseFlag = true
                        end
                        
                        if IsZoneSafe(player, playerSafeZone) or InStandRange() then
                            player:Attack(qTarget)
							lastTarget = qTarget
                        end
                    end
                end
            elseif next(reticles) then
                local closestHero = GetClosestHero(900)
                if InStandRange() and not InTurretRange(reticles[1]) then
                    player:MoveTo(reticles[1].x, reticles[1].z)
                    mouseFlag = false
                elseif GetDistance(player, reticles[1]) > qRadius and not InTurretRange(reticles[1]) and IsZoneSafe(reticles[1], reticleSafeZone) and IsZoneSafe(player, playerSafeZone)
                    and not (closestHero ~= nil and GetDistance(reticles[1], closestHero) > aaRange) -- if enemy is found within 900 but the distance to him is greater than distance to reticle
                    and not InStandRange() then
                    player:MoveTo(reticles[1].x, reticles[1].z)
                    mouseFlag = false
                else
                    if not InStandRange() then
                        player:MoveTo(mousePos.x, mousePos.z)
                        mouseFlag = false
                    else
                        player:HoldPosition()
                    end
                end
            else
                if not InStandRange() then
                    player:MoveTo(mousePos.x, mousePos.z)
                    mouseFlag = false
                else
                    player:HoldPosition()
                end
            end
        end
        --[[ End Main Hotkey Logic ]]
    end

    function OnCreateObj(object)
        if myHero.dead then return end
        
        for _, v in pairs(qParticles) do
            if string.find(object.name, v) then
                if GetDistance(object, player) < 333 then
                    shotFired = true
                    shotFiredAt = GetTickCount()
                end
            end
        end
        
        for _, v in pairs(aaParticles) do
            if string.find(object.name, v) then
                shotFired = true
                shotFiredAt = GetTickCount()
            end
        end
        
        if object ~= nil and object.name ~= nil and object.x ~= nil and object.z ~= nil and GetDistance(player, object) <= reticleDetectionRange then
            if object.name == qreticleName then
                table.insert(reticles, object)
            elseif object.name == qbuffEndName then
                qStacks = 0
            end
        end
    end

	function MinionMarkerOnLoad()
		minionTable = {}
		for i = 0, objManager.maxObjects do
			local obj = objManager:GetObject(i)
			if obj ~= nil and obj.type ~= nil and obj.type == "obj_AI_Minion" then 
				table.insert(minionTable, obj) 
			end
		end
	end
	
    function OnDeleteObj(object)
        if object ~= nil and object.name ~= nil and object.x ~= nil and object.z ~= nil and GetDistance(player, object) <= reticleDetectionRange then
            if object.name == qreticleName then
                table.remove(reticles, 1)
                qStacks = qStacks - 1
            end
        end
    end

    function OnDraw()
        if not myHero.dead then
            if drawAttackRange == true then
                DrawCircle(player.x, player.y, player.z, aaRange, drawAttackRangeColor)
            end
            if drawERange == true then
                DrawCircle(player.x, player.y, player.z, eRange, drawERangeColor)
            end
            if drawStandRange == true then
                DrawCircle(player.x, player.y, player.z, standRange, drawStandRangeColor)
            end
        end
    end

    PrintChat(" >> NEPHEW Draven's 0.1 checking...")
	PrintChat(" >> NEPHEW Draven's 0.1 Load. Good Game!")
end

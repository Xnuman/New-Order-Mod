-- $Id: //depot/Projects/StarWars_Expansion/Run/Data/Scripts/AI/LandMode/SecureBuildPadEscorted.lua#11 $
--/////////////////////////////////////////////////////////////////////////////////////////////////
--
-- (C) Petroglyph Games, Inc.
--
--
--  *****           **                          *                   *
--  *   **          *                           *                   *
--  *    *          *                           *                   *
--  *    *          *     *                 *   *          *        *
--  *   *     *** ******  * **  ****      ***   * *      * *****    * ***
--  *  **    *  *   *     **   *   **   **  *   *  *    * **   **   **   *
--  ***     *****   *     *   *     *  *    *   *  *   **  *    *   *    *
--  *       *       *     *   *     *  *    *   *   *  *   *    *   *    *
--  *       *       *     *   *     *  *    *   *   * **   *   *    *    *
--  *       **       *    *   **   *   **   *   *    **    *  *     *   *
-- **        ****     **  *    ****     *****   *    **    ***      *   *
--                                          *        *     *
--                                          *        *     *
--                                          *       *      *
--                                      *  *        *      *
--                                      ****       *       *
--
--/////////////////////////////////////////////////////////////////////////////////////////////////
-- C O N F I D E N T I A L   S O U R C E   C O D E -- D O   N O T   D I S T R I B U T E
--/////////////////////////////////////////////////////////////////////////////////////////////////
--
--              $File: //depot/Projects/StarWars_Expansion/Run/Data/Scripts/AI/LandMode/SecureBuildPadEscorted.lua $
--
--    Original Author: Steve Copeland
--
--            $Author: James_Yarrow $
--
--            $Change: 56734 $
--
--          $DateTime: 2006/10/24 14:15:48 $
--
--          $Revision: #11 $
--
--/////////////////////////////////////////////////////////////////////////////////////////////////

require("pgevents")

function Definitions()

	Category = "Secure_Contestable_Escorted"
	IgnoreTarget = true
	TaskForce = 
	{
		{
			"MainForce"
			,"Infantry = 1,4"
		},
		{
			"EscortForce"		
			,"Infantry | Vehicle | LandHero = 1,4"
		}
	}

	AllowEngagedUnits = false
	
	wait_for_build_time = 10
end

function MainForce_Thread()
	BlockOnCommand(MainForce.Produce_Force())
	
	QuickReinforce(PlayerObject, AITarget, MainForce, EscortForce)
	
	MainForce.Activate_Ability("SPREAD_OUT", false)
	
	unit_table = MainForce.Get_Unit_Table()
	
	for i, unit in pairs(unit_table) do
		lib_nearest_garrison = Find_Nearest(unit, "CanContainGarrison", unit.Get_Owner(), true)
		
		if TestValid(lib_nearest_garrison) and unit.Can_Garrison(lib_nearest_garrison) then
			unit.Garrison(lib_nearest_garrison)
		end
	end

	Set_Land_AI_Targeting_Priorities(MainForce)
	
	-- move to contestables
	faction_name = PlayerObject.Get_Faction_Name()
	if PlayerObject.Get_Difficulty() == "Easy" then
		BlockOnCommand(MainForce.Attack_Move(AITarget))
	else	
		BlockOnCommand(MainForce.Attack_Move(AITarget, MainForce.Get_Self_Threat_Max()))
	end
		
	MainForce.Set_As_Goal_System_Removable(false)

	if TestValid(Target) then
        if (EvaluatePerception("Is_Build_Pad", PlayerObject, Target) == 1) then

			-- Build pads may have an existing enemy structure than needs to be removed
			-- Note that the enemy player can build structures late or rebuild destroyed structures, thus the need to repeat.
			structure = Target.Get_Build_Pad_Contents()
			if (structure == nil) or
				(TestValid(structure) and PlayerObject.Get_Faction_Name() ~= structure.Get_Owner().Get_Faction_Name()) then
								
				-- Attack any structure that might be there
				if TestValid(structure) then
					BlockOnCommand(MainForce.Attack_Target(structure))
				end

				--Wait for control to transition
				BlockOnCommand(MainForce.Guard_Target(AITarget), 60, Target_Has_Structure)
				
				--It's been a minute.  If we still don't have control then give up
				if Target.Get_Owner() ~= PlayerObject then
					ScriptExit()
				end

				-- Guard the spot to give another plan the chance to can something here
				-- Wait indefinately, if this is a refinery pad and we have no refineries.
				if (EvaluatePerception("Is_Refinery_Pad", PlayerObject, Target) == 1 or
					EvaluatePerception("Is_Outpost_Pad", PlayerObject, Target) == 1) then
					wait_for_build_time = -1
				end
				--MessageBox("%s, %s--Guarding for %d", tostring(Script), tostring(Target), wait_for_build_time)
				BlockOnCommand(MainForce.Guard_Target(AITarget), wait_for_build_time, Target_Has_Structure)				
			end

		else
		
			-- Stand guard so that we can retain usage of this structure
			MainForce.Guard_Target(AITarget)
			Sleep(10)
		end
	end

	MainForce.Set_Plan_Result(true)

	ScriptExit()
end

-- Does the plan's original Target have a friendlystructure on it?
function Target_Has_Structure()
	if TestValid(Target) then
		structure = Target.Get_Build_Pad_Contents()
        if TestValid(structure) then
			--MessageBox("%s, %s-- Target has structure, abandonning guard.", tostring(Script), tostring(Target))
			return true
		end
	end
	return false
end

-- Override default handling, which will kill the plan
function MainForce_Original_Target_Owner_Changed(tf, old_player, new_player)
end


function EscortForce_Thread()
	BlockOnCommand(EscortForce.Produce_Force())
	
	QuickReinforce(PlayerObject, AITarget, EscortForce, MainForce)

	Set_Land_AI_Targeting_Priorities(EscortForce)

	Try_Ability(EscortForce, "FORCE_CLOAK")
	-- Give an initial order to put the escorts in a state that the Escort function expects
	EscortForce.Guard_Target(MainForce)
	
	escort_unit_table = EscortForce.Get_Unit_Table()
	
	for i,escort in pairs(escort_unit_table) do
		if escort.Has_Garrison() then
			escort.Move_To(AITarget)
		end
	end

	EscortAlive = true
	while EscortAlive do
		Escort(EscortForce, MainForce)
	end
end

function EscortForce_No_Units_Remaining()
	EscortAlive = false
end

-- Override default handling, which will kill the plan
function EscortForce_Original_Target_Owner_Changed(tf, old_player, new_player)
end


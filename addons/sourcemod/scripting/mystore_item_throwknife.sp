/*
 * MyStore - Throw knife item module
 * by: shanapu
 * https://github.com/shanapu/
 * 
 * Copyright (C) 2018-2019 Thomas Schmidt (shanapu)
 * Credits: Bacardi - https://forums.alliedmods.net/showthread.php?t=269846
 * Contributer:
 *
 * Original development by Zephyrus - https://github.com/dvarnai/store-plugin
 *
 * Love goes out to the sourcemod team and all other plugin developers!
 * THANKS FOR MAKING FREE SOFTWARE!
 *
 * This file is part of the MyStore SourceMod Plugin.
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <http://www.gnu.org/licenses/>.
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

#include <colors> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/colors.inc
#include <mystore> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/mystore.inc


int g_iCount = 0;
int g_iRoundLimit[MAXPLAYERS + 1][STORE_MAX_ITEMS / 2];
bool g_bEquipt[MAXPLAYERS + 1] = false;
int g_iClientModel[MAXPLAYERS + 1];

Handle g_hTimerDelay[MAXPLAYERS+1];
Handle g_hThrownKnives;

int g_iLimit[STORE_MAX_ITEMS];

/*
 * Build date: <DATE>
 * Build number: <BUILD>
 * Commit: https://github.com/shanapu/MyStore/commit/<COMMIT>
 */

public Plugin myinfo = 
{
	name = "MyStore - Throw knife item module",
	author = "shanapu",
	description = "",
	version = "0.1.<BUILD>",
	url = "github.com/shanapu/MyStore"
};

public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");

	MyStore_RegisterHandler("throwknife", _, ThrowKnife_Reset, ThrowKnife_Config, ThrowKnife_Equip, ThrowKnife_Remove, true);

	HookEvent("player_spawn", Event_OnPlayerSpawn);
	HookEvent("weapon_fire", Event_WeaponFire);

	g_hThrownKnives = CreateArray();
}

public void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!client)
		return;

	for (int i = 0; i <= g_iCount; i++)
	{
		g_iRoundLimit[client][i] = 0;
	}
}

public void ThrowKnife_Reset()
{
	g_iCount = 0;
}

public bool ThrowKnife_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, g_iCount);
	g_iLimit[g_iCount] = kv.GetNum("limit", 0);

	g_iCount++;

	return true;
}

public int ThrowKnife_Equip(int client, int itemid)
{
	g_iClientModel[client] = MyStore_GetDataIndex(itemid);
	g_bEquipt[client] = true;

	return ITEM_EQUIP_SUCCESS;
}

public int ThrowKnife_Remove(int client, int itemid)
{
	g_bEquipt[client] = false;

	return ITEM_EQUIP_REMOVE;
}

public void OnClientDisconnect(int client)
{
	g_bEquipt[client] = false;
}

public void Event_WeaponFire(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!g_bEquipt[client])
		return;

	char weapon[20];
	event.GetString("weapon", weapon, sizeof(weapon));

	if (StrContains(weapon, "knife", false) == -1 && StrContains(weapon, "bayonet") == -1)
		return;

	g_hTimerDelay[client] = CreateTimer(0.0, Timer_CreateKnife, GetClientUserId(client));
}

// by bacardi https:// forums.alliedmods.net/showthread.php?t=269846
public Action Timer_CreateKnife(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);

	if (!IsValidClient(client, true, true))
		return Plugin_Handled;

	int iIndex = g_iClientModel[client];
	if (0 < g_iLimit[iIndex] <= g_iRoundLimit[client][iIndex])
		return Plugin_Handled;

	g_iRoundLimit[client][iIndex]++;

	g_hTimerDelay[client] = null;

	int slot_knife = GetPlayerWeaponSlot(client, CS_SLOT_KNIFE);
	int knife = CreateEntityByName("smokegrenade_projectile");

	if (knife != -1)
	{
		// owner
		SetEntPropEnt(knife, Prop_Send, "m_hOwnerEntity", client);
		SetEntPropEnt(knife, Prop_Send, "m_hThrower", client);
		SetEntProp(knife, Prop_Send, "m_iTeamNum", GetClientTeam(client));
	}

	if (!DispatchSpawn(knife))
		return Plugin_Handled;

	// player knife model
	char model[PLATFORM_MAX_PATH];
	if (slot_knife != -1)
	{
		GetEntPropString(slot_knife, Prop_Data, "m_ModelName", model, sizeof(model));
		if (ReplaceString(model, sizeof(model), "v_knife_", "w_knife_", true) != 1)
		{
			model[0] = '\0';
		}
		else if (ReplaceString(model, sizeof(model), ".mdl", "_dropped.mdl", true) != 1)
		{
			model[0] = '\0';
		}
	}

	// model and size
	SetEntProp(knife, Prop_Send, "m_nModelIndex", PrecacheModel(model));
	SetEntPropFloat(knife, Prop_Send, "m_flModelScale", 1.0);

	// knive elasticity
	SetEntPropFloat(knife, Prop_Send, "m_flElasticity", 0.2);
	// gravity
	SetEntPropFloat(knife, Prop_Data, "m_flGravity", 1.0);

	// Player origin and angle
	float origin[3], angle[3];
	GetClientEyePosition(client, origin);
	GetClientEyeAngles(client, angle);

	// knive new spawn position and angle is same as player's
	float pos[3];
	GetAngleVectors(angle, pos, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(pos, 50.0);
	AddVectors(pos, origin, pos);

	// knive flying direction and speed/power
	float player_velocity[3], velocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", player_velocity);
	GetAngleVectors(angle, velocity, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(velocity, 2250.0);
	AddVectors(velocity, player_velocity, velocity);

	// spin knive
	float spin[] = {4000.0, 0.0, 0.0};
	SetEntPropVector(knife, Prop_Data, "m_vecAngVelocity", spin);

	// Stop grenade detonate and Kill knive after 1 - 30 sec
	SetEntProp(knife, Prop_Data, "m_nNextThinkTick", -1);
	char sBuffer[25];
	Format(sBuffer, sizeof(sBuffer), "!self,Kill,,%0.1f,-1", 1.5);
	DispatchKeyValue(knife, "OnUser1", sBuffer);
	AcceptEntityInput(knife, "FireUser1");

	int color[4] = {255, ...};
	TE_SetupBeamFollow(knife, PrecacheModel("effects/blueblacklargebeam.vmt"), 0, 0.5, 1.0, 0.1, 0, color);

	TE_SendToAll();

	// Throw knive!
	TeleportEntity(knife, pos, angle, velocity);
	SDKHookEx(knife, SDKHook_Touch, KnifeHit);

	PushArrayCell(g_hThrownKnives, EntIndexToEntRef(knife));

	return Plugin_Handled;
}

// awesome code by bacardi https:// forums.alliedmods.net/showthread.php?t=269846
public Action KnifeHit(int knife, int other)
{
	if ((0 < other <= MaxClients) && GetClientTeam(other) != CS_TEAM_T) // Hits player index
	{
		int victim = other;

		SetVariantString("csblood");
		AcceptEntityInput(knife, "DispatchEffect");
		AcceptEntityInput(knife, "Kill");

		int attacker = GetEntPropEnt(knife, Prop_Send, "m_hThrower");
	//	int inflictor = GetPlayerWeaponSlot(attacker, CS_SLOT_KNIFE);
	
	//	if (inflictor == -1)
	//	{
		int inflictor = attacker; //test crash
	//	}

		float victimeye[3];
		GetClientEyePosition(victim, victimeye);

		float damagePosition[3];
		float damageForce[3];

		GetEntPropVector(knife, Prop_Data, "m_vecOrigin", damagePosition);
		GetEntPropVector(knife, Prop_Data, "m_vecVelocity", damageForce);

		if (GetVectorLength(damageForce) == 0.0) // knife movement stop
			return;

		// create damage
		SDKHooks_TakeDamage(victim, inflictor, attacker, 200.0, DMG_SLASH|DMG_NEVERGIB, knife, damageForce, damagePosition);

		// blood effect
		int color[] = {255, 0, 0, 255};
		float dir[3];

		TE_SetupBloodSprite(damagePosition, dir, color, 1, PrecacheDecal("sprites/blood.vmt"), PrecacheDecal("sprites/blood.vmt"));
		TE_SendToAll(0.0);

		// ragdoll effect
		int ragdoll = GetEntPropEnt(victim, Prop_Send, "m_hRagdoll");
		if (ragdoll != -1)
		{
			ScaleVector(damageForce, 50.0);
			damageForce[2] = FloatAbs(damageForce[2]); // push up!
			SetEntPropVector(ragdoll, Prop_Send, "m_vecForce", damageForce);
			SetEntPropVector(ragdoll, Prop_Send, "m_vecRagdollVelocity", damageForce);
		}
	}
	else if (FindValueInArray(g_hThrownKnives, EntIndexToEntRef(other)) != -1) // knives collide
	{
		SDKUnhook(knife, SDKHook_Touch, KnifeHit);
		float pos[3], dir[3];
		GetEntPropVector(knife, Prop_Data, "m_vecOrigin", pos);
		TE_SetupArmorRicochet(pos, dir);
		TE_SendToAll(0.0);

		DispatchKeyValue(knife, "OnUser1", "!self,Kill,,1.0,-1");
		AcceptEntityInput(knife, "FireUser1");
	}
}

public void OnEntityDestroyed(int entity)
{
	if (!IsValidEdict(entity)) return;

	int index = FindValueInArray(g_hThrownKnives, EntIndexToEntRef(entity));
	if (index != -1)
	{
		RemoveFromArray(g_hThrownKnives, index);
	}
}

bool IsValidClient(int client, bool bots = true, bool dead = true)
{
	if (client <= 0)
		return false;

	if (client > MaxClients)
		return false;

	if (!IsClientInGame(client))
		return false;

	if (IsFakeClient(client) && !bots)
		return false;

	if (IsClientSourceTV(client))
		return false;

	if (IsClientReplay(client))
		return false;

	if (!IsPlayerAlive(client) && !dead)
		return false;

	return true;
}
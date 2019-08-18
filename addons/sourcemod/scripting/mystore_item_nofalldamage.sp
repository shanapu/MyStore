/*
 * MyStore - No fall damage item module
 * by: shanapu
 * https://github.com/shanapu/
 * 
 * Copyright (C) 2018-2019 Thomas Schmidt (shanapu)
 * Credits: dordnung - https://forums.alliedmods.net/showthread.php?p=1338942
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

#include <mystore> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/mystore.inc

bool g_bEquipt[MAXPLAYERS + 1] = false;

ConVar gc_bEnable;

/*
 * Build date: <DATE>
 * Build number: <BUILD>
 * Commit: https://github.com/shanapu/MyStore/commit/<COMMIT>
 */

public Plugin myinfo = 
{
	name = "MyStore - No fall damage item module",
	author = "shanapu", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "",
	version = "0.1.<BUILD>", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = "github.com/shanapu/MyStore"
};

public void OnPluginStart()
{
	if (MyStore_RegisterHandler("nofalldamage", _, _, NoFallDamage_Config, NoFallDamage_Equip, NoFallDamage_Remove, true) == -1)
	{
		SetFailState("Can't Register module to core - Reached max module types(%i).", STORE_MAX_TYPES);
	}
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
}

public bool NoFallDamage_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, 0);

	return true;
}

public int NoFallDamage_Equip(int client, int itemid)
{
	g_bEquipt[client] = true;

	return ITEM_EQUIP_SUCCESS;
}

public int  NoFallDamage_Remove(int client, int itemid)
{
	g_bEquipt[client] = false;

	return ITEM_EQUIP_REMOVE;
}

public void OnClientPutInServer(int client)
{
	if (IsValidClient(client))
	{
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}

public void OnClientDisconnect(int client)
{
	if (IsValidClient(client))
	{
		SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	}

	g_bEquipt[client] = false;
}

public Action OnTakeDamage(int client, int &attacker, int &inflictor, float &damage, int &damagetype, int &bweapon, float damageForce[3], const float damagePosition[3])
{
	if (!gc_bEnable.BoolValue)
		return Plugin_Continue;

	if (!g_bEquipt[client])
		return Plugin_Continue;

	if (IsValidClient(client))
	{
		if ((GetClientTeam(client) == 2 || GetClientTeam(client) == 3) && IsPlayerAlive(client))
		{
			if (damagetype & DMG_FALL)
				return Plugin_Handled;
		}
	}

	return Plugin_Continue;
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
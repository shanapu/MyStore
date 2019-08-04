/*
 * MyStore - Godmode item module
 * by: shanapu
 * https://github.com/shanapu/
 * 
 * Copyright (C) 2018-2019 Thomas Schmidt (shanapu)
 * Credits:
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

#include <colors> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/colors.inc
#include <mystore> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/mystore.inc

char g_sChatPrefix[128];

float g_fDuration[STORE_MAX_ITEMS];

int g_iRoundLimit[MAXPLAYERS + 1][STORE_MAX_ITEMS / 2];
int g_iLimit[STORE_MAX_ITEMS];
int g_iTeam[STORE_MAX_ITEMS];
int g_iCount = 0;

/*
 * Build date: <DATE>
 * Build number: <BUILD>
 * Commit: https://github.com/shanapu/MyStore/commit/<COMMIT>
 */

public Plugin myinfo = 
{
	name = "MyStore - Godmode item module",
	author = "shanapu",
	description = "",
	version = "0.1.<BUILD>",
	url = "github.com/shanapu/MyStore"
};

public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");

	MyStore_RegisterHandler("godmode", _, Godmode_Reset, Godmode_Config, Godmode_Equip, _, false);

	HookEvent("player_spawn", Event_OnPlayerSpawn);
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
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

public void Godmode_Reset()
{
	g_iCount = 0;
}

public bool Godmode_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, g_iCount);

	g_fDuration[g_iCount] = kv.GetFloat("duration");
	g_iLimit[g_iCount] = kv.GetNum("limit");
	g_iTeam[g_iCount] = kv.GetNum("team", 0);

	g_iCount++;

	return true;
}

public int Godmode_Equip(int client, int itemid)
{
	int iIndex = MyStore_GetDataIndex(itemid);

	if (0 < g_iLimit[iIndex] <= g_iRoundLimit[client][iIndex])
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Round Limit");
		return ITEM_EQUIP_FAIL;
	}

	if (0 < g_iTeam[g_iCount] && g_iTeam[g_iCount] != GetClientTeam(client) - 1)
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Wrong Team");
		return ITEM_EQUIP_FAIL;
	}

	if (!IsPlayerAlive(client))
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Must be Alive");
		return ITEM_EQUIP_FAIL;
	}

	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	CreateTimer(g_fDuration[iIndex], Timer_RemoveGodmode, GetClientUserId(client));

	g_iRoundLimit[client][iIndex]++;

	return ITEM_EQUIP_REMOVE;
}

public Action Timer_RemoveGodmode(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!client)
		return Plugin_Stop;

	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);

	return Plugin_Stop;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	damage = 0.0;

	return Plugin_Changed;
}
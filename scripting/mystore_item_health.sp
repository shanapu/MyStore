/*
 * MyStore - Health item module
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

#include <colors> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/colors.inc
#include <mystore> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/mystore.inc

char g_sChatPrefix[128];

int g_iHealths[STORE_MAX_ITEMS];
int g_iMaxHealths[STORE_MAX_ITEMS];
int g_iLimit[STORE_MAX_ITEMS];
int g_iCount = 0;
int g_iRoundLimit[MAXPLAYERS + 1][STORE_MAX_ITEMS / 2];

public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");

	MyStore_RegisterHandler("health", _, Health_Reset, Health_Config, Health_Equip, _, false);

	HookEvent("player_spawn", Events_OnPlayerSpawn);
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

public void Events_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!client)
		return;

	for (int i = 0; i <= g_iCount; i++)
	{
		g_iRoundLimit[client][i] = 0;
	}
}

public void Health_Reset()
{
	g_iCount = 0;
}

public bool Health_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, g_iCount);

	g_iHealths[g_iCount] = kv.GetNum("health");
	g_iMaxHealths[g_iCount] = kv.GetNum("max_health", 0);
	g_iLimit[g_iCount] = kv.GetNum("limit", 0);

	g_iCount++;

	return true;
}

public int Health_Equip(int client, int itemid)
{
	int iIndex = MyStore_GetDataIndex(itemid);

	if (0 < g_iLimit[iIndex] <= g_iRoundLimit[client][iIndex])
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Round Limit");
		return ITEM_EQUIP_FAIL;
	}

	if (!IsPlayerAlive(client))
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Must be Alive");
		return ITEM_EQUIP_FAIL;
	}

	int iHealth = GetClientHealth(client) + g_iHealths[iIndex];

	if (g_iMaxHealths[iIndex] != 0 && iHealth > g_iMaxHealths[iIndex])
	{
		iHealth = g_iMaxHealths[iIndex];
	}

	SetEntityHealth(client, iHealth);

	g_iRoundLimit[client][iIndex]++;

	return ITEM_EQUIP_SUCCESS;
}
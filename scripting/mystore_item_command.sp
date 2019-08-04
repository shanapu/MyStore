/*
 * MyStore - Command item module
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

#include <mystore> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/mystore.inc

#include <colors> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/colors.inc

char g_sChatPrefix[128];

int g_iCount = 0;
int g_iRoundLimit[MAXPLAYERS + 1][STORE_MAX_ITEMS / 2];
int g_iSpam[MAXPLAYERS + 1] = {0, ...};

char g_sCommand[STORE_MAX_ITEMS][64];
char g_sCommandOff[STORE_MAX_ITEMS][64];
int g_iTimeOff[STORE_MAX_ITEMS];
int g_iCooldown[STORE_MAX_ITEMS];
int g_iLimit[STORE_MAX_ITEMS];

/*
 * Build date: <DATE>
 * Build number: <BUILD>
 * Commit: https://github.com/shanapu/MyStore/commit/<COMMIT>
 */

public Plugin myinfo = 
{
	name = "MyStore - Command item module",
	author = "shanapu",
	description = "",
	version = "0.1.<BUILD>",
	url = "github.com/shanapu/MyStore"
};

public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");

	MyStore_RegisterHandler("command", _, Commands_Reset, Commands_Config, Commands_Equip, _, false);

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

public void Commands_Reset()
{
	g_iCount = 0;
}

public bool Commands_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, g_iCount);

	kv.GetString("command", g_sCommand[g_iCount], 64);
	kv.GetString("command_off", g_sCommandOff[g_iCount], 64);
	g_iTimeOff[g_iCount] = kv.GetNum("time", -1);
	g_iLimit[g_iCount] = kv.GetNum("limit", 0);
	g_iCooldown[g_iCount] = kv.GetNum("cooldown", 10);

	g_iCount++;

	return true;
}

public int Commands_Equip(int client, int itemid)
{
	int iIndex = MyStore_GetDataIndex(itemid);

	if (0 < g_iLimit[iIndex] >= g_iRoundLimit[client][iIndex])
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Round Limit");
		return ITEM_EQUIP_FAIL;
	}

	if (0 < g_iCooldown[iIndex] && g_iSpam[client] > GetTime())
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Spam Cooldown", g_iSpam[client] - GetTime());
		return ITEM_EQUIP_FAIL;
	}

	char sCommand[256];
	strcopy(sCommand, sizeof(sCommand), g_sCommand[iIndex]);

	char sClientID[11];
	char sUserID[11];
	char sSteamID[32];
	char sName[66];

	IntToString(client, sClientID, sizeof(sClientID));
	IntToString(GetClientUserId(client), sUserID, sizeof(sUserID));
	GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));
	GetClientName(client, sName, sizeof(sName));


	ReplaceString(sCommand, sizeof(sCommand), "{clientid}", sClientID);
	ReplaceString(sCommand, sizeof(sCommand), "{userid}", sUserID);
	ReplaceString(sCommand, sizeof(sCommand), "{steamid}", sSteamID);
	ReplaceString(sCommand, sizeof(sCommand), "{name}", sName);

	ServerCommand("%s", sCommand);

	if (g_iTimeOff[iIndex] != -1) ///??
	{
		DataPack pack = new DataPack();
		pack.WriteCell(GetClientUserId(client));
		pack.WriteCell(iIndex);
		pack.Reset();

		CreateTimer(g_iTimeOff[iIndex] * 1.0, Timer_CommandOff, pack);
	}

	g_iSpam[client] = GetTime() + g_iCooldown[iIndex];
	g_iRoundLimit[client][iIndex]++;

	return ITEM_EQUIP_REMOVE;
}

public Action Timer_CommandOff(Handle timer, DataPack pack)
{
	int client = GetClientOfUserId(pack.ReadCell());
	int iIndex = pack.ReadCell();
	delete pack;

	char sCommand[256];
	strcopy(sCommand, sizeof(sCommand), g_sCommandOff[iIndex]);

	char sClientID[11];
	char sUserID[11];
	char sSteamID[32];
	char sName[66];

	if (client)
	{
		IntToString(client, sClientID, sizeof(sClientID));
		IntToString(GetClientUserId(client), sUserID, sizeof(sUserID));
		GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));
		GetClientName(client, sName, sizeof(sName));
	}

	ReplaceString(sCommand, sizeof(sCommand), "{clientid}", sClientID);
	ReplaceString(sCommand, sizeof(sCommand), "{userid}", sUserID);
	ReplaceString(sCommand, sizeof(sCommand), "{steamid}", sSteamID);
	ReplaceString(sCommand, sizeof(sCommand), "{name}", sName);

	ServerCommand("%s", sCommand);

	return Plugin_Stop;
}
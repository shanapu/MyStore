/*
 * MyStore - Spawn extra item module
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

#include <sourcemod>
#include <sdktools>

#include <mystore> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/mystore.inc

#include <colors> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/colors.inc

int g_iHealth[STORE_MAX_ITEMS];
int g_iArmor[STORE_MAX_ITEMS];
float g_iGravity[STORE_MAX_ITEMS];
float g_iSpeed[STORE_MAX_ITEMS];
int g_iMoney[STORE_MAX_ITEMS];
char g_sItems[STORE_MAX_ITEMS][128];
char g_sCommand[STORE_MAX_ITEMS][128];

char g_sChatPrefix[128];

ConVar gc_bEnable;

bool g_bEquipt[MAXPLAYERS + 1] = false;

int g_iCount = 0;

public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");

	MyStore_RegisterHandler("spawn", _, Spawn_Reset, Spawn_Config, Spawn_Equip, Spawn_Remove, true);

	HookEvent("player_spawn", Event_PlayerSpawn);
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

public void Spawn_Reset()
{
	g_iCount = 0;
}

public bool Spawn_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, g_iCount);

	g_iHealth[g_iCount] = kv.GetNum("health", -1);
	g_iArmor[g_iCount] = kv.GetNum("armor", -1);
	g_iGravity[g_iCount] = kv.GetFloat("gravity", -1.0);
	g_iSpeed[g_iCount] = kv.GetFloat("speed", -1.0);
	g_iMoney[g_iCount] = kv.GetNum("money", -1);
	kv.GetString("command", g_sCommand[g_iCount], 128);
	kv.GetString("items", g_sItems[g_iCount], 128);
	ReplaceString(g_sItems[g_iCount], sizeof(g_sItems[]), " ", "");

	g_iCount++;

	return true;
}

public int Spawn_Equip(int client, int itemid)
{
	g_bEquipt[client] = true;
	any item[Item_Data];
	MyStore_GetItem(itemid, item);

	CPrintToChat(client, "%s%t", g_sChatPrefix, "Recieve Spawn", item[szName]);

//	GivePlayerExtras(client);

	return ITEM_EQUIP_SUCCESS;
}

public int Spawn_Remove(int client, int itemid)
{
	g_bEquipt[client] = false;

	return ITEM_EQUIP_REMOVE;
}

public void OnClientDisconnect(int client)
{
	g_bEquipt[client] = false;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!gc_bEnable.BoolValue)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!g_bEquipt[client])
		return;

	if (!client || !IsPlayerAlive(client))
		return;

	GivePlayerExtras(client);
}

void GivePlayerExtras(client)
{
	int iIndex = MyStore_GetDataIndex(MyStore_GetEquippedItem(client, "spawn", 0));

	if (g_iHealth[iIndex] != -1)
	{
		SetEntityHealth(client, GetClientHealth(client) + g_iHealth[iIndex]);
	}

	if (g_iArmor[iIndex] != -1)
	{
		SetEntProp(client, Prop_Send, "m_ArmorValue", GetEntProp(client, Prop_Send, "m_ArmorValue") + g_iArmor[iIndex]);
	}

	if (g_iGravity[iIndex] != -1.0)
	{
		SetEntityGravity(client, g_iGravity[iIndex]);
	}

	if (g_iSpeed[iIndex] != -1.0)
	{
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_iSpeed[iIndex]);
	}

	if (g_iMoney[iIndex] != -1)
	{
		SetEntProp(client, Prop_Send, "m_iAccount", GetEntProp(client, Prop_Send, "m_iAccount") + g_iMoney[iIndex]);
	}

	if (g_sItems[iIndex][0])
	{
		int iCount = 0;
		char siItem[12][32];
		iCount = ExplodeString(g_sItems[iIndex], ",", siItem, sizeof(siItem), sizeof(siItem[]));

		for (int i = 0; i < iCount; i++)
		{
			GivePlayerItem(client, siItem[i]);
		}
	}

	if (g_sCommand[iIndex][0])
	{
		char sCommand[256];
		strcopy(sCommand, sizeof(sCommand), g_sCommand[iIndex]);

		char sClientID[11];
		char sUserID[11];
		char sSteamID[32] = "\"";
		char sName[66] = "\"";

		IntToString(client, sClientID, sizeof(sClientID));
		IntToString(GetClientUserId(client), sUserID, sizeof(sUserID));
		GetClientAuthId(client, AuthId_Steam2, sSteamID[1], sizeof(sSteamID)-1);
		GetClientName(client, sName[1], sizeof(sName)-1);

		sSteamID[strlen(sSteamID)] = '"';
		sName[strlen(sName)] = '"';

		ReplaceString(sCommand, sizeof(sCommand), "{clientid}", sClientID);
		ReplaceString(sCommand, sizeof(sCommand), "{userid}", sUserID);
		ReplaceString(sCommand, sizeof(sCommand), "{steamid}", sSteamID);
		ReplaceString(sCommand, sizeof(sCommand), "{name}", sName);

		ServerCommand("%s", sCommand);
	}
}
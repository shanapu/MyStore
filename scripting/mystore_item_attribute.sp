/*
 * MyStore - Attribute item module
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

ConVar gc_bEnable;

bool g_bUsed[MAXPLAYERS + 1];

public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("round_end", Event_RoundEnd);
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
}

public void Event_RoundEnd(Event event, char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_bUsed[i] = false;
	}
}

public void MyStore_OnItemEquipt(int client, int itemid)
{
	if (!client || !IsClientInGame(client) || !IsPlayerAlive(client))
		return;

	any item[Item_Data];
	char sValue[32];

	MyStore_GetItem(itemid, item);

	if (item[hAttributes] == null || g_bUsed[client])
		return;

	g_bUsed[client] = true;

	if (item[hAttributes].GetString("health", sValue, sizeof(sValue)))
	{
		SetEntityHealth(client, GetClientHealth(client) + StringToInt(sValue));
	}

	if (item[hAttributes].GetString("gravity", sValue, sizeof(sValue)))
	{
		SetEntityGravity(client, StringToFloat(sValue));
	}

	if (item[hAttributes].GetString("money", sValue, sizeof(sValue)))
	{
		SetEntProp(client, Prop_Send, "m_iAccount", GetEntProp(client, Prop_Send, "m_iAccount") + StringToInt(sValue));
	}

	if (item[hAttributes].GetString("armor", sValue, sizeof(sValue)))
	{
		SetEntProp(client, Prop_Send, "m_ArmorValue", GetEntProp(client, Prop_Send, "m_ArmorValue") + StringToInt(sValue));
	}

	if (item[hAttributes].GetString("speed", sValue, sizeof(sValue)))
	{
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", StringToFloat(sValue));
	}

	if (item[hAttributes].GetString("items", sValue, sizeof(sValue)))
	{
		if (sValue[0])
		{
			int iCount = 0;
			char siItem[12][32];
			iCount = ExplodeString(sValue, ",", siItem, sizeof(siItem), sizeof(siItem[]));

			for (int i = 0; i < iCount; i++)
			{
				GivePlayerItem(client, siItem[i]);
			}
		}
	}

	if (item[hAttributes].GetString("command", sValue, sizeof(sValue)))
	{
		if (!sValue[0])
			return;

		char sCommand[256];
		strcopy(sCommand, sizeof(sCommand), sValue);

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

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!gc_bEnable.BoolValue)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!client || !IsClientInGame(client) || !IsPlayerAlive(client))
		return;

	// Reset client
	SetEntityGravity(client, 1.0);

	int idx = -1;
	int item_idx = -1;
	any item[Item_Data];
	char sValue[32];

	while ((item_idx = MyStore_IterateEquippedItems(client, idx, true)) != -1)
	{
		MyStore_GetItem(item_idx, item);

		if (item[hAttributes] == null || g_bUsed[client])
			return;

		g_bUsed[client] = true;

		if (item[hAttributes].GetString("health", sValue, sizeof(sValue)))
		{
			SetEntityHealth(client, GetClientHealth(client) + StringToInt(sValue));
		}

		if (item[hAttributes].GetString("money", sValue, sizeof(sValue)))
		{
			SetEntProp(client, Prop_Send, "m_iAccount", GetEntProp(client, Prop_Send, "m_iAccount") + StringToInt(sValue));
		}

		if (item[hAttributes].GetString("gravity", sValue, sizeof(sValue)))
		{
			SetEntityGravity(client, StringToFloat(sValue));
		}

		if (item[hAttributes].GetString("armor", sValue, sizeof(sValue)))
		{
			SetEntProp(client, Prop_Send, "m_ArmorValue", GetEntProp(client, Prop_Send, "m_ArmorValue") + StringToInt(sValue));
		}

		if (item[hAttributes].GetString("speed", sValue, sizeof(sValue)))
		{
			SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", StringToFloat(sValue));
		}

		if (item[hAttributes].GetString("items", sValue, sizeof(sValue)))
		{
			if (sValue[0])
			{
				int iCount = 0;
				char siItem[12][32];
				iCount = ExplodeString(sValue, ",", siItem, sizeof(siItem), sizeof(siItem[]));

				for (int i = 0; i < iCount; i++)
				{
					GivePlayerItem(client, siItem[i]);
				}
			}
		}

		if (item[hAttributes].GetString("command", sValue, sizeof(sValue)))
		{
			if (!sValue[0])
				return;

			char sCommand[256];
			strcopy(sCommand, sizeof(sCommand), sValue);

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
}
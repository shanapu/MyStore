/*
 * MyStore - Default-item module
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
#include <sdkhooks>

#include <mystore> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/mystore.inc

#include <colors> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/colors.inc
#include <autoexecconfig> //https://raw.githubusercontent.com/Impact123/AutoExecConfig/development/autoexecconfig.inc

#define MAX_DEFAULT 6

int g_iFlagBits[MAX_DEFAULT];
int g_bForce[MAX_DEFAULT][STORE_MAX_ITEMS];
int g_bUnEquip[MAX_DEFAULT][STORE_MAX_ITEMS];
int g_iCount;

char g_sItem[MAX_DEFAULT][STORE_MAX_ITEMS][32];
int g_iItemCount[MAX_DEFAULT];

int g_iActive[MAXPLAYERS + 1];
bool g_bRetry[MAXPLAYERS + 1];

ConVar gc_bEnable;

public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");

	LoadConfig();
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
}

public void OnClientPutInServer(int client)
{
	if (IsFakeClient(client) || !gc_bEnable.BoolValue)
		return;

	g_bRetry[client] = false;
	g_iActive[client] = -1;

	for (int i = 0; i < g_iCount; i++)
	{
		if (!CheckFlagBits(client, g_iFlagBits[i]))
			continue;

		g_iActive[client] = i;
	}

	if (g_iActive[client] == -1)
		return;

	CreateTimer(2.5, Timer_OnClientPutInServer, GetClientUserId(client));
}

public Action Timer_OnClientPutInServer(Handle tmr, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!client)
		return Plugin_Handled;

	if (!MyStore_IsClientLoaded(client) && !g_bRetry[client])
	{
		g_bRetry[client] = true;
		CreateTimer(2.5, Timer_OnClientPutInServer, GetClientUserId(client)); //no endless pleas todo

		return Plugin_Handled;
	}

	for (int j = 0; j < g_iItemCount[g_iActive[client]]; j++)
	{
		int itemid = MyStore_GetItemIdbyUniqueId(g_sItem[g_iActive[client]][j]);
		if (itemid == -1)
			continue;

		if (g_bUnEquip[g_iActive[client]][j] && MyStore_HasClientItem(client, itemid))
		{
			MyStore_UnequipItem(client, itemid);
			continue;
		}

		if (!MyStore_HasClientItem(client, itemid)) //lootbox
		{
			MyStore_GiveItem(client, itemid, 0, 0, 0);
			MyStore_EquipItem(client, itemid);
		}
		else if (g_bForce[g_iActive[client]][j])
		{
			MyStore_EquipItem(client, itemid);
		}
	}

	return Plugin_Handled;
}

void LoadConfig()
{
	char sFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFile, sizeof(sFile), "configs/MyStore/defaultItems.txt");
	KeyValues kv = new KeyValues("Default");
	kv.ImportFromFile(sFile);
	if (!kv.GotoFirstSubKey())
	{
		SetFailState("Failed to read configs/MyStore/defaultItems.txt");
	}

	GoThroughConfig(kv);
	delete kv;
}

void GoThroughConfig(KeyValues &kv)
{
	char sBuffer[64];

	g_iCount = 0;

	do
	{
		// We reached the max amount of items so break and don't add any more items
		if (g_iCount == MAX_DEFAULT)
			break;

		kv.GetString("flags", sBuffer, sizeof(sBuffer), "");
		g_iFlagBits[g_iCount] = ReadFlagString(sBuffer);

		if (kv.JumpToKey("Items"))
		{
			kv.GotoFirstSubKey(false);
			do
			{
				g_bForce[g_iCount][g_iItemCount[g_iCount]] = false;
				kv.GetSectionName(sBuffer, sizeof(sBuffer));
				if (StrEqual(sBuffer, "force"))
				{
					g_bForce[g_iCount][g_iItemCount[g_iCount]] = true;
				}
				else if (StrEqual(sBuffer, "unequip"))
				{
					g_bUnEquip[g_iCount][g_iItemCount[g_iCount]] = true;
				}
				kv.GetString(NULL_STRING, g_sItem[g_iCount][g_iItemCount[g_iCount]], 64);
				g_iItemCount[g_iCount]++;
			}
			while kv.GotoNextKey(false);

			kv.GoBack();
			kv.GoBack();
		}

		g_iCount++;
	}
	while kv.GotoNextKey();
}

bool CheckFlagBits(int client, int flagsNeed, int flags = -1)
{
	if (flags==-1)
	{
		flags = GetUserFlagBits(client);
	}

	if (flagsNeed == 0 || flags & flagsNeed || flags & ADMFLAG_ROOT)
	{
		return true;
	}

	return false;
}
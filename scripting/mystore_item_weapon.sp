/*
 * MyStore - Weapon item module
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

#include <mystore> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/mystore.inc

#include <colors> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/colors.inc
#include <autoexecconfig> //https://raw.githubusercontent.com/Impact123/AutoExecConfig/development/autoexecconfig.inc

char g_sChatPrefix[128];
char g_sCreditsName[64];

ConVar gc_bEnable;

ConVar gc_iMaxWeapons;

char g_sWeapon[STORE_MAX_ITEMS / 2][32];
char g_sTrigger[STORE_MAX_ITEMS / 2][64];
int g_iPrice[STORE_MAX_ITEMS / 2];
int g_iCooldown[STORE_MAX_ITEMS / 2];
int g_iLimit[STORE_MAX_ITEMS / 2];
int g_iItemId[STORE_MAX_ITEMS / 2];
int g_iFlagBits[STORE_MAX_ITEMS / 2];

int g_iCount = 0;
int g_iAllLimit[MAXPLAYERS + 1];
int g_iRoundLimit[STORE_MAX_ITEMS / 2][MAXPLAYERS + 1];
int g_iSpam[MAXPLAYERS + 1] = {0,...};

Handle g_hTimerPreview[MAXPLAYERS + 1];
int g_iPreviewEntity[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");

	AutoExecConfig_SetFile("items", "sourcemod/MyStore");
	AutoExecConfig_SetCreateFile(true);

	gc_iMaxWeapons = AutoExecConfig_CreateConVar("mystore_weapons_max", "3", "how many weapons AT ALL can you buy in a round. To catch the roundlimit from all weapons buyed. 0 - only limited by items.txt", _, true, 0.0);

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	HookEvent("player_spawn", Events_OnPlayerSpawn);
	HookEvent("player_say", Event_PlayerSay);

	MyStore_RegisterHandler("weapon", _, Weapons_Reset, Weapons_Config, Weapons_Equip, _, false);
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
	strcopy(g_sCreditsName, sizeof(g_sCreditsName), credits);
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

	g_iAllLimit[client] = 0;
}

public int Weapons_Reset()
{
	g_iCount = 0;
}

public bool Weapons_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, g_iCount);
	kv.GetString("weapon", g_sWeapon[g_iCount], 32);
	g_iLimit[g_iCount] = kv.GetNum("limit", 0);
	g_iCooldown[g_iCount] = kv.GetNum("cooldown", 10);
	kv.GetString("trigger", g_sTrigger[g_iCount], 64);
	g_iPrice[g_iCount] = kv.GetNum("price");

	char sBuffer[16];
	kv.GetString("flag", sBuffer, sizeof(sBuffer));
	g_iFlagBits[g_iCount] = ReadFlagString(sBuffer);

	g_iCount++;

	return true;
}

public int Weapons_Equip(int client, int itemid)
{
	int iIndex = MyStore_GetDataIndex(itemid);

	if (0 < g_iLimit[iIndex] <= g_iRoundLimit[iIndex][client] || g_iAllLimit[client] >= gc_iMaxWeapons.IntValue && gc_iMaxWeapons.IntValue != 0)
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Round Limit");
		return ITEM_EQUIP_FAIL;
	}

	if (0 < g_iCooldown[iIndex] && g_iSpam[client] > GetTime())
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Spam Cooldown", g_iSpam[client] - GetTime());
		return ITEM_EQUIP_FAIL;
	}

	if (!IsPlayerAlive(client))
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Must be Alive");
		return ITEM_EQUIP_FAIL;
	}

	GivePlayerItem(client, g_sWeapon[iIndex]);

	g_iRoundLimit[iIndex][client]++;
	g_iAllLimit[client]++;
	g_iSpam[client] = GetTime() + g_iCooldown[iIndex];

	return ITEM_EQUIP_SUCCESS;
}

public void Event_PlayerSay(Event event, char[] name, bool dontBroadcast)
{
	if (!gc_bEnable.BoolValue)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client)
		return;

	char sBuffer[32];
	GetEventString(event, "text", sBuffer, sizeof(sBuffer));

	for (int i = 0; i < g_iCount; i++)
	{
		if (strcmp(sBuffer, g_sTrigger[i]) == 0)
		{
			if (!CheckFlagBits(client, g_iFlagBits[i]) || !MyStore_HasClientAccess(client))
				return;

			if (0 < g_iLimit[i] <= g_iRoundLimit[i][client] || g_iAllLimit[client] >= gc_iMaxWeapons.IntValue && gc_iMaxWeapons.IntValue != 0)
			{
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Round Limit");
				return;
			}

			if (g_iSpam[client] > GetTime())
			{
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Spam Cooldown", g_iSpam[client] - GetTime());
				return;
			}

			int credits = MyStore_GetClientCredits(client);
			bool has = MyStore_HasClientItem(client, g_iItemId[i]);
			bool haspackage = MyStore_IsItemInBoughtPackage(client, g_iItemId[i]);
			if (credits >= g_iPrice[i] || has || haspackage) // check prive parten for package? todo
			{
				GivePlayerItem(client, g_sWeapon[i]);

				if (has || !haspackage)
				{
					MyStore_RemoveItem(client, g_iItemId[i]);
				}
				else if (!haspackage)
				{
					MyStore_SetClientCredits(client, credits - g_iPrice[i], "Weapon Trigger");
				}

				g_iSpam[client] = GetTime() + g_iCooldown[i];
			}
			else
			{
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Credit Not Enough", g_sCreditsName);
			}

			break;
		}
	}
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

public void OnClientDisconnect(int client)
{
	if (g_hTimerPreview[client] != null)
	{
		TriggerTimer(g_hTimerPreview[client], false);
	}
}
///todo ? done?! test!
public void MyStore_OnPreviewItem(int client, char[] type, int index)
{
	if (g_hTimerPreview[client] != null)
	{
		TriggerTimer(g_hTimerPreview[client], false);
	}

	if (!StrEqual(type, "weapon"))
		return;

	int iPreview = CreateEntityByName(g_sWeapon[index]); //prop_dynamic_override
	DispatchSpawn(iPreview);
	AcceptEntityInput(iPreview, "Enable");

	float fOrigin[3], fAngles[3], fRad[2], fPosition[3];

	GetClientAbsOrigin(client, fOrigin);
	GetClientAbsAngles(client, fAngles);

	fRad[0] = DegToRad(fAngles[0]);
	fRad[1] = DegToRad(fAngles[1]);

	fPosition[0] = fOrigin[0] + 64 * Cosine(fRad[0]) * Cosine(fRad[1]);
	fPosition[1] = fOrigin[1] + 64 * Cosine(fRad[0]) * Sine(fRad[1]);
	fPosition[2] = fOrigin[2] + 4 * Sine(fRad[0]);

	fAngles[0] *= -1.0;
	fAngles[1] *= -1.0;

	fPosition[2] += 55;

	TeleportEntity(iPreview, fPosition, fAngles, NULL_VECTOR);
	SDKHook(iPreview, SDKHook_ShouldCollide, Hook_ShouldCollide);

	g_iPreviewEntity[client] = EntIndexToEntRef(iPreview);

	int iRotator = CreateEntityByName("func_rotating");
	DispatchKeyValueVector(iRotator, "origin", fPosition);

	DispatchKeyValue(iRotator, "maxspeed", "20");
	DispatchKeyValue(iRotator, "spawnflags", "64");
	DispatchSpawn(iRotator);

	SetVariantString("!activator");
	AcceptEntityInput(iPreview, "SetParent", iRotator, iRotator);
	AcceptEntityInput(iRotator, "Start");

	SDKHook(iPreview, SDKHook_SetTransmit, Hook_SetTransmit_Preview);

	g_hTimerPreview[client] = CreateTimer(8.0, Timer_KillPreview, client);

	CPrintToChat(client, "%s%t", g_sChatPrefix, "Spawn Preview", client);
}

public bool Hook_ShouldCollide(int entity, int collisiongroup, int contentsmask, bool result)
{
	return false;
}

public Action Hook_SetTransmit_Preview(int ent, int client)
{
	if (g_iPreviewEntity[client] == INVALID_ENT_REFERENCE)
		return Plugin_Handled;

	if (ent == EntRefToEntIndex(g_iPreviewEntity[client]))
		return Plugin_Continue;

	return Plugin_Handled;
}

public Action Timer_KillPreview(Handle timer, int client)
{
	g_hTimerPreview[client] = null;

	if (g_iPreviewEntity[client] != INVALID_ENT_REFERENCE)
	{
		int entity = EntRefToEntIndex(g_iPreviewEntity[client]);

		if (IsValidEdict(entity))
		{
			SDKUnhook(entity, SDKHook_SetTransmit, Hook_SetTransmit_Preview);
			SDKUnhook(entity, SDKHook_ShouldCollide, Hook_ShouldCollide);
			AcceptEntityInput(entity, "Kill");
		}
	}
	g_iPreviewEntity[client] = INVALID_ENT_REFERENCE;

	return Plugin_Stop;
}
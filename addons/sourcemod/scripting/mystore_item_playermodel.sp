/*
 * MyStore - Player model item module
 * by: shanapu
 * https://github.com/shanapu/
 * 
 * Copyright (C) 2018-2019 Thomas Schmidt (shanapu)
 * Credits: Kxnrl - https://github.com/Kxnrl/Store
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
#include <cstrike>

#include <mystore> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/mystore.inc

#include <colors> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/colors.inc
#include <smartdm> //https://forums.alliedmods.net/attachment.php?attachmentid=136152&d=1406298576
#include <autoexecconfig> //https://raw.githubusercontent.com/Impact123/AutoExecConfig/development/autoexecconfig.inc

#pragma semicolon 1
#pragma newdecls required

char g_sModel[STORE_MAX_ITEMS][PLATFORM_MAX_PATH];
char g_sArms[STORE_MAX_ITEMS][PLATFORM_MAX_PATH];
int g_iTeam[STORE_MAX_ITEMS];

char g_sChatPrefix[128];

ConVar gc_bChangeInstant;
ConVar gc_fDelay;

ConVar gc_bEnable;

int g_iCount = 0;

int g_iModel[MAXPLAYERS + 1] = {-1, ...};
Handle g_hTimerPreview[MAXPLAYERS + 1];
int g_iPreviewEntity[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

/*
 * Build date: <DATE>
 * Build number: <BUILD>
 * Commit: https://github.com/shanapu/MyStore/commit/<COMMIT>
 */

public Plugin myinfo = 
{
	name = "MyStore - Player model item module",
	author = "shanapu",
	description = "",
	version = "0.1.<BUILD>",
	url = "github.com/shanapu/MyStore"
};

public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");

	AutoExecConfig_SetFile("items", "sourcemod/MyStore");
	AutoExecConfig_SetCreateFile(true);

	MyStore_RegisterHandler("playermodel", PlayerModels_OnMapStart, PlayerModels_Reset, PlayerModels_Config, PlayerModels_Equip, PlayerModels_Remove, true);

	gc_bChangeInstant = AutoExecConfig_CreateConVar("mystore_playermodel_instant", "1", "Defines whether the skin should be changed instantly or on next spawn.", _, true, 0.0, true, 1.0);
	gc_fDelay = AutoExecConfig_CreateConVar("mystore_playermodel_delay", "0.5", "Delay after spawn before applying the skin. -1 means no delay", _, true, -1.0, true, 1.0);

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	HookEvent("player_spawn", Event_PlayerSpawn);
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
	gc_bEnable.AddChangeHook(OnSettingChanged);
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

public void OnSettingChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == gc_bEnable)
	{
		if (StringToInt(newValue) == 1) // enable
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (!IsClientInGame(i) || IsFakeClient(i))
					continue;

				CS_UpdateClientModel(i);
			}
		}
		else // disable
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (!IsClientInGame(i) || IsFakeClient(i))
					continue;

				if (GetClientTeam(i) != g_iTeam[MyStore_GetDataIndex(g_iModel[i])] || g_iModel[i] == -1)
					continue;

				PlayerModels_Equip(i, g_iModel[i]);
			}
		}
	}
}

public void PlayerModels_OnMapStart()
{
	for (int i = 0; i < g_iCount; i++)
	{
		PrecacheModel(g_sModel[i], true);
		Downloader_AddFileToDownloadsTable(g_sModel[i]);

		if (g_sArms[i][0] != 0)
		{
			PrecacheModel(g_sArms[i], true);
			Downloader_AddFileToDownloadsTable(g_sArms[i]);
		}
	}
}

public void PlayerModels_Reset()
{
	g_iCount = 0;
}

public bool PlayerModels_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, g_iCount);

	kv.GetString("model", g_sModel[g_iCount], PLATFORM_MAX_PATH);

	if (!FileExists(g_sModel[g_iCount], true))
	{
		MyStore_LogMessage(0, LOG_ERROR, "Can't find model %s.", g_sModel[g_iCount]);
		return false;
	}

	kv.GetString("arms", g_sArms[g_iCount], PLATFORM_MAX_PATH);
	g_iTeam[g_iCount] = kv.GetNum("team", 0);

	g_iCount++;

	return true;
}

public int PlayerModels_Equip(int client, int itemid)
{
	int iIndex = MyStore_GetDataIndex(itemid);
	g_iModel[client] = itemid;

	if (gc_bChangeInstant.BoolValue && IsPlayerAlive(client) && (GetClientTeam(client) == g_iTeam[iIndex] || g_iTeam[iIndex] == 0))
	{
		SetClientModel(client, g_sModel[iIndex], g_sArms[iIndex], iIndex);
	}
	else
	{
		if (MyStore_IsClientLoaded(client))
		{
			CPrintToChat(client, "%s%t", g_sChatPrefix, "PlayerModels Settings Changed");
		}
	}

	if (g_hTimerPreview[client] != null)
	{
		TriggerTimer(g_hTimerPreview[client], false);
	}

	return g_iTeam[iIndex];
}

public int PlayerModels_Remove(int client, int itemid)
{
	int iIndex = MyStore_GetDataIndex(itemid);
	g_iModel[client] = -1;
	if (MyStore_IsClientLoaded(client) && !gc_bChangeInstant.BoolValue)
		CPrintToChat(client, "%s%t", g_sChatPrefix, "PlayerModels Settings Changed");

	if (MyStore_IsClientLoaded(client) && gc_bChangeInstant.BoolValue && GetClientTeam(client) == g_iTeam[iIndex])
		CS_UpdateClientModel(client);

	return g_iTeam[iIndex];
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsPlayerAlive(client) || !(CS_TEAM_T <= GetClientTeam(client) <= CS_TEAM_CT))
		return;

	if (gc_fDelay.FloatValue == 0)
	{
		Timer_PlayerSpawnPost(null, GetClientUserId(client));
	}
	else
	{
		CreateTimer(gc_fDelay.FloatValue, Timer_PlayerSpawnPost, GetClientUserId(client));
	}
}

public Action Timer_PlayerSpawnPost(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!client || !IsClientInGame(client))
		return Plugin_Stop;

	int iEquipped = MyStore_GetEquippedItem(client, "playermodel", GetClientTeam(client));
	if (iEquipped < 0)
		return Plugin_Stop;

	int iIndex = MyStore_GetDataIndex(iEquipped);
	SetClientModel(client, g_sModel[iIndex], g_sArms[iIndex], iIndex);

	return Plugin_Stop;
}

void SetClientModel(int client, char[] model, char[] arms = "", int index)
{
	SetEntityModel(client, model);

	if (arms[0] == 0)
		return;

	RemoveClientGloves(client, index);
	SetEntPropString(client, Prop_Send, "m_szArmsModel", arms);
	CreateTimer(0.15, Timer_RemovePlayerWeapon, GetClientUserId(client));
}

public Action Timer_RemovePlayerWeapon(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);

	if (!client || !IsClientConnected(client) || !IsPlayerAlive(client))
		return Plugin_Stop;

	int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

	if (iWeapon == -1)
		return Plugin_Stop;

	RemovePlayerItem(client, iWeapon);
	DataPack pack = new DataPack();
	pack.WriteCell(iWeapon);
	pack.WriteCell(GetClientUserId(client));
	CreateTimer(0.15, Timer_GivePlayerWeapon, pack);

	return Plugin_Stop;
}

public Action Timer_GivePlayerWeapon(Handle timer, DataPack pack)
{
	pack.Reset();
	int iWeapon = pack.ReadCell();
	int client = GetClientOfUserId(pack.ReadCell());
	if (0 < client <= MAXPLAYERS && IsClientConnected(client) && IsPlayerAlive(client))
	{
		EquipPlayerWeapon(client, iWeapon);
	}
	delete pack;

	return Plugin_Stop;
}

void RemoveClientGloves(int client, int index = -1)
{
	if (index == -1 && GetEquippedSkin(client) <= 0)
		return;

	int gloves = GetEntPropEnt(client, Prop_Send, "m_hMyWearables");
	if (gloves != -1)
	{
		AcceptEntityInput(gloves, "KillHierarchy");
	}
}

int GetEquippedSkin(int client)
{
	return MyStore_GetEquippedItem(client, "playermodel", GetClientTeam(client));
}


public void OnClientDisconnect(int client)
{
	if (g_hTimerPreview[client] != null)
	{
		TriggerTimer(g_hTimerPreview[client], false);
	}
	g_iModel[client] = -1;
}

public void MyStore_OnPreviewItem(int client, char[] type, int index)
{
	if (g_hTimerPreview[client] != null)
	{
		TriggerTimer(g_hTimerPreview[client], false);
	}

	if (!StrEqual(type, "playermodel"))
		return;

	int iPreview = CreateEntityByName("prop_dynamic_override"); //prop_physics_multiplayer

	DispatchKeyValue(iPreview, "spawnflags", "64");
	DispatchKeyValue(iPreview, "model", g_sModel[index]);

	DispatchSpawn(iPreview);

	SetEntProp(iPreview, Prop_Send, "m_CollisionGroup", 11);

	AcceptEntityInput(iPreview, "Enable");

	int offset = GetEntSendPropOffs(iPreview, "m_clrGlow");
	SetEntProp(iPreview, Prop_Send, "m_bShouldGlow", true, true);
	SetEntProp(iPreview, Prop_Send, "m_nGlowStyle", 0);
	SetEntPropFloat(iPreview, Prop_Send, "m_flGlowMaxDist", 2000.0);


	SetEntData(iPreview, offset, 57, _, true);
	SetEntData(iPreview, offset + 1, 197, _, true);
	SetEntData(iPreview, offset + 2, 187, _, true);
	SetEntData(iPreview, offset + 3, 155, _, true);

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

	fPosition[2] += 5;

	TeleportEntity(iPreview, fPosition, fAngles, NULL_VECTOR);

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
			AcceptEntityInput(entity, "Kill");
		}
	}
	g_iPreviewEntity[client] = INVALID_ENT_REFERENCE;

	return Plugin_Stop;
}

/*
 * MyStore - Trail item module
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
#include <cstrike>
#include <clientprefs>

#include <mystore> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/mystore.inc

#include <colors> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/colors.inc
#include <smartdm> //https://forums.alliedmods.net/attachment.php?attachmentid=136152&d=1406298576
#include <autoexecconfig> //https://raw.githubusercontent.com/Impact123/AutoExecConfig/development/autoexecconfig.inc

#pragma semicolon 1
#pragma newdecls required

char g_sMaterial[STORE_MAX_ITEMS][PLATFORM_MAX_PATH];
float g_fWidth[STORE_MAX_ITEMS];
int g_iColor[STORE_MAX_ITEMS][4];
int g_iSlot[STORE_MAX_ITEMS];
int g_iCacheID[STORE_MAX_ITEMS];

bool g_bSpawnTrails[MAXPLAYERS + 1];

ConVar gc_iPadding;
ConVar gc_iMaxColumns;
ConVar gc_iTrailLife;

ConVar gc_bEnable;

float g_fClientCounters[MAXPLAYERS + 1];
float g_fLastPosition[MAXPLAYERS + 1][3];

int g_iCount = 0;
int g_iClientTrails[MAXPLAYERS + 1][STORE_MAX_SLOTS];
int g_iTrailOwners[2048] = {-1};

bool g_bHide[MAXPLAYERS + 1];
Handle g_hHideCookie = INVALID_HANDLE;

Handle g_hTimerPreview[MAXPLAYERS + 1];
int g_iPreviewEntity[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

char g_sChatPrefix[128];

/*
 * Build date: <DATE>
 * Build number: <BUILD>
 * Commit: https://github.com/shanapu/MyStore/commit/<COMMIT>
 */

public Plugin myinfo = 
{
	name = "MyStore - Trail item module",
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

	gc_iPadding = AutoExecConfig_CreateConVar("mystore_trails_padding", "30.0", "Space between two trails", _, true, 1.0);
	gc_iMaxColumns = AutoExecConfig_CreateConVar("mystore_trails_columns", "3", "Number of columns before starting to increase altitude", _, true, 1.0);
	gc_iTrailLife = AutoExecConfig_CreateConVar("mystore_trails_life", "1.0", "Life of a trail in seconds", _, true, 0.1);

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	MyStore_RegisterHandler("trail", Trails_OnMapStart, Trails_Reset, Trails_Config, Trails_Equip, Trails_Remove, true);

	HookEvent("player_spawn", Trails_PlayerSpawn);
	HookEvent("player_death", Trails_PlayerDeath);

	g_hHideCookie = RegClientCookie("Trails_Hide_Cookie", "Cookie to check if Trails are blocked", CookieAccess_Private);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!AreClientCookiesCached(i))
			continue;

		OnClientCookiesCached(i);
	}

	RegConsoleCmd("sm_hidetrails", Command_Hide, "Hides the Trails");
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}


public void OnClientCookiesCached(int client)
{
	char sValue[8];
	GetClientCookie(client, g_hHideCookie, sValue, sizeof(sValue));

	g_bHide[client] = (sValue[0] && StringToInt(sValue));
}

public Action Command_Hide(int client, int args)
{
	g_bHide[client] = !g_bHide[client];
	if (g_bHide[client])
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Item hidden", "trail");
		SetClientCookie(client, g_hHideCookie, "1");
	}
	else
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Item visible", "trail");
		SetClientCookie(client, g_hHideCookie, "0");
	}

	return Plugin_Handled;
}

public void OnClientDisconnect(int client)
{
	g_bHide[client] = false;
}

public void Trails_OnMapStart()
{
	for (int a = 0; a <= MaxClients; a++)
	{
		for (int b = 0; b < STORE_MAX_SLOTS; b++)
		{
			g_iClientTrails[a][b] = 0;
		}
	}

	for (int i = 0; i < g_iCount; i++)
	{
		g_iCacheID[i] = PrecacheModel(g_sMaterial[i], true);
		Downloader_AddFileToDownloadsTable(g_sMaterial[i]);
	}
}

public void Trails_Reset()
{
	g_iCount = 0;
}

public bool Trails_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, g_iCount);

	kv.GetString("material", g_sMaterial[g_iCount], PLATFORM_MAX_PATH);

	if (!FileExists(g_sMaterial[g_iCount], true))
	{
		MyStore_LogMessage(0, LOG_ERROR, "Can't find trail %s.", g_sMaterial[g_iCount]);
		return false;
	}

	g_fWidth[g_iCount] = kv.GetFloat("width", 10.0);
	kv.GetColor("color", g_iColor[g_iCount][0], g_iColor[g_iCount][1], g_iColor[g_iCount][2], g_iColor[g_iCount][3]);
	g_iSlot[g_iCount] = kv.GetNum("slot");

	g_iCount++;

	return true;
}

public int Trails_Equip(int client, int itemid)
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client) || !(CS_TEAM_T <= GetClientTeam(client) <= CS_TEAM_CT))
		return -1;

	CreateTimer(0.1, Timer_CreateTrails, GetClientUserId(client));

	return g_iSlot[MyStore_GetDataIndex(itemid)];
}

public int Trails_Remove(int client, int itemid)
{
	CreateTimer(0.1, Timer_CreateTrails, GetClientUserId(client));

	return  g_iSlot[MyStore_GetDataIndex(itemid)];
}

public Action Timer_CreateTrails(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!client)
		return Plugin_Stop;

	for (int i = 0; i < STORE_MAX_SLOTS; i++)
	{
		RemoveTrail(client, i);
		CreateTrail(client, -1, i);
	}

	return Plugin_Stop;
}

public Action Trails_PlayerSpawn(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsPlayerAlive(client) || !(CS_TEAM_T <= GetClientTeam(client) <= CS_TEAM_CT))
		return Plugin_Continue;

	CreateTimer(0.1, Timer_CreateTrails, GetClientUserId(client));

	return Plugin_Continue;
}

public Action Trails_PlayerDeath(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsPlayerAlive(client))
	{
		for (int i = 0; i < STORE_MAX_SLOTS; i++)  //todo NO LOOP
		{
			RemoveTrail(client, i);
		}
	}

	return Plugin_Continue;
}

void CreateTrail(int client, int itemid = -1, int slot = 0)
{
	if (!gc_bEnable.BoolValue)
		return;

	int iEquipped = (itemid == -1 ? MyStore_GetEquippedItem(client, "trail", slot) : itemid);
	if (iEquipped >=  0)
	{
		int iIndex = MyStore_GetDataIndex(iEquipped);

		int m_aEquipped[STORE_MAX_SLOTS] = {-1,...};
		int iNumEquipped = 0;
		int iCurrent;
		for (int i = 0; i < STORE_MAX_SLOTS; i++)
		{
			if ((m_aEquipped[iNumEquipped] = MyStore_GetEquippedItem(client, "trail", i))>= 0) // to do equip
			{
				if (i == g_iSlot[iIndex])
				{
					iCurrent = iNumEquipped;
				}

				iNumEquipped++;
			}
		}

		if (g_iClientTrails[client][slot] == 0 || !IsValidEdict(g_iClientTrails[client][slot]))
		{
			g_iClientTrails[client][slot] = CreateEntityByName("env_sprite");
			DispatchKeyValue(g_iClientTrails[client][slot], "classname", "env_sprite");
			DispatchKeyValue(g_iClientTrails[client][slot], "spawnflags", "1");
			DispatchKeyValue(g_iClientTrails[client][slot], "scale", "0.0");
			DispatchKeyValue(g_iClientTrails[client][slot], "rendermode", "10");
			DispatchKeyValue(g_iClientTrails[client][slot], "rendercolor", "255 255 255 0");
			DispatchKeyValue(g_iClientTrails[client][slot], "model", g_sMaterial[iIndex]);
			DispatchSpawn(g_iClientTrails[client][slot]);
			AttachTrail(g_iClientTrails[client][slot], client, iCurrent, iNumEquipped);
			SDKHook(g_iClientTrails[client][slot], SDKHook_SetTransmit, Hook_TrailSetTransmit);
		}

		TE_SetupBeamFollow(g_iClientTrails[client][slot], g_iCacheID[iIndex], 0, gc_iTrailLife.FloatValue, g_fWidth[iIndex], g_fWidth[iIndex], 10, g_iColor[iIndex]);
		TE_SendToAll();
	}
}

public void RemoveTrail(int client, int slot)
{
	if (g_iClientTrails[client][slot] != 0 && IsValidEdict(g_iClientTrails[client][slot]))
	{
		g_iTrailOwners[g_iClientTrails[client][slot]] = -1;

		char sClassname[64];
		GetEdictClassname(g_iClientTrails[client][slot], sClassname, sizeof(sClassname));
		if (strcmp("env_sprite", sClassname) == 0)
		{
			SDKUnhook(g_iClientTrails[client][slot], SDKHook_SetTransmit, Hook_TrailSetTransmit);
			AcceptEntityInput(g_iClientTrails[client][slot], "Kill");
		}
	}
	g_iClientTrails[client][slot] = 0;
}

public void AttachTrail(int ent, int client, int current, int num)
{
	float fOrigin[3];
	float fAng[3];
	float fTemp[3] = {0.0, 90.0, 0.0};
	GetEntPropVector(client, Prop_Data, "m_angAbsRotation", fAng);
	SetEntPropVector(client, Prop_Data, "m_angAbsRotation", fTemp);
	float m_fX = (gc_iPadding.FloatValue * ((num-1) % gc_iMaxColumns.IntValue)) / 2 - (gc_iPadding.FloatValue * (current % gc_iMaxColumns.IntValue));
	float fPosition[3];
	fPosition[0] = m_fX;
	fPosition[1] = 0.0;
	fPosition[2] =  5.0 + (current / gc_iMaxColumns.IntValue) * gc_iPadding.FloatValue;
	GetClientAbsOrigin(client, fOrigin);
	AddVectors(fOrigin, fPosition, fOrigin);
	TeleportEntity(ent, fOrigin, fTemp, NULL_VECTOR);
	SetVariantString("!activator");
	AcceptEntityInput(ent, "SetParent", client, ent);
	SetEntPropVector(client, Prop_Data, "m_angAbsRotation", fAng);
/*
	SetVariantString("OnUser1 !self:SetScale:1:0.5:-1");
	AcceptEntityInput(ent, "AddOutput");
	AcceptEntityInput(ent, "FireUser1");*/
}

public void OnGameFrame()
{
	if (GetGameTickCount() % 6 != 0)
		return;

	float fTime = GetEngineTime();
	float fPosition[3];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || !IsPlayerAlive(i))
			continue;

		GetClientAbsOrigin(i, fPosition);
		if (GetVectorDistance(g_fLastPosition[i], fPosition) <= 5.0)
		{
			if (g_bSpawnTrails[i])
				return;

			if (fTime - g_fClientCounters[i] >= gc_iTrailLife.FloatValue / 2)
			{
				g_bSpawnTrails[i] = true;
			}
		}
		else
		{
			if (g_bSpawnTrails[i])
			{
				g_bSpawnTrails[i] = false;
				TE_Start("KillPlayerAttachments");
				TE_WriteNum("m_nPlayer",i);
				TE_SendToAll();
				for (int a = 0; a < STORE_MAX_SLOTS; a++)
				{
					CreateTrail(i, -1, a);
				}
			}
			else
			{
				g_fClientCounters[i] = fTime;
			}

			g_fLastPosition[i] = fPosition;
		}
	}
}

public Action Hook_TrailSetTransmit(int ent, int client)
{
	Set_EdictFlags(ent);

	return g_bHide[client] ? Plugin_Handled : Plugin_Continue;
}

void Set_EdictFlags(int edict)
{
	if (GetEdictFlags(edict) & FL_EDICT_ALWAYS)
	{
		SetEdictFlags(edict, (GetEdictFlags(edict) ^ FL_EDICT_ALWAYS));
	}
}

public void MyStore_OnPreviewItem(int client, char[] type, int index)
{
	if (g_hTimerPreview[client] != null)
	{
		TriggerTimer(g_hTimerPreview[client], false);
	}

	if (StrContains(type, "trail") == -1)
		return;

	int iPreview = CreateEntityByName("env_sprite_oriented");

	DispatchKeyValue(iPreview, "model", g_sMaterial[index]);
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

	fPosition[2] += 35;

	TeleportEntity(iPreview, fPosition, NULL_VECTOR, NULL_VECTOR);

	g_iPreviewEntity[client] = EntIndexToEntRef(iPreview);

	SDKHook(iPreview, SDKHook_SetTransmit, Hook_SetTransmit_Preview);

	g_hTimerPreview[client] = CreateTimer(5.0, Timer_KillPreview, client);

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
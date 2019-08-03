/*
 * MyStore - Spray item module
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
#include <clientprefs>

#include <mystore> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/mystore.inc

#include <colors> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/colors.inc
#include <smartdm> //https://forums.alliedmods.net/attachment.php?attachmentid=136152&d=1406298576
#include <autoexecconfig> //https://raw.githubusercontent.com/Impact123/AutoExecConfig/development/autoexecconfig.inc

#pragma semicolon 1
#pragma newdecls required

char g_sSprays[STORE_MAX_ITEMS][PLATFORM_MAX_PATH];
char g_sChatPrefix[128];

ConVar gc_bEnable;

int g_iSprayPrecache[STORE_MAX_ITEMS] = {-1,...};
int g_iSpam[STORE_MAX_ITEMS];
int g_iSprayCache[MAXPLAYERS + 1] = {-1,...};
int g_iRoundCooldown[MAXPLAYERS + 1] = {0,...};
int g_iCount = 0;

ConVar gc_iSprayDistance;

bool g_bHide[MAXPLAYERS + 1];
Handle g_hHideCookie = INVALID_HANDLE;

public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");

	AutoExecConfig_SetFile("items", "sourcemod/MyStore");
	AutoExecConfig_SetCreateFile(true);

	gc_iSprayDistance = AutoExecConfig_CreateConVar("mystore_spray_distance", "115", "Max distance from wall to spray", _, true, 1.0);

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	MyStore_RegisterHandler("spray", Sprays_OnMapStart, Sprays_Reset, Sprays_Config, Sprays_Equip, Sprays_Remove, true);

	g_hHideCookie = RegClientCookie("Sprays_Hide_Cookie", "Cookie to check if Sprays are blocked", CookieAccess_Private);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!AreClientCookiesCached(i))
			continue;

		OnClientCookiesCached(i);
	}

	RegConsoleCmd("sm_hidesprays", Command_Hide, "Hide the Sprays");
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
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Item hidden", "spray");
		SetClientCookie(client, g_hHideCookie, "1");
	}
	else
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Item visible", "spray");
		SetClientCookie(client, g_hHideCookie, "0");
	}

	return Plugin_Handled;
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

public void Sprays_OnMapStart()
{
	char sDecal[PLATFORM_MAX_PATH];

	for (int i = 0; i < g_iCount; i++)
	{
		strcopy(sDecal, sizeof(sDecal), g_sSprays[i][10]);
		sDecal[strlen(sDecal)-4] = 0;

		g_iSprayPrecache[i] = PrecacheDecal(sDecal, true);
		Downloader_AddFileToDownloadsTable(g_sSprays[i]);
	}

	//Downloader_AddFileToDownloadsTable("models/esko/blockmaker/normal_small.mdl");

	PrecacheSound("player/sprayer.wav", true);
}

public void OnClientConnected(int client)
{
	g_iSprayCache[client] = -1;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (!gc_bEnable.BoolValue)
		return Plugin_Continue;

	if (buttons & IN_USE && g_iSprayCache[client] != -1 && g_iRoundCooldown[client] <= GetTime())
	{
		if (!IsPlayerAlive(client))
			return Plugin_Continue;

		if (0 < g_iSpam[g_iSprayCache[client]] && g_iRoundCooldown[client] > GetTime())
		{
			CPrintToChat(client, "%s%t", g_sChatPrefix, "Spam Cooldown", g_iSpam[client] - GetTime());
			return Plugin_Continue;
		}

		int[] clients = new int[MaxClients + 1];
		int numClients = 0;
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i))
				continue;

			if (g_bHide[i])
				continue;

			clients[numClients] = i;
			numClients++;
		}

		if (numClients < 1)
			return Plugin_Continue;

		float flEyes[3];
		GetClientEyePosition(client, flEyes);

		float flView[3];
		GetPlayerEyeViewPoint(client, flView);

		if (GetVectorDistance(flEyes, flView) > gc_iSprayDistance.IntValue)
			return Plugin_Continue;

		TE_Start("World Decal");
		TE_WriteVector("m_vecOrigin",flView);
		TE_WriteNum("m_nIndex", g_iSprayPrecache[g_iSprayCache[client]]);

		TE_Send(clients, numClients, 0.0);

		EmitSoundToAll("player/sprayer.wav", client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.6);

		g_iRoundCooldown[client] = GetTime() + g_iSpam[g_iSprayCache[client]];
	}

	return Plugin_Continue;
}

public void Sprays_Reset()
{
	g_iCount = 0;
}

public bool Sprays_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, g_iCount);
	kv.GetString("material", g_sSprays[g_iCount], sizeof(g_sSprays[]));
	g_iSpam[g_iCount] = kv.GetNum("cooldown", 10);

	if (!FileExists(g_sSprays[g_iCount], true))
	{
		MyStore_LogMessage(0, LOG_ERROR, "Can't find spray %s.", g_sSprays[g_iCount]);
		return false;
	}

	g_iCount++;

	return true;
}

public int Sprays_Equip(int client, int itemid)
{
	g_iSprayCache[client] = MyStore_GetDataIndex(itemid);

	return ITEM_EQUIP_SUCCESS;
}

public int Sprays_Remove(int client, int itemid)
{
	g_iSprayCache[client] = -1;

	return ITEM_EQUIP_REMOVE;
}

void GetPlayerEyeViewPoint(int client, float fPosition[3])
{
	float m_flRot[3];
	float fPos[3];

	GetClientEyeAngles(client, m_flRot);
	GetClientEyePosition(client, fPos);

	TR_TraceRayFilter(fPos, m_flRot, MASK_ALL, RayType_Infinite, TraceRayDontHitSelf, client);
	TR_GetEndPosition(fPosition);
}

public bool TraceRayDontHitSelf(int entity, int mask, any data)
{
	if (entity == data)
	{
		return false;
	}

	return true;
}
/*
Handle g_hTimerPreview[MAXPLAYERS + 1];
int g_iPreviewEntity[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};


public void OnClientDisconnect(int client)
{
	if (g_hTimerPreview[client] != null)
	{
		TriggerTimer(g_hTimerPreview[client], false);
	}
}


public void MyStore_OnPreviewItem(int client, char[] type, int index)
{
	if (g_hTimerPreview[client] != null)
	{
		TriggerTimer(g_hTimerPreview[client], false);
	}

	if (!StrEqual(type, "spray"))
		return;

	int iPreview = CreateEntityByName("env_sprite_oriented");

	DispatchKeyValue(iPreview, "spawnflags", "1");
	DispatchKeyValueFloat(iPreview, "scale", 0.2);
	DispatchKeyValue(iPreview, "model", g_sSprays[index]);
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
			AcceptEntityInput(entity, "Kill");
		}
	}
	g_iPreviewEntity[client] = INVALID_ENT_REFERENCE;

	return Plugin_Stop;
}
*/
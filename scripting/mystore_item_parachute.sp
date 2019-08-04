/*
 * MyStore - Parachute item module
 * by: shanapu
 * https://github.com/shanapu/
 * 
 * Copyright (C) 2018-2019 Thomas Schmidt (shanapu)
 * Credits: SWAT_88 - https://forums.alliedmods.net/showthread.php?p=580269
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

#define COOLDOWN 5.0
#define TIME 300

int g_iJumps[MAXPLAYERS + 1];
Handle g_hTimerReload[MAXPLAYERS + 1];

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>

#include <mystore> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/mystore.inc

#include <smartdm> //https://forums.alliedmods.net/attachment.php?attachmentid=136152&d=1406298576
#include <colors> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/colors.inc

#pragma semicolon 1
#pragma newdecls required

bool g_bParachute[MAXPLAYERS + 1];
bool g_bEquipt[MAXPLAYERS + 1] = false;

char g_sModels[STORE_MAX_ITEMS][PLATFORM_MAX_PATH];
char g_sChatPrefix[128];

ConVar gc_bEnable;

float g_fSpeed[STORE_MAX_ITEMS];

int g_iCount = 0;
int g_iVelocity = -1;
int g_iParaEntRef[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};
int g_iClientModel[MAXPLAYERS + 1];

Handle g_hTimerPreview[MAXPLAYERS + 1];
int g_iPreviewEntity[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

bool g_bHide[MAXPLAYERS + 1];
Handle g_hHideCookie = INVALID_HANDLE;

/*
 * Build date: <DATE>
 * Build number: <BUILD>
 * Commit: https://github.com/shanapu/MyStore/commit/<COMMIT>
 */

public Plugin myinfo = 
{
	name = "MyStore - Parachute item module",
	author = "shanapu",
	description = "",
	version = "0.1.<BUILD>",
	url = "github.com/shanapu/MyStore"
};

public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");

	MyStore_RegisterHandler("parachute", ParaChute_OnMapStart, ParaChute_Reset, ParaChute_Config, ParaChute_Equip, ParaChute_Remove, true);

	g_iVelocity = FindSendPropInfo("CBasePlayer", "m_vecVelocity[0]");

	g_hHideCookie = RegClientCookie("Parachute_Hide_Cookie", "Cookie to check if Parachute are blocked", CookieAccess_Private);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!AreClientCookiesCached(i))
			continue;

		OnClientCookiesCached(i);
	}

	RegConsoleCmd("sm_hideparachute", Command_Hide, "Hide the Parachute");
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
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Item hidden", "parachute");
		SetClientCookie(client, g_hHideCookie, "1");
	}
	else
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Item visible", "parachute");
		SetClientCookie(client, g_hHideCookie, "0");
	}

	return Plugin_Handled;
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

public void ParaChute_OnMapStart()
{
	for (int i = 0; i < g_iCount; i++)
	{
		Downloader_AddFileToDownloadsTable(g_sModels[i]);

		if (IsModelPrecached(g_sModels[i]))
			continue;

		PrecacheModel(g_sModels[i]);
	}
}

public void ParaChute_Reset()
{
	g_iCount = 0;
}

public bool ParaChute_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, g_iCount);

	kv.GetString("model", g_sModels[g_iCount], PLATFORM_MAX_PATH);

	if (!FileExists(g_sModels[g_iCount], true))
	{
		MyStore_LogMessage(0, LOG_ERROR, "Can't find model %s.", g_sModels[g_iCount]);
		return false;
	}

	g_fSpeed[g_iCount] = kv.GetFloat("fallspeed", 100.0);

	g_iCount++;

	return true;
}

public int ParaChute_Equip(int client, int itemid)
{
	g_iClientModel[client] = MyStore_GetDataIndex(itemid);
	g_bEquipt[client] = true;

	return ITEM_EQUIP_SUCCESS;
}

public int ParaChute_Remove(int client, int itemid)
{
	DisableParachute(client);
	g_bEquipt[client] = false;

	return ITEM_EQUIP_REMOVE;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (!g_bEquipt[client])
		return Plugin_Continue;

	if (!gc_bEnable.BoolValue)
		return Plugin_Continue;

	// https://gitlab.com/Zipcore/HungerGames/blob/master/addons/sourcemod/scripting/hungergames/tools/parachute.sp
	// Check abort reasons
	if (g_bParachute[client])
	{
		// Abort by released button
		if (!(buttons & IN_USE) || !IsPlayerAlive(client))
		{
			DisableParachute(client);
			return Plugin_Continue;
		}

		// Abort by up speed
		float fVel[3];
		GetEntDataVector(client, g_iVelocity, fVel);

		if (fVel[2] >= 0.0)
		{
			DisableParachute(client);
			return Plugin_Continue;
		}

		// Abort by on ground flag
		if (GetEntityFlags(client) & FL_ONGROUND)
		{
			DisableParachute(client);
			return Plugin_Continue;
		}

		if (0 <= g_iJumps[client] <= TIME)
		{
			g_iJumps[client]++;
		}
		else
		{
			g_hTimerReload[client] = CreateTimer(COOLDOWN, Timer_Reload, GetClientUserId(client));
			PrintCenterText(client, "%s", "Parachute Empty");
			DisableParachute(client);
			return Plugin_Continue;
		}

		// decrease fallspeed
		float fOldSpeed = fVel[2];

		// Player is falling to fast, lets slow him to max gc_fSpeed
		if (fVel[2] < g_fSpeed[g_iClientModel[client]] * (-1.0))
		{
			fVel[2] = g_fSpeed[g_iClientModel[client]] * (-1.0);
		}

		// fallspeed changed
		if (fOldSpeed != fVel[2])
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVel);
	}
	// Should we start the parashute?
	else if (g_bEquipt[client] && (0 <= g_iJumps[client] <= TIME))
	{
		// Reject by released button
		if (!(buttons & IN_USE) || !IsPlayerAlive(client))
			return Plugin_Continue;

		// Reject by on ground flag
		if (GetEntityFlags(client) & FL_ONGROUND)
			return Plugin_Continue;

		// Reject by up speed
		float fVel[3];
		GetEntDataVector(client, g_iVelocity, fVel);

		if (fVel[2] >= 0.0)
			return Plugin_Continue;

		// Open parachute
		int iEntity = CreateEntityByName("prop_dynamic_override");
		DispatchKeyValue(iEntity, "model", g_sModels[g_iClientModel[client]]);
		DispatchSpawn(iEntity);

		SetEntityMoveType(iEntity, MOVETYPE_NOCLIP);

		// Teleport to player
		float fPos[3];
		float fAng[3];
		GetClientAbsOrigin(client, fPos);
		GetClientAbsAngles(client, fAng);
		fAng[0] = 0.0;
		TeleportEntity(iEntity, fPos, fAng, NULL_VECTOR);

		// Parent to player
		char sClient[16];
		Format(sClient, 16, "client%d", client);
		DispatchKeyValue(client, "targetname", sClient);
		SetVariantString(sClient);
		AcceptEntityInput(iEntity, "SetParent", iEntity, iEntity, 0);

		g_iParaEntRef[client] = EntIndexToEntRef(iEntity);
		g_bParachute[client] = true;

		Set_EdictFlags(iEntity);

		SDKHook(iEntity, SDKHook_SetTransmit, Hook_SetTransmit);
	}

	return Plugin_Continue;
}

public Action Hook_SetTransmit(int entity, int client)
{
	Set_EdictFlags(entity);

	return g_bHide[client] ? Plugin_Handled : Plugin_Continue;
}

void Set_EdictFlags(int edict)
{
	if (GetEdictFlags(edict) & FL_EDICT_ALWAYS)
	{
		SetEdictFlags(edict, (GetEdictFlags(edict) ^ FL_EDICT_ALWAYS));
	}
}

void DisableParachute(int client)
{
	int iEntity = EntRefToEntIndex(g_iParaEntRef[client]);
	if (iEntity != INVALID_ENT_REFERENCE)
	{
		SDKUnhook(iEntity, SDKHook_SetTransmit, Hook_SetTransmit);
		AcceptEntityInput(iEntity, "ClearParent");
		AcceptEntityInput(iEntity, "kill");
	}

	g_bParachute[client] = false;
	g_iParaEntRef[client] = INVALID_ENT_REFERENCE;
}

public void OnClientDisconnect(int client)
{
	if (g_hTimerPreview[client] != null)
	{
		TriggerTimer(g_hTimerPreview[client], false);
	}

	g_bEquipt[client] = false;
	g_bHide[client] = false;
}

public void OnClientDisconnect_Post(int client)
{
	g_iJumps[client] = 0;

	delete g_hTimerReload[client];
}

public Action Timer_Reload(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);

	if (!client)
		return Plugin_Stop;

	if (g_hTimerReload[client] != null)
	{
		g_iJumps[client] = 0;
		PrintCenterText(client, "Parachute Reloaded");
		g_hTimerReload[client] = null;
	}

	return Plugin_Stop;
}

public void MyStore_OnPreviewItem(int client, char[] type, int index)
{
	if (g_hTimerPreview[client] != null)
	{
		TriggerTimer(g_hTimerPreview[client], false);
	}

	if (!StrEqual(type, "parachute"))
		return;

	int iPreview = CreateEntityByName("prop_dynamic_override"); //prop_dynamic_override

	DispatchKeyValue(iPreview, "spawnflags", "64");
	DispatchKeyValue(iPreview, "model", g_sModels[index]);
	DispatchKeyValue(iPreview, "scale", "0.4");
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

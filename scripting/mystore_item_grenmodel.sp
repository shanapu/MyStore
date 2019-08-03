/*
 * MyStore - Grenade model item module
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
#include <smartdm> //https://forums.alliedmods.net/attachment.php?attachmentid=136152&d=1406298576

#pragma semicolon 1
#pragma newdecls required

char g_sModel[STORE_MAX_ITEMS][PLATFORM_MAX_PATH];
char g_sWeapon[STORE_MAX_ITEMS][64];
int g_iSlot[STORE_MAX_ITEMS];

bool g_bEquipt[MAXPLAYERS + 1] = false;

char g_sSlots[16][64];
char g_sChatPrefix[128];

ConVar gc_bEnable;

int g_iCount = 0;
int g_iSlots = 0;

Handle g_hTimerPreview[MAXPLAYERS + 1];
int g_iPreviewEntity[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");

	MyStore_RegisterHandler("grenademodel", GrenadeModels_OnMapStart, GrenadeModels_Reset, GrenadeModels_Config, GrenadeModels_Equip, GrenadeModels_Remove, true);
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

public void GrenadeModels_OnMapStart()
{
	for (int i = 0; i < g_iCount; i++)
	{
		PrecacheModel(g_sModel[i], true);
		Downloader_AddFileToDownloadsTable(g_sModel[i]);
	}
}

public void GrenadeModels_Reset()
{
	g_iCount = 0;
}

public bool GrenadeModels_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, g_iCount);

	kv.GetString("model", g_sModel[g_iCount], PLATFORM_MAX_PATH);

	if (!FileExists(g_sModel[g_iCount], true))
	{
		MyStore_LogMessage(0, LOG_ERROR, "Can't find emote material %s.", g_sModel[g_iCount]);
		return false;
	}

	kv.GetString("grenade", g_sWeapon[g_iCount], PLATFORM_MAX_PATH);
	g_iSlot[g_iCount] = GrenadeModels_GetSlot(g_sWeapon[g_iCount]);

	g_iCount++;

	return true;
}

public int GrenadeModels_Equip(int client, int itemid)
{
	g_bEquipt[client] = true;

	return g_iSlot[MyStore_GetDataIndex(itemid)];
}

public int GrenadeModels_Remove(int client, int itemid)
{
	g_bEquipt[client] = false;

	return g_iSlot[MyStore_GetDataIndex(itemid)];
}

public int GrenadeModels_GetSlot(char[] weapon)
{
	for (int i = 0; i < g_iSlots; i++)
	{
		if (strcmp(weapon, g_sSlots[i]) == 0)
			return i;
	}

	strcopy(g_sSlots[g_iSlots], sizeof(g_sSlots[]), weapon);
	return g_iSlots++;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (g_iCount == 0)
		return;

	if (StrContains(classname, "_projectile") > 0)
	{
		SDKHook(entity, SDKHook_SpawnPost, OnEntitySpawnedPost);
	}
}

public int OnEntitySpawnedPost(int entity)
{
	if (!gc_bEnable.BoolValue)
		return;

	int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if (!client)
		return;

	if (!g_bEquipt[client])
		return;

	if (!(0 < client <= MaxClients))
		return;

	char sClassname[64];
	GetEdictClassname(entity, sClassname, sizeof(sClassname));

	for (int i = 0; i < strlen(sClassname); i++)
	{
		if (sClassname[i] == '_')
		{
			sClassname[i] = 0;
			break;
		}
	}

	int iSlots = GrenadeModels_GetSlot(sClassname);

	int iEquipped = MyStore_GetEquippedItem(client, "grenademodel", iSlots);

	if (iEquipped < 0)
		return;

	int iIndex = MyStore_GetDataIndex(iEquipped);
	SetEntityModel(entity, g_sModel[iIndex]);
}

public void OnClientDisconnect(int client)
{
	if (g_hTimerPreview[client] != null)
	{
		TriggerTimer(g_hTimerPreview[client], false);
	}

	g_bEquipt[client] = false;
}

public void MyStore_OnPreviewItem(int client, char[] type, int index)
{
	if (g_hTimerPreview[client] != null)
	{
		TriggerTimer(g_hTimerPreview[client], false);
	}

	if (!StrEqual(type, "grenademodel"))
		return;

	int iPreview = CreateEntityByName("prop_dynamic_override"); //prop_dynamic_override

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

	float fOri[3];
	float fAng[3];
	float fRad[2];
	float fPos[3];

	GetClientAbsOrigin(client, fOri);
	GetClientAbsAngles(client, fAng);

	fRad[0] = DegToRad(fAng[0]);
	fRad[1] = DegToRad(fAng[1]);

	fPos[0] = fOri[0] + 64 * Cosine(fRad[0]) * Cosine(fRad[1]);
	fPos[1] = fOri[1] + 64 * Cosine(fRad[0]) * Sine(fRad[1]);
	fPos[2] = fOri[2] + 4 * Sine(fRad[0]);

	fAng[0] *= -1.0;
	fAng[1] *= -1.0;

	fPos[2] += 55;

	TeleportEntity(iPreview, fPos, fAng, NULL_VECTOR);

	g_iPreviewEntity[client] = EntIndexToEntRef(iPreview);

	int iRotator = CreateEntityByName("func_rotating");
	DispatchKeyValueVector(iRotator, "origin", fPos);

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

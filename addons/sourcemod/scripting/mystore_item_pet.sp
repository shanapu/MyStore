/*
 * MyStore - Pet item module
 * by: shanapu
 * https://github.com/shanapu/
 * 
 * Copyright (C) 2018-2019 Thomas Schmidt (shanapu)
 * Credits: Totenfluch - https://github.com/Totenfluch/store-plugin
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

/*
 * Build date: <DATE>
 * Build number: <BUILD>
 * Commit: https://github.com/shanapu/MyStore/commit/<COMMIT>
 */

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <clientprefs>

#include <mystore> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/mystore.inc

#include <colors> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/colors.inc
#include <smartdm> //https://forums.alliedmods.net/attachment.php?attachmentid=136152&d=1406298576

#pragma semicolon 1
#pragma newdecls required

char g_sModel[STORE_MAX_ITEMS][PLATFORM_MAX_PATH];
char g_sRun[STORE_MAX_ITEMS][64];
char g_sIdle[STORE_MAX_ITEMS][64];
float g_fPosition[STORE_MAX_ITEMS][3];
float g_fAngles[STORE_MAX_ITEMS][3];

char g_sChatPrefix[128];

ConVar gc_bEnable;

int g_iCount = 0;
int g_iClientPet[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};
int g_iSelectedPet[MAXPLAYERS + 1] = {-1,...};
int g_iLastAnimation[MAXPLAYERS + 1] = {-1,...};

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
	name = "MyStore - Pet item module",
	author = "shanapu", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "",
	version = "0.1.<BUILD>", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = "github.com/shanapu/MyStore"
};

public void OnPluginStart()
{
	if (MyStore_RegisterHandler("pet", Pets_OnMapStart, Pets_Reset, Pets_Config, Pets_Equip, Pets_Remove, true) == -1)
	{
		SetFailState("Can't Register module to core - Reached max module types(%i).", STORE_MAX_TYPES);
	}

	LoadTranslations("mystore.phrases");

	RegConsoleCmd("sm_hidepets", Command_Hide, "Hides the Pets");

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_team", Event_PlayerTeam);

	g_hHideCookie = RegClientCookie("Pets_Hide_Cookie", "Cookie to check if Pets are blocked", CookieAccess_Private);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!AreClientCookiesCached(i))
			continue;

		OnClientCookiesCached(i);
	}
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
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Item hidden", "pet");
		SetClientCookie(client, g_hHideCookie, "1");
	}
	else
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Item visible", "pet");
		SetClientCookie(client, g_hHideCookie, "0");
	}

	return Plugin_Handled;
}

public void Pets_OnMapStart()
{
	for (int i = 0; i < g_iCount; i++)
	{
		PrecacheModel(g_sModel[i], true);
		Downloader_AddFileToDownloadsTable(g_sModel[i]);
	}
}

public void Pets_Reset()
{
	g_iCount = 0;
}

public bool Pets_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, g_iCount);

	kv.GetString("model", g_sModel[g_iCount], PLATFORM_MAX_PATH);

	if (!FileExists(g_sModel[g_iCount], true))
	{
		MyStore_LogMessage(0, LOG_ERROR, "Can't find model %s.", g_sModel[g_iCount]);
		return false;
	}

	kv.GetString("idle", g_sIdle[g_iCount], 64);
	kv.GetString("run", g_sRun[g_iCount], 64);
	kv.GetVector("position", g_fPosition[g_iCount]);
	kv.GetVector("angles", g_fAngles[g_iCount]);

	g_iCount++;

	return true;
}

public int Pets_Equip(int client, int itemid)
{
	g_iSelectedPet[client] = MyStore_GetDataIndex(itemid);
	ResetPet(client);
	CreatePet(client);

	return ITEM_EQUIP_SUCCESS;
}

public int Pets_Remove(int client, int itemid)
{
	ResetPet(client);
	g_iSelectedPet[client] = -1;

	return ITEM_EQUIP_REMOVE;
}

public void OnClientConnected(int client)
{
	g_iSelectedPet[client] = -1;
	g_bHide[client] = false;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsPlayerAlive(client) || !(CS_TEAM_T <= GetClientTeam(client) <= CS_TEAM_CT))
		return;

	ResetPet(client);
	CreatePet(client);
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client)
		return;

	ResetPet(client);
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client)
		return;

	ResetPet(client);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (!gc_bEnable.BoolValue)
		return Plugin_Continue;

	if (!client || !IsClientInGame(client) || !IsPlayerAlive(client) || g_iClientPet[client] == INVALID_ENT_REFERENCE)
		return Plugin_Continue;

	if (tickcount % 5 == 0 && EntRefToEntIndex(g_iClientPet[client]) != -1)
	{
		float fVec[3];
		float fDist;
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fVec);
		fDist = GetVectorLength(fVec);
		if (g_iLastAnimation[client] != 1 && fDist > 0.0)
		{
			SetVariantString(g_sRun[g_iSelectedPet[client]]);
			AcceptEntityInput(EntRefToEntIndex(g_iClientPet[client]), "SetAnimation");

			g_iLastAnimation[client] = 1;
		}
		else if (g_iLastAnimation[client] != 2 && fDist == 0.0)
		{
			SetVariantString(g_sIdle[g_iSelectedPet[client]]);
			AcceptEntityInput(EntRefToEntIndex(g_iClientPet[client]), "SetAnimation");

			g_iLastAnimation[client] = 2;
		}
	}

	return Plugin_Continue;
}

void CreatePet(int client)
{
	if (!gc_bEnable.BoolValue)
		return;

	if (g_iClientPet[client] != INVALID_ENT_REFERENCE)
		return;

	if (g_iSelectedPet[client] == -1)
		return;

	if (!client || !IsClientInGame(client) || !IsPlayerAlive(client) || !(CS_TEAM_T <= GetClientTeam(client) <= CS_TEAM_CT))
		return;

	int iIndex = g_iSelectedPet[client];

	int iEntity = CreateEntityByName("prop_dynamic_override");
	if (IsValidEntity(iEntity))
	{
		float fPos[3];
		float fAng[3];
		float fOri[3];
		float flClientAngles[3];
		GetClientAbsOrigin(client, fOri);
		GetClientAbsAngles(client, flClientAngles);

		fPos[0] = g_fPosition[iIndex][0];
		fPos[1] = g_fPosition[iIndex][1];
		fPos[2] = g_fPosition[iIndex][2];
		fAng[0] = g_fAngles[iIndex][0];
		fAng[1] = g_fAngles[iIndex][1];
		fAng[2] = g_fAngles[iIndex][2];

		float fForward[3];
		float fRight[3];
		float fUp[3];
		GetAngleVectors(flClientAngles, fForward, fRight, fUp);

		fOri[0] += fRight[0] * fPos[0] + fForward[0] * fPos[1] + fUp[0] * fPos[2];
		fOri[1] += fRight[1] * fPos[0] + fForward[1] * fPos[1] + fUp[1] * fPos[2];
		fOri[2] += fRight[2] * fPos[0] + fForward[2] * fPos[1] + fUp[2] * fPos[2];
		fAng[1] += flClientAngles[1];

		DispatchKeyValue(iEntity, "model", g_sModel[iIndex]);
		DispatchKeyValue(iEntity, "spawnflags", "256");
		DispatchKeyValue(iEntity, "solid", "0");
		SetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity", client);

		DispatchSpawn(iEntity);
		AcceptEntityInput(iEntity, "TurnOn", iEntity, iEntity, 0);

		// Teleport the pet to the right fPosition and attach it
		TeleportEntity(iEntity, fOri, fAng, NULL_VECTOR); 

		SDKHook(client, SDKHook_PreThink, PetThink);
		g_iClientPet[client] = EntIndexToEntRef(iEntity);
		g_iLastAnimation[client] = -1;

		Set_EdictFlags(iEntity);

		SDKHook(iEntity, SDKHook_SetTransmit, Hook_SetTransmit);
	}
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

public void PetThink(int client)
{
	int iEntity = EntRefToEntIndex(g_iClientPet[client]);
	if (!IsValidEntity(iEntity))
	{
		SDKUnhook(client, SDKHook_PreThink, PetThink);
		return;
	}

	float pos[3];
	float ang[3];
	float clientPos[3];
	GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", pos);
	GetEntPropVector(iEntity, Prop_Data, "m_angRotation", ang);
	GetClientAbsOrigin(client, clientPos);

	float fDist = GetVectorDistance(clientPos, pos);
	float distX = clientPos[0] - pos[0];
	float distY = clientPos[1] - pos[1];
	float speed = (fDist - 64.0) / 54;
	Math_Clamp(speed, -4.0, 4.0);
	if (FloatAbs(speed) < 0.3)
		speed *= 0.1;

	// Teleport to owner if too far
	if (fDist > 1024.0)
	{
		float posTmp[3];
		GetClientAbsOrigin(client, posTmp);
		OffsetLocation(posTmp);
		TeleportEntity(iEntity, posTmp, NULL_VECTOR, NULL_VECTOR);
		GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", pos);
	}

	// Set new location data
	if (pos[0] < clientPos[0])pos[0] += speed;
	if (pos[0] > clientPos[0])pos[0] -= speed;
	if (pos[1] < clientPos[1])pos[1] += speed;
	if (pos[1] > clientPos[1])pos[1] -= speed;

	// Height
	int selectedPet = g_iSelectedPet[client];
	float petoff = g_fPosition[selectedPet][2];

	pos[2] = clientPos[2] + 100.0;
	float distZ = GetClientDistanceToGround(iEntity, client, pos[2]); 
	if (distZ < 300 && distZ > -300)
		pos[2] -= distZ;
	pos[2] += petoff;

	// Look at owner
	ang[1] = (ArcTangent2(distY, distX) * 180) / 3.14;

	TeleportEntity(iEntity, pos, ang, NULL_VECTOR);
}

void ResetPet(int client)
{
	if (g_iClientPet[client] == INVALID_ENT_REFERENCE)
		return;

	int iEntity = EntRefToEntIndex(g_iClientPet[client]);
	g_iClientPet[client] = INVALID_ENT_REFERENCE;
	if (iEntity == INVALID_ENT_REFERENCE)
		return;

	AcceptEntityInput(iEntity, "Kill");
	SDKUnhook(iEntity, SDKHook_SetTransmit, Hook_SetTransmit);
}

float GetClientDistanceToGround(int ent, int client, float pos2)
{
	float fOri[3];
	float fGround[3];
	GetEntPropVector(ent, Prop_Data, "m_vecOrigin", fOri);
	fOri[2] = pos2;
	fOri[2] += 100.0;
	float anglePos[3];
	anglePos[0] = 90.0;
	anglePos[1] = 0.0;
	anglePos[2] = 0.0;

	TR_TraceRayFilter(fOri, anglePos, MASK_PLAYERSOLID, RayType_Infinite, TraceRayNoPlayers, client);
	if (TR_DidHit()) {
		TR_GetEndPosition(fGround);
		fOri[2] -= 100.0;
		return GetVectorDistance(fOri, fGround);
	}

	return 0.0;
}

public bool TraceRayNoPlayers(int entity, int mask, any data)
{
	if (entity == data || (entity >= 1 && entity <= MaxClients))
	{
		return false;
	}

	return true;
}

void OffsetLocation(float pos[3])
{
	pos[0] += GetRandomFloat(-128.0, 128.0);
	pos[1] += GetRandomFloat(-128.0, 128.0);
}

any Math_Clamp(any value, any min, any max)
{
	value = Math_Min(value, min);
	value = Math_Max(value, max);

	return value;
}

any Math_Min(any value, any min)
{
	if (value < min)
	{
		value = min;
	}

	return value;
}

any Math_Max(any value, any max)
{
	if (value > max)
	{
		value = max;
	}

	return value;
}

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

	if (!StrEqual(type, "pet"))
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

	//Miku Green
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

		if (entity > 0 && IsValidEdict(entity))
		{
			SDKUnhook(entity, SDKHook_SetTransmit, Hook_SetTransmit_Preview);
			AcceptEntityInput(entity, "Kill");
		}
	}
	g_iPreviewEntity[client] = INVALID_ENT_REFERENCE;

	return Plugin_Stop;
}

//https://forums.alliedmods.net/showthread.php?p=2567245
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <mystore>

bool g_bEquipt[MAXPLAYERS + 1] = false;

ConVar gc_bEnable;

public void OnPluginStart()
{
	MyStore_RegisterHandler("dmgtext", _, _, DmgText_Config, DmgText_Equip, DmgText_Remove, true);
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
}

public bool DmgText_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, 0);

	return true;
}

public int DmgText_Equip(int client, int itemid)
{
	g_bEquipt[client] = true;

	return ITEM_EQUIP_SUCCESS;
}

public int DmgText_Remove(int client, int itemid)
{
	g_bEquipt[client] = false;

	return ITEM_EQUIP_REMOVE;
}

public void OnClientDisconnect(int client)
{
	g_bEquipt[client] = false;
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

public void OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], float damagePosition[3])
{
	if (!gc_bEnable.BoolValue)
		return;

	if (!IsValidClient(victim) || attacker == victim || !IsValidClient(attacker))
		return;

	if (!g_bEquipt[attacker])
		return;

	if (damage < 1)
		return;

	char sdamage[8];
	int idamage = RoundToZero(damage);
	IntToString(idamage, sdamage, sizeof(sdamage));

	if (damagetype == 8)
	{
		GetClientAbsOrigin(victim, damagePosition);
		damagePosition[0] += GetRandomFloat(-10.0, 10.0);
		damagePosition[1] += GetRandomFloat(-10.0, 10.0);
		damagePosition[2] += GetRandomFloat(60.0, 70.0);
	}

	ShowDamageText(attacker, victim, damagePosition, sdamage, !IsPlayerAlive(victim));
}

void ShowDamageText(int client, int victim, float pos[3], char[] damage, bool kill)
{
	int entity = CreateEntityByName("point_worldtext");
	if (entity == -1)
		return;

	float fDistance;
	char sSize[8];
	float angles[3];
	GetClientEyeAngles(client, angles);
	fDistance = GetDistance(client, victim);
	DispatchKeyValue(entity, "message", damage);

	float fSize = 0.0025 * fDistance * (kill ? 24.0 : 20.0);
	if (fSize < 5.5)
	{
		fSize = 5.5;
	}
	FloatToString(fSize, sSize, sizeof(sSize));

	DispatchKeyValue(entity, "textsize", sSize);
	DispatchKeyValue(entity, "color",  kill ? "255 0 0" : "255 255 255");

	SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);
	SetFlags(entity);

	SDKHook(entity, SDKHook_SetTransmit, SetTransmit);
	TeleportEntity(entity, pos, angles, NULL_VECTOR);

	CreateTimer(0.5, KillText, EntIndexToEntRef(entity));
}

public Action KillText(Handle timer, int ref)
{
	int entity = EntRefToEntIndex(ref);
	if (entity == INVALID_ENT_REFERENCE || !IsValidEntity(entity))
		return;

	SDKUnhook(entity, SDKHook_SetTransmit, SetTransmit);
	AcceptEntityInput(entity, "kill");
}

public Action SetTransmit(int entity, int client)
{
	SetFlags(entity);
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if (client == owner)
		return Plugin_Continue;

	return Plugin_Handled;
}

void SetFlags(int entity)
{
	if (GetEdictFlags(entity) & FL_EDICT_ALWAYS)
	{
		SetEdictFlags(entity, (GetEdictFlags(entity) ^ FL_EDICT_ALWAYS));
	}
}

float GetDistance(int entity, int target)
{
	float entityVec[3];
	float targetVec[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entityVec);
	GetEntPropVector(target, Prop_Send, "m_vecOrigin", targetVec);

	return GetVectorDistance(entityVec, targetVec);
}

bool IsValidClient(int client, bool bots = true, bool dead = true)
{
	if (client <= 0)
		return false;

	if (client > MaxClients)
		return false;

	if (!IsClientInGame(client))
		return false;

	if (IsFakeClient(client) && !bots)
		return false;

	if (IsClientSourceTV(client))
		return false;

	if (IsClientReplay(client))
		return false;

	if (!IsPlayerAlive(client) && !dead)
		return false;

	return true;
}
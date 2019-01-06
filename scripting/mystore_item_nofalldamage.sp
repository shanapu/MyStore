// https://github.com/Totenfluch/StammFeaturesForStore

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
	MyStore_RegisterHandler("nofalldamage", _, _, NoFallDamage_Config, NoFallDamage_Equip, NoFallDamage_Remove, true);
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
}

public bool NoFallDamage_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, 0);

	return true;
}

public int NoFallDamage_Equip(int client, int itemid)
{
	g_bEquipt[client] = true;

	return ITEM_EQUIP_SUCCESS;
}

public int  NoFallDamage_Remove(int client, int itemid)
{
	g_bEquipt[client] = false;

	return ITEM_EQUIP_REMOVE;
}

public void OnClientPutInServer(int client)
{
	if (IsValidClient(client))
	{
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}

public void OnClientDisconnect(int client)
{
	if (IsValidClient(client))
	{
		SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	}

	g_bEquipt[client] = false;
}

public Action OnTakeDamage(int client, int &attacker, int &inflictor, float &damage, int &damagetype, int &bweapon, float damageForce[3], const float damagePosition[3])
{
	if (!gc_bEnable.BoolValue)
		return Plugin_Continue;

	if (!g_bEquipt[client])
		return Plugin_Continue;

	if (IsValidClient(client))
	{
		if ((GetClientTeam(client) == 2 || GetClientTeam(client) == 3) && IsPlayerAlive(client))
		{
			if (damagetype & DMG_FALL)
				return Plugin_Handled;
		}
	}

	return Plugin_Continue;
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
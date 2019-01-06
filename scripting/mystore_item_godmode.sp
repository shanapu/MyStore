#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <colors>
#include <mystore>

char g_sChatPrefix[128];

float g_fDuration[STORE_MAX_ITEMS];

int g_iRoundLimit[MAXPLAYERS + 1][STORE_MAX_ITEMS / 2];
int g_iLimit[STORE_MAX_ITEMS];
int g_iTeam[STORE_MAX_ITEMS];
int g_iCount = 0;

public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");

	MyStore_RegisterHandler("godmode", _, Godmode_Reset, Godmode_Config, Godmode_Equip, _, false);

	HookEvent("player_spawn", Event_OnPlayerSpawn);
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

public void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!client)
		return;

	for (int i = 0; i <= g_iCount; i++)
	{
		g_iRoundLimit[client][i] = 0;
	}
}

public void Godmode_Reset()
{
	g_iCount = 0;
}

public bool Godmode_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, g_iCount);

	g_fDuration[g_iCount] = kv.GetFloat("duration");
	g_iLimit[g_iCount] = kv.GetNum("limit");
	g_iTeam[g_iCount] = kv.GetNum("team", 0);

	g_iCount++;

	return true;
}

public int Godmode_Equip(int client, int itemid)
{
	int iIndex = MyStore_GetDataIndex(itemid);

	if (0 < g_iLimit[iIndex] <= g_iRoundLimit[client][iIndex])
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Round Limit");
		return ITEM_EQUIP_FAIL;
	}

	if (0 < g_iTeam[g_iCount] && g_iTeam[g_iCount] != GetClientTeam(client) - 1)
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Wrong Team");
		return ITEM_EQUIP_FAIL;
	}

	if (!IsPlayerAlive(client))
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Must be Alive");
		return ITEM_EQUIP_FAIL;
	}

	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	CreateTimer(g_fDuration[iIndex], Timer_RemoveGodmode, GetClientUserId(client));

	g_iRoundLimit[client][iIndex]++;

	return ITEM_EQUIP_REMOVE;
}

public Action Timer_RemoveGodmode(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!client)
		return Plugin_Stop;

	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);

	return Plugin_Stop;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	damage = 0.0;

	return Plugin_Changed;
}
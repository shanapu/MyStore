#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>

#include <colors>
#include <mystore>

char g_sChatPrefix[128];

int g_iRoundLimit[MAXPLAYERS + 1] = {0,...};
int g_iLimit = 0;

public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");

	MyStore_RegisterHandler("respawn", _, _, Respawn_Config, Respawn_Equip, _, false);

	HookEvent("player_spawn", Event_PlayerSpawn);
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

public void Event_PlayerSpawn(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client)
		return;

	g_iRoundLimit[client] = 0;
}

public bool Respawn_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, 0);

	g_iLimit = kv.GetNum("limit");

	return true;
}

public int Respawn_Equip(int client, int itemid)
{
	if (IsPlayerAlive(client))
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Must Dead");
		return ITEM_EQUIP_FAIL;
	}

	if (0 < g_iLimit <= g_iRoundLimit[client])
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Round Limit");
		return ITEM_EQUIP_FAIL;
	}

	CS_RespawnPlayer(client);

	g_iRoundLimit[client]++;

	return ITEM_EQUIP_REMOVE;
}
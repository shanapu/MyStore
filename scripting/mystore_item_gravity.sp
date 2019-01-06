#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#include <mystore>

#include <colors>

char g_sChatPrefix[128];

int g_iGravity[STORE_MAX_ITEMS];
int g_iLimit[STORE_MAX_ITEMS];
int g_iRoundLimit[MAXPLAYERS + 1] = {0,...};
int g_iCount = 0;

float g_fGravityTime[STORE_MAX_ITEMS];

public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");

	MyStore_RegisterHandler("gravity", _, Gravity_Reset, Gravity_Config, Gravity_Equip, _, false);

	HookEvent("player_spawn", Events_OnPlayerSpawn);
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

public void Events_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!client)
		return;

	g_iRoundLimit[client] = 0;
}

public void Gravity_Reset()
{
	g_iCount = 0;
}

public bool Gravity_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, g_iCount);

	g_iGravity[g_iCount] = kv.GetNum("gravity");
	g_fGravityTime[g_iCount] = kv.GetFloat("duration");
	g_iLimit[g_iCount] = kv.GetNum("limit");

	g_iCount++;

	return true;
}

public int Gravity_Equip(int client, int itemid)
{
	int iIndex = MyStore_GetDataIndex(itemid);

	if (0 < g_iLimit[iIndex] <= g_iRoundLimit[client])
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Round Limit");
		return ITEM_EQUIP_FAIL;
	}

	if (!IsPlayerAlive(client))
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Must be Alive");
		return ITEM_EQUIP_FAIL;
	}

	ConVar hGravity = FindConVar("sv_gravity");

	if (hGravity.IntValue == 0)
	{
		SetEntityGravity(client, 0.0);
	}
	else
	{
		SetEntityGravity(client, view_as<float>(g_iGravity[iIndex]) / hGravity.IntValue);
	}

	if (g_fGravityTime[iIndex] != 0.0)
	{
		CreateTimer(g_fGravityTime[iIndex], Timer_RemoveGravity, GetClientUserId(client));
	}

	return ITEM_EQUIP_REMOVE;
}

public Action Timer_RemoveGravity(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!client || !IsClientInGame(client))
		return Plugin_Stop;

	SetEntityGravity(client, 1.0);

	return Plugin_Stop;
}
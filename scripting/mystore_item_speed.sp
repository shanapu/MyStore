#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#include <colors>
#include <mystore>

char g_sChatPrefix[128];

float g_fSpeed[STORE_MAX_ITEMS];
float g_fSpeedTime[STORE_MAX_ITEMS];

int g_iCount = 0;
int g_iSpeedLimit[STORE_MAX_ITEMS];
int g_iRoundLimit[MAXPLAYERS + 1][STORE_MAX_ITEMS / 2];

public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");

	MyStore_RegisterHandler("speed", Speed_OnMapStart, Speed_Reset, Speed_Config, Speed_Equip, _, false);

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

public void Speed_OnMapStart()
{
	PrecacheSound("player/suit_sprint.wav", true);
}

public void Speed_Reset()
{
	g_iCount = 0;
}

public bool Speed_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, g_iCount);

	g_fSpeed[g_iCount] = kv.GetFloat("speed");
	g_fSpeedTime[g_iCount] = kv.GetFloat("duration");
	g_iSpeedLimit[g_iCount] = kv.GetNum("limit");

	g_iCount++;

	return true;
}

public int Speed_Equip(int client, int itemid)
{
	int iIndex = MyStore_GetDataIndex(itemid);

	if (0 < g_iRoundLimit[client][iIndex] >= g_iSpeedLimit[iIndex])
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Round Limit");
		return ITEM_EQUIP_FAIL;
	}

	if (!IsPlayerAlive(client))
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Must be Alive");
		return ITEM_EQUIP_FAIL;
	}

	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_fSpeed[iIndex]);
	EmitSoundToClient(client, "player/suit_sprint.wav", SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.8);

	if (g_fSpeedTime[iIndex] != 0.0)
	{
		CreateTimer(g_fSpeedTime[iIndex], Timer_RemoveSpeed, GetClientUserId(client));
	}

	g_iRoundLimit[client][iIndex]++;

	return ITEM_EQUIP_REMOVE;
}

public Action Timer_RemoveSpeed(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!client || !IsClientInGame(client))
		return Plugin_Stop;

	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);

	return Plugin_Stop;
}
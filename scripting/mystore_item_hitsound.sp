// https://forums.alliedmods.net/showthread.php?p=1965643

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <mystore>

#include <autoexecconfig>

ConVar gc_bEnable;

bool g_bEquipt[MAXPLAYERS + 1] = false;


public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");

	
	AutoExecConfig_SetFile("items", "MyStore");
	AutoExecConfig_SetCreateFile(true);

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	MyStore_RegisterHandler("hitsound", _, _, Hitsound_Config, Hitsound_Equip, _, true);
}


public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
}

public bool Hitsound_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, 0);

	return true;
}

public int Hitsound_Equip(int client, int itemid)
{
	g_bEquipt[client] = true;

	return ITEM_EQUIP_SUCCESS;
}

public int Hitsound_Remove(int client, int itemid)
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

//	if (damagetype == 8)
//		return;

	ClientCommand(attacker, "playgamesound training/bell_normal.wav");
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
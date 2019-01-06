#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#include <mystore>

bool g_bEquipt[MAXPLAYERS + 1] = false;

ConVar gc_bEnable;

public void OnPluginStart()
{
	MyStore_RegisterHandler("bulletsparks", _, _, BulletSparks_Config, BulletSparks_Equip, BulletSparks_Remove, true);

	HookEvent("bullet_impact", Event_BulletImpact);
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
}

public bool BulletSparks_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, 0);

	return true;
}

public int BulletSparks_Equip(int client, int itemid)
{
	g_bEquipt[client] = true;

	return ITEM_EQUIP_SUCCESS;
}

public int  BulletSparks_Remove(int client, int itemid)
{
	g_bEquipt[client] = false;

	return ITEM_EQUIP_REMOVE;
}

public void OnClientDisconnect(int client)
{
	g_bEquipt[client] = false;
}

public void Event_BulletImpact(Event event, char[] sName, bool bDontBroadcast)
{
	if (!gc_bEnable.BoolValue)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!client)
		return;

	if (!g_bEquipt[client])
		return;

	float startpos[3];
	float dir[3] = {0.0, 0.0, 0.0};

	startpos[0] = event.GetFloat("x");
	startpos[1] = event.GetFloat("y");
	startpos[2] = event.GetFloat("z");

	TE_SetupSparks(startpos, dir, 2500, 5000);

	TE_SendToAll();
}
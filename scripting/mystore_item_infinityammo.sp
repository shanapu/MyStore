#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#include <mystore>

#include <autoexecconfig>

bool g_bEquipt[MAXPLAYERS + 1] = false;

ConVar gc_bEnable;
ConVar gc_bType;

public void OnPluginStart()
{
	AutoExecConfig_SetFile("item", "MyStore");
	AutoExecConfig_SetCreateFile(true);

	gc_bType = AutoExecConfig_CreateConVar("mystore_infinityammo_type", "1", "0 - infinityammo with reload clips, 1 - infinityammo without reload", _, true, 0.0, true, 1.0);

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	MyStore_RegisterHandler("infinityammo", _, _, InfinityAmmo_Config, InfinityAmmo_Equip, InfinityAmmo_Remove, true);

	HookEvent("weapon_fire", Event_WeaponFire);
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
}

public bool InfinityAmmo_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, 0);

	return true;
}

public int InfinityAmmo_Equip(int client, int itemid)
{
	g_bEquipt[client] = true;

	return ITEM_EQUIP_SUCCESS;
}

public int InfinityAmmo_Remove(int client, int itemid)
{
	g_bEquipt[client] = false;

	return ITEM_EQUIP_REMOVE;
}

public void OnClientDisconnect(int client)
{
	g_bEquipt[client] = false;
}

public void Event_WeaponFire(Event event, char[] name, bool dontBroadcast)
{
	if (!gc_bEnable.BoolValue)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!g_bEquipt[client])
		return;

	char weapons[64];
	int weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	GetEntityClassname(weapon, weapons, sizeof(weapons));

	if (!gc_bType.BoolValue)
	{
		int ammo = GetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount");
		SetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount", ammo);
	}
	else
	{
		SetEntProp(weapon, Prop_Send, "m_iClip1", GetEntProp(weapon, Prop_Data, "m_iClip1") + 1);
	}
}
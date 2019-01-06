#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#include <mystore>

bool g_bEquipt[MAXPLAYERS + 1] = false;

ConVar gc_bEnable;

public void OnPluginStart()
{
	MyStore_RegisterHandler("noreload", _, _, NoReload_Config, NoReload_Equip, NoReload_Remove, true);

	HookEvent("weapon_fire", Event_WeaponFire);
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
}

public bool NoReload_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, 0);

	return true;
}

public int NoReload_Equip(int client, int itemid)
{
	g_bEquipt[client] = true;

	return ITEM_EQUIP_SUCCESS;
}

public int  NoReload_Remove(int client, int itemid)
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

	int clip = GetEntProp(weapon, Prop_Data, "m_iClip1");
	int ammo = GetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount");

	if (clip > 3)
		return;

	if (ammo < 1)
		return;

	SetEntProp(weapon, Prop_Send, "m_iClip1", 4);

	int newAmmo = ammo - (4 - clip);

	if (newAmmo <= 0)
	{
		newAmmo = 0;
	}

	SetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount", newAmmo);
}

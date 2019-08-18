/*
 * MyStore - No reload item module
 * by: shanapu
 * https://github.com/shanapu/
 * 
 * Copyright (C) 2018-2019 Thomas Schmidt (shanapu)
 * Credits: dordnung - https://forums.alliedmods.net/showthread.php?p=1338942
 * Contributer:
 *
 * Original development by Zephyrus - https://github.com/dvarnai/store-plugin
 *
 * Love goes out to the sourcemod team and all other plugin developers!
 * THANKS FOR MAKING FREE SOFTWARE!
 *
 * This file is part of the MyStore SourceMod Plugin.
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <http://www.gnu.org/licenses/>.
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#include <mystore> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/mystore.inc

bool g_bEquipt[MAXPLAYERS + 1] = false;

ConVar gc_bEnable;

/*
 * Build date: <DATE>
 * Build number: <BUILD>
 * Commit: https://github.com/shanapu/MyStore/commit/<COMMIT>
 */

public Plugin myinfo = 
{
	name = "MyStore - No reload item module",
	author = "shanapu", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "",
	version = "0.1.<BUILD>", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = "github.com/shanapu/MyStore"
};

public void OnPluginStart()
{
	if (MyStore_RegisterHandler("noreload", _, _, NoReload_Config, NoReload_Equip, NoReload_Remove, true) == -1)
	{
		SetFailState("Can't Register module to core - Reached max module types(%i).", STORE_MAX_TYPES);
	}

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

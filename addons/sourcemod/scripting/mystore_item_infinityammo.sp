/*
 * MyStore - Infinity Ammo item module
 * by: shanapu
 * https://github.com/shanapu/
 * 
 * Copyright (C) 2018-2019 Thomas Schmidt (shanapu)
 * Credits:
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

#include <autoexecconfig> //https://raw.githubusercontent.com/Impact123/AutoExecConfig/development/autoexecconfig.inc

bool g_bEquipt[MAXPLAYERS + 1] = false;

ConVar gc_bEnable;
ConVar gc_bType;

/*
 * Build date: <DATE>
 * Build number: <BUILD>
 * Commit: https://github.com/shanapu/MyStore/commit/<COMMIT>
 */

public Plugin myinfo = 
{
	name = "MyStore - Infinity Ammo item module",
	author = "shanapu",
	description = "",
	version = "0.1.<BUILD>",
	url = "github.com/shanapu/MyStore"
};

public void OnPluginStart()
{
	AutoExecConfig_SetFile("items", "sourcemod/mystore");
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
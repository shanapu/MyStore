/*
 * MyStore - Instand plant/defuse bomb item module
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

#include <autoexecconfig> //https://raw.githubusercontent.com/Impact123/AutoExecConfig/development/autoexecconfig.inc

bool g_bEquipt[MAXPLAYERS + 1] = false;

ConVar gc_bEnable;
ConVar gc_iType;

public void OnPluginStart()
{
	MyStore_RegisterHandler("instabomb", _, _, InstaBomb_Config, InstaBomb_Equip, InstaBomb_Remove, true);

	AutoExecConfig_SetFile("items", "sourcemod/MyStore");
	AutoExecConfig_SetCreateFile(true);

	gc_iType = AutoExecConfig_CreateConVar("mystore_instabomb_type", "2", "1 - instadefuse only / 2 - instadefuse & instaplant / 3 - instaplant only", _, true, 1.0, true, 3.0);

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	HookEvent("bomb_begindefuse", Event_Defuse);
	HookEvent("bomb_beginplant", Event_Plant);
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
}

public bool InstaBomb_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, 0);

	return true;
}

public int InstaBomb_Equip(int client, int itemid)
{
	g_bEquipt[client] = true;

	return ITEM_EQUIP_SUCCESS;
}

public int  InstaBomb_Remove(int client, int itemid)
{
	g_bEquipt[client] = false;

	return ITEM_EQUIP_REMOVE;
}

public void OnClientDisconnect(int client)
{
	g_bEquipt[client] = false;
}

public void Event_Defuse(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!g_bEquipt[client])
		return;

	if (!gc_bEnable.BoolValue || gc_iType.IntValue == 3)
		return;

	CreateTimer(0.1, Timer_Defuse);
}

public Action Timer_Defuse(Handle timer)
{
	int bomb = FindEntityByClassname(-1, "planted_c4");
	if (!bomb)
		return Plugin_Handled;

	SetEntPropFloat(bomb, Prop_Send, "m_flDefuseCountDown", GetGameTime());

	return Plugin_Handled;
}

public void Event_Plant(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!g_bEquipt[client])
		return;

	if (!gc_bEnable.BoolValue || gc_iType.IntValue == 1)
		return;

	CreateTimer(0.1, Timer_Plant, GetClientUserId(client));
}

public Action Timer_Plant(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!client)
		return Plugin_Handled;

	int bomb = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	char sBuffer[16];
	GetEntityClassname(bomb, sBuffer, sizeof(sBuffer));

	if (!StrEqual(sBuffer, "weapon_c4"))
		return Plugin_Handled;

	SetEntPropFloat(bomb, Prop_Send, "m_fArmedTime", GetGameTime());

	return Plugin_Handled;
}
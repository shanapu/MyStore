/*
 * MyStore - Perspective item module
 * by: shanapu
 * https://github.com/shanapu/
 * 
 * Copyright (C) 2018-2019 Thomas Schmidt (shanapu)
 * Credits: Franc1sco - https://github.com/Franc1sco/Thirdperson-and-mirror-view
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

bool g_bEquiptMirror[MAXPLAYERS + 1] = false;
bool g_bEquiptTP[MAXPLAYERS + 1] = false;

ConVar gc_bEnable;
ConVar mp_forcecamera;
ConVar sv_allow_thirdperson;

/*
 * Build date: <DATE>
 * Build number: <BUILD>
 * Commit: https://github.com/shanapu/MyStore/commit/<COMMIT>
 */

public Plugin myinfo = 
{
	name = "MyStore - Perspective item module",
	author = "shanapu", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "",
	version = "0.1.<BUILD>", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = "github.com/shanapu/MyStore"
};

public void OnPluginStart()
{
	if (MyStore_RegisterHandler("mirror", _, _, Mirror_Config, Mirror_Equip, Mirror_Remove, true) == -1)
	{
		SetFailState("Can't Register module to core - Reached max module types(%i).", STORE_MAX_TYPES);
	}

	if (MyStore_RegisterHandler("thirdperson", _, _, ThirdPerson_Config, ThirdPerson_Equip, ThirdPerson_Remove, true) == -1)
	{
		MyStore_LogMessage(_, LOG_ERROR, "Can't Register module to core - Reached max module types(%i).", STORE_MAX_TYPES);
	}

	mp_forcecamera = FindConVar("mp_forcecamera");

	sv_allow_thirdperson = FindConVar("sv_allow_thirdperson");

	sv_allow_thirdperson.AddChangeHook(OnSettingChanged);

	HookEvent("player_spawn", Event_PlayerSpawn);
}


public void OnSettingChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == sv_allow_thirdperson)
	{
		if (sv_allow_thirdperson.IntValue != 1)
		{
			sv_allow_thirdperson.IntValue = 1;
		}
	}
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;

	sv_allow_thirdperson.IntValue = 1;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!gc_bEnable.BoolValue)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!g_bEquiptMirror[client] && !g_bEquiptTP[client])
		return;

	if (!client || !IsPlayerAlive(client))
		return;

	if (g_bEquiptMirror[client])
	{
		SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", 0); 
		SetEntProp(client, Prop_Send, "m_iObserverMode", 1);
		SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 0);
		SetEntProp(client, Prop_Send, "m_iFOV", 120);
		SendConVarValue(client, mp_forcecamera, "1");
	}

	if (!g_bEquiptTP[client])
		return;

	ClientCommand(client, "thirdperson");
}

public bool Mirror_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, 0);

	return true;
}

public bool ThirdPerson_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, 0);

	return true;
}

public int Mirror_Equip(int client, int itemid)
{
	SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", 0);
	SetEntProp(client, Prop_Send, "m_iObserverMode", 1);
	SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 0);
	SetEntProp(client, Prop_Send, "m_iFOV", 120);
	SendConVarValue(client, mp_forcecamera, "1");

	return ITEM_EQUIP_SUCCESS;
}

public int ThirdPerson_Equip(int client, int itemid)
{
	ClientCommand(client, "thirdperson");

	return ITEM_EQUIP_SUCCESS;
}


public int Mirror_Remove(int client, int itemid)
{
	SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", -1);
	SetEntProp(client, Prop_Send, "m_iObserverMode", 0);
	SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);
	SetEntProp(client, Prop_Send, "m_iFOV", 90);
	char sBuffer[6];
	Format(sBuffer, sizeof(sBuffer), "%i", mp_forcecamera.IntValue);
	mp_forcecamera.ReplicateToClient(client, sBuffer);

	return ITEM_EQUIP_REMOVE;
}

public int ThirdPerson_Remove(int client, int itemid)
{
	g_bEquiptTP[client] = false;
	ClientCommand(client, "firstperson");

	return ITEM_EQUIP_REMOVE;
}

public void OnClientDisconnect(int client)
{
	ClientCommand(client, "firstperson");
	g_bEquiptTP[client] = false;
	g_bEquiptMirror[client] = false;
}

public void OnPluginEnd()
{
	// Save all client data
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		if (!g_bEquiptTP[i])
			continue;

		ClientCommand(i, "firstperson");
	}
}
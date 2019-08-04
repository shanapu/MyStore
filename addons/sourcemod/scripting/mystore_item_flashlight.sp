/*
 * MyStore - Flashlight item module
 * by: shanapu
 * https://github.com/shanapu/
 * 
 * Copyright (C) 2018-2019 Thomas Schmidt (shanapu)
 * Credits: Mitchell - https://forums.alliedmods.net/showthread.php?p=2042310
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

ConVar gc_bEnable;
ConVar bSnd;

bool g_bEquipt[MAXPLAYERS + 1] = false;

/*
 * Build date: <DATE>
 * Build number: <BUILD>
 * Commit: https://github.com/shanapu/MyStore/commit/<COMMIT>
 */

public Plugin myinfo = 
{
	name = "MyStore - Flashlight item module",
	author = "shanapu",
	description = "",
	version = "0.1.<BUILD>",
	url = "github.com/shanapu/MyStore"
};

public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");

	AddCommandListener(Command_LAW, "+lookatweapon");
	RegConsoleCmd("sm_flashlight", Command_FlashLight);

	AutoExecConfig_SetFile("items", "sourcemod/MyStore");
	AutoExecConfig_SetCreateFile(true);

	bSnd = AutoExecConfig_CreateConVar("mystore_flashlight_sound", "1", "Enable sound when a player uses the flash light.", _, true, 0.0, true, 1.0);

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	MyStore_RegisterHandler("flashlight", Flashlight_OnMapStart, _, Flashlight_Config, Flashlight_Equip, _, true);
}

public void Flashlight_OnMapStart()
{
	PrecacheSound("items/flashlight1.wav", true);
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
}

public bool Flashlight_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, 0);

	return true;
}

public int Flashlight_Equip(int client, int itemid)
{
	g_bEquipt[client] = true;

	return ITEM_EQUIP_SUCCESS;
}

public int Flashlight_Remove(int client, int itemid)
{
	g_bEquipt[client] = false;

	return ITEM_EQUIP_REMOVE;
}

public void OnClientDisconnect(int client)
{
	g_bEquipt[client] = false;
}

public Action Command_FlashLight(int client, int args)
{
	if (!gc_bEnable.BoolValue)
		return Plugin_Handled;

	if (!IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Handled;

	ToggleFlashlight(client);

	return Plugin_Handled;
}

public Action Command_LAW(int client, const char[] command, int args)
{
	if (!gc_bEnable.BoolValue)
		return Plugin_Continue;

	if (!IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Continue;

	ToggleFlashlight(client);

	return Plugin_Continue;
}

void ToggleFlashlight(int client)
{
	SetEntProp(client, Prop_Send, "m_fEffects", GetEntProp(client, Prop_Send, "m_fEffects") ^ 4);

	if (!bSnd.BoolValue)
		return;

	EmitSoundToClient(client, "items/flashlight1.wav");
}
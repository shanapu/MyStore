/*
 * MyStore - Deathsound item module
 * by: shanapu
 * https://github.com/shanapu/
 * 
 * Copyright (C) 2018-2019 Thomas Schmidt (shanapu)
 * Credits: Kxnrl - https://github.com/shanapu/StoreDeathsound/pull/2
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

#include <sourcemod>
#include <sdktools>

#include <colors> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/colors.inc

#include <mystore> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/mystore.inc

#pragma semicolon 1
#pragma newdecls required


char g_sSound[STORE_MAX_ITEMS][PLATFORM_MAX_PATH];
int g_iOrigin[STORE_MAX_ITEMS];
float g_fVolume[STORE_MAX_ITEMS];
bool g_bBlock[STORE_MAX_ITEMS];

bool g_bEquipt[MAXPLAYERS + 1] = false;

ConVar gc_bEnable;

int g_iCount = 0;
int g_iEquipped[MAXPLAYERS + 1];
char g_sChatPrefix[64];

/*
 * Build date: <DATE>
 * Build number: <BUILD>
 * Commit: https://github.com/shanapu/MyStore/commit/<COMMIT>
 */

public Plugin myinfo = 
{
	name = "MyStore - Deathsound item module",
	author = "shanapu", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "",
	version = "0.1.<BUILD>", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = "github.com/shanapu/MyStore"
};

public void OnPluginStart()
{
	if (MyStore_RegisterHandler("death_sound", DeathSound_OnMapStart, DeathSound_Reset, DeathSound_Config, DeathSound_Equip, DeathSound_Remove, true) == -1)
	{
		SetFailState("Can't Register module to core - Reached max module types(%i).", STORE_MAX_TYPES);
	}

	LoadTranslations("mystore.phrases");

	HookEvent("player_death", Event_PlayerDeath);
	AddNormalSoundHook(Hook_NormalSound);
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

public void DeathSound_OnMapStart()
{
	char sBuffer[256];

	for (int i = 0; i < g_iCount; i++)
	{
		PrecacheSound(g_sSound[i]);
		FormatEx(sBuffer, sizeof(sBuffer), "sound/%s", g_sSound[i]);
		AddFileToDownloadsTable(sBuffer);
	}
}

public void DeathSound_Reset()
{
	g_iCount = 0;
}

public bool DeathSound_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, g_iCount);

	kv.GetString("sound", g_sSound[g_iCount], PLATFORM_MAX_PATH);

	char sBuffer[256];
	FormatEx(sBuffer, sizeof(sBuffer), "sound/%s", g_sSound[g_iCount]);

	if (!FileExists(sBuffer, true))
	{
		MyStore_LogMessage(0, LOG_ERROR, "Can't find sound %s.", g_sSound[g_iCount]);
		return false;
	}

	g_iOrigin[g_iCount] = kv.GetNum("origin", 2);
	g_fVolume[g_iCount] = kv.GetFloat("volume", 1.0);
	g_bBlock[g_iCount] = view_as<bool>(kv.GetNum("block", 1));

	if (g_fVolume[g_iCount] > 1.0)
	{
		g_fVolume[g_iCount] = 1.0;
	}
	else if (g_fVolume[g_iCount] <= 0.0)
	{
		g_fVolume[g_iCount] = 0.05;
	}

	g_iCount++;

	return true;
}

public int DeathSound_Equip(int client, int itemid)
{
	g_iEquipped[client] = MyStore_GetDataIndex(itemid);
	g_bEquipt[client] = true;

	return ITEM_EQUIP_SUCCESS;
}

public int DeathSound_Remove(int client, int itemid)
{
	g_bEquipt[client] = false;

	return ITEM_EQUIP_SUCCESS;
}

public void OnClientDisconnect(int client)
{
	g_bEquipt[client] = false;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!gc_bEnable.BoolValue)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));

	if (!g_bEquipt[client])
		return;

	if (client == attacker)
		return;

	switch (g_iOrigin[g_iEquipped[client]])
	{
		// Sound From global world
		case 1:
		{
			EmitSoundToAll(g_sSound[g_iEquipped[client]], SOUND_FROM_WORLD, _, SNDLEVEL_RAIDSIREN, _, g_fVolume[g_iEquipped[client]]);
		}
		// Sound From local player
		case 2:
		{
			float fVec[3];
			GetClientAbsOrigin(client, fVec);
			EmitAmbientSound(g_sSound[g_iEquipped[client]], fVec, SOUND_FROM_PLAYER, SNDLEVEL_RAIDSIREN, _, g_fVolume[g_iEquipped[client]]);
		}
		// Sound From player voice
		case 3:
		{
			float fPos[3], fAgl[3];
			GetClientEyePosition(client, fPos);
			GetClientEyeAngles(client, fAgl);

			// player`s mouth
			fPos[2] -= 3.0;

			EmitSoundToAll(g_sSound[g_iEquipped[client]], client, SNDCHAN_VOICE, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fVolume[g_iEquipped[client]], SNDPITCH_NORMAL, client, fPos, fAgl, true);
		}
	}
}

public Action Hook_NormalSound(int clients[64], int &numClients, char sample[PLATFORM_MAX_PATH], int &client, int &channel, float &volume, int &level, int &pitch, int &flags)
{
	if (channel != SNDCHAN_VOICE || client > MaxClients || client < 1 || !IsClientInGame(client) || sample[0] != '~' || !g_bEquipt[client])
		return Plugin_Continue;

	if (g_bBlock[g_iEquipped[client]] && StrContains(sample, "~player/death", false) == 0)
		return Plugin_Handled;

	return Plugin_Continue;
}

public void MyStore_OnPreviewItem(int client, char[] type, int index)
{
	if (!StrEqual(type, "death_sound"))
		return;

	EmitSoundToClient(client, g_sSound[index], client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fVolume[index] / 2);

	CPrintToChat(client, "%s%t", g_sChatPrefix, "Play Preview", client);
}
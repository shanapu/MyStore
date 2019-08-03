/*
 * MyStore - Sound item module
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

#include <sourcemod>
#include <sdktools>

#include <colors> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/colors.inc
#include <mystore> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/mystore.inc

#include <smartdm> //https://forums.alliedmods.net/attachment.php?attachmentid=136152&d=1406298576

#pragma semicolon 1
#pragma newdecls required

char g_sSound[STORE_MAX_ITEMS][PLATFORM_MAX_PATH];
char g_sTrigger[STORE_MAX_ITEMS][64];
int g_unPrice[STORE_MAX_ITEMS];
int g_iCooldown[STORE_MAX_ITEMS];
int g_iOrigin[STORE_MAX_ITEMS];
float g_fVolume[STORE_MAX_ITEMS];
int g_iPerm[STORE_MAX_ITEMS];
int g_iItemId[STORE_MAX_ITEMS];
int g_iFlagBits[STORE_MAX_ITEMS];

char g_sChatPrefix[128];
char g_sCreditsName[64];

ConVar gc_bEnable;

int g_iCount = 0;
int g_iSpam[MAXPLAYERS + 1] = {0,...};

public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");

	MyStore_RegisterHandler("sound", Sounds_OnMapStart, Sounds_Reset, Sounds_Config, Sounds_Equip, Sounds_Remove, false);

	HookEvent("player_say", Event_PlayerSay);
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
	strcopy(g_sCreditsName, sizeof(g_sCreditsName), credits);
}

public void Sounds_OnMapStart()
{
	char sBuffer[256];

	for (int i = 0; i < g_iCount; i++)
	{
		PrecacheSound(g_sSound[i], true);
		FormatEx(sBuffer, sizeof(sBuffer), "sound/%s", g_sSound[i]);
		AddFileToDownloadsTable(sBuffer);
	}
}

public void Sounds_Reset()
{
	g_iCount = 0;
}

public bool Sounds_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, g_iCount);

	kv.GetString("sound", g_sSound[g_iCount], PLATFORM_MAX_PATH);

	char sBuffer[256];
	FormatEx(sBuffer, sizeof(sBuffer), "sound/%s", g_sSound[g_iCount]);

	if (!FileExists(sBuffer, true))
	{
		MyStore_LogMessage(0, LOG_ERROR, "Can't find sound %s.", sBuffer);
		return false;
	}

	kv.GetString("trigger", g_sTrigger[g_iCount], 64);
	g_iPerm[g_iCount] = kv.GetNum("perm", 0);
	g_iCooldown[g_iCount] = kv.GetNum("cooldown", 30);
	g_fVolume[g_iCount] = kv.GetFloat("volume", 0.5);
	g_iOrigin[g_iCount] = kv.GetNum("origin", 1);
	g_unPrice[g_iCount] = kv.GetNum("price");
	g_iItemId[g_iCount] = itemid;

	kv.GetString("flag", sBuffer, sizeof(sBuffer));
	g_iFlagBits[g_iCount] = ReadFlagString(sBuffer);

	if (g_iCooldown[g_iCount] < 10)
	{
		g_iCooldown[g_iCount] = 10;
	}

	if (g_fVolume[g_iCount] > 1.0)
	{
		g_fVolume[g_iCount] = 1.0;
	}

	if (g_fVolume[g_iCount] <= 0.0)
	{
		g_fVolume[g_iCount] = 0.05;
	}

	g_iCount++;

	return true;
}

public int Sounds_Equip(int client, int itemid)
{
	int iIndex = MyStore_GetDataIndex(itemid);

	if (g_iSpam[client] > GetTime())
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Spam Cooldown", g_iSpam[client] - GetTime());
		return ITEM_EQUIP_FAIL;
	}

	if (!IsPlayerAlive(client) && g_iOrigin[iIndex] > 1)
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Must be Alive");
		return ITEM_EQUIP_FAIL;
	}

	switch (g_iOrigin[iIndex])
	{
		// Sound From global world
		case 1:
		{
			EmitSoundToAll(g_sSound[iIndex], SOUND_FROM_WORLD, _, SNDLEVEL_RAIDSIREN, _, g_fVolume[iIndex]);
		}
		// Sound From local player
		case 2:
		{
			float fVec[3];
			GetClientAbsOrigin(client, fVec);
			EmitAmbientSound(g_sSound[iIndex], fVec, SOUND_FROM_PLAYER, SNDLEVEL_RAIDSIREN, _, g_fVolume[iIndex]);
		}
		// Sound From player voice
		case 3:
		{
			float fPos[3], fAgl[3];
			GetClientEyePosition(client, fPos);
			GetClientEyeAngles(client, fAgl);

			// player`s mouth
			fPos[2] -= 3.0;

			EmitSoundToAll(g_sSound[iIndex], client, SNDCHAN_VOICE, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fVolume[iIndex], SNDPITCH_NORMAL, client, fPos, fAgl, true);
		}
	}

	g_iSpam[client] = GetTime() + g_iCooldown[iIndex];

	MyStore_SetClientPreviousMenu(client, MENU_PARENT);
	MyStore_DisplayPreviousMenu(client);

	return g_iPerm[iIndex]; // 1 ITEM_EQUIP_KEEP / 0 ITEM_EQUIP_REMOVE
}

public int Sounds_Remove(int client, int itemid)
{
	return ITEM_EQUIP_REMOVE;
}

public void Event_PlayerSay(Event event, char[] name, bool dontBroadcast)
{
	if (!gc_bEnable.BoolValue)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client)
		return;

	char sBuffer[32];
	GetEventString(event, "text", sBuffer, sizeof(sBuffer));

	for (int i = 0; i < g_iCount; i++)
	{
		if (strcmp(sBuffer, g_sTrigger[i]) == 0)
		{
			if (!CheckFlagBits(client, g_iFlagBits[i]) || !MyStore_HasClientAccess(client))
				return;

			if (g_iSpam[client] > GetTime())
			{
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Spam Cooldown", g_iSpam[client] - GetTime());
				return;
			}

			int credits = MyStore_GetClientCredits(client);
			if (credits >= g_unPrice[i] || MyStore_HasClientItem(client, g_iItemId[i]))
			{
				switch (g_iOrigin[i])
				{
					// Sound From global world
					case 1:
					{
						EmitSoundToAll(g_sSound[i], SOUND_FROM_WORLD, _, SNDLEVEL_RAIDSIREN, _, g_fVolume[i]);
					}
					// Sound From local player
					case 2:
					{
						float fVec[3];
						GetClientAbsOrigin(client, fVec);
						EmitAmbientSound(g_sSound[i], fVec, SOUND_FROM_PLAYER, SNDLEVEL_RAIDSIREN, _, g_fVolume[i]);
					}
					// Sound From player voice
					case 3:
					{
						float fPos[3], fAgl[3];
						GetClientEyePosition(client, fPos);
						GetClientEyeAngles(client, fAgl);

						// player`s mouth
						fPos[2] -= 3.0;

						EmitSoundToAll(g_sSound[i], client, SNDCHAN_VOICE, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fVolume[i], SNDPITCH_NORMAL, client, fPos, fAgl, true);
					}
				}
			
				if (!MyStore_HasClientItem(client, g_iItemId[i]))
				{
					MyStore_SetClientCredits(client, credits - g_unPrice[i], "Sound Trigger");
					if (g_iPerm[i] == 1)
					{
						MyStore_GiveItem(client, g_iItemId[i], 0, 0, g_unPrice[i]);
					}
				}
				else if (g_iPerm[i] == 0)
				{
					MyStore_RemoveItem(client, g_iItemId[i]);
				}

				g_iSpam[client] = GetTime() + g_iCooldown[i];
			}
			else
			{
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Credit Not Enough", g_sCreditsName);
			}

			break;
		}
	}
}

public void MyStore_OnPreviewItem(int client, char[] type, int index)
{
	if (!StrEqual(type, "sound"))
		return;

	EmitSoundToClient(client, g_sSound[index], client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fVolume[index] / 1.5);

	CPrintToChat(client, "%s%t", g_sChatPrefix, "Play Preview", client);
}

bool CheckFlagBits(int client, int flagsNeed, int flags = -1)
{
	if (flags==-1)
	{
		flags = GetUserFlagBits(client);
	}

	if (flagsNeed == 0 || flags & flagsNeed || flags & ADMFLAG_ROOT)
	{
		return true;
	}
	return false;
}
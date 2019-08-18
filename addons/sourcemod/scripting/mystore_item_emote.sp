/*
 * MyStore - Emote item module
 * by: shanapu
 * https://github.com/shanapu/
 * 
 * Copyright (C) 2018-2019 Thomas Schmidt (shanapu)
 * Credits: Rachnus - https://forums.alliedmods.net/showthread.php?t=309198
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
#include <sdkhooks>
#include <clientprefs>

#include <colors> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/colors.inc
#include <mystore> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/mystore.inc

#include <smartdm> //https://forums.alliedmods.net/attachment.php?attachmentid=136152&d=1406298576
#include <autoexecconfig> //https://raw.githubusercontent.com/Impact123/AutoExecConfig/development/autoexecconfig.inc

#pragma semicolon 1
#pragma newdecls required

char g_sMaterial[STORE_MAX_ITEMS][PLATFORM_MAX_PATH];
char g_sSound[STORE_MAX_ITEMS][PLATFORM_MAX_PATH];
char g_sTrigger[STORE_MAX_ITEMS][64];
float g_fTime[STORE_MAX_ITEMS];
int g_unPrice[STORE_MAX_ITEMS];
int g_iCooldown[STORE_MAX_ITEMS];
float g_fVolume[STORE_MAX_ITEMS];
float g_fScale[STORE_MAX_ITEMS];
int g_iPerm[STORE_MAX_ITEMS];
int g_iItemId[STORE_MAX_ITEMS];
int g_iFlagBits[STORE_MAX_ITEMS];

char g_sChatPrefix[128];
char g_sCreditsName[64];

ConVar gc_bEnable;
ConVar gc_fHeight;

int g_iCount = 0;
int g_iSpam[MAXPLAYERS + 1] = {0,...};

Handle g_hTimerPreview[MAXPLAYERS + 1];
int g_iPreviewEntity[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

bool g_bHide[MAXPLAYERS + 1];
Handle g_hHideCookie = INVALID_HANDLE;

/*
 * Build date: <DATE>
 * Build number: <BUILD>
 * Commit: https://github.com/shanapu/MyStore/commit/<COMMIT>
 */

public Plugin myinfo = 
{
	name = "MyStore - Emote item module",
	author = "shanapu", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "",
	version = "0.1.<BUILD>", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = "github.com/shanapu/MyStore"
};

public void OnPluginStart()
{
	if (MyStore_RegisterHandler("emote", Emotes_OnMapStart, Emotes_Reset, Emotes_Config, Emotes_Equip, _, false) == -1)
	{
		SetFailState("Can't Register module to core - Reached max module types(%i).", STORE_MAX_TYPES);
	}

	LoadTranslations("mystore.phrases");

	RegConsoleCmd("sm_hideemote", Command_Hide, "Hides the Emotes");

	HookEvent("player_say", Event_PlayerSay);

	AutoExecConfig_SetFile("items", "sourcemod/mystore");
	AutoExecConfig_SetCreateFile(true);

	gc_fHeight= AutoExecConfig_CreateConVar("mystore_emote_height", "130.0", "distance above players head", _, true, 1.0);

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	g_hHideCookie = RegClientCookie("Emotes_Hide_Cookie", "Cookie to check if Emotes are blocked", CookieAccess_Private);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!AreClientCookiesCached(i))
			continue;

		OnClientCookiesCached(i);
	}
}

public void OnClientCookiesCached(int client)
{
	char sValue[8];
	GetClientCookie(client, g_hHideCookie, sValue, sizeof(sValue));

	g_bHide[client] = (sValue[0] && StringToInt(sValue));
}

public Action Command_Hide(int client, int args)
{
	g_bHide[client] = !g_bHide[client];
	if (g_bHide[client])
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Item hidden", "emote");
		SetClientCookie(client, g_hHideCookie, "1");
	}
	else
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Item visible", "emote");
		SetClientCookie(client, g_hHideCookie, "0");
	}

	return Plugin_Handled;
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
	strcopy(g_sCreditsName, sizeof(g_sCreditsName), credits);
}

public void Emotes_OnMapStart()
{
	char sBuffer[256];

	for (int i = 0; i < g_iCount; i++)
	{
		PrecacheModel(g_sMaterial[i]);
		Downloader_AddFileToDownloadsTable(g_sMaterial[i]);

		FormatEx(sBuffer, sizeof(sBuffer), "sound/%s", g_sSound[i]);
		if (!FileExists(sBuffer, true))
			continue;

		PrecacheSound(g_sSound[i], true);
		AddFileToDownloadsTable(sBuffer);
	}
}

public void Emotes_Reset()
{
	g_iCount = 0;
}

public bool Emotes_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, g_iCount);

	kv.GetString("material", g_sMaterial[g_iCount], PLATFORM_MAX_PATH);

	if (!FileExists(g_sMaterial[g_iCount], true))
	{
		MyStore_LogMessage(0, LOG_ERROR, "Can't find emote material %s.", g_sMaterial[g_iCount]);
		return false;
	}

	kv.GetString("sound", g_sSound[g_iCount], PLATFORM_MAX_PATH);
	kv.GetString("trigger", g_sTrigger[g_iCount], 64);
	g_fScale[g_iCount] = kv.GetFloat("scale", 0.1);
	g_iPerm[g_iCount] = kv.GetNum("perm", 0);
	g_fTime[g_iCount] = kv.GetFloat("time", 2.5);
	g_iCooldown[g_iCount] = kv.GetNum("cooldown", 3);
	g_fVolume[g_iCount] = kv.GetFloat("volume", 0.5);
	g_unPrice[g_iCount] = kv.GetNum("price");
	g_iItemId[g_iCount] = itemid;

	char sBuffer[16];
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

public int Emotes_Equip(int client, int itemid)
{
	int iIndex = MyStore_GetDataIndex(itemid);

	if (g_iSpam[client] > GetTime())
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Spam Cooldown", g_iSpam[client] - GetTime());
		return ITEM_EQUIP_FAIL;
	}

	if (!IsPlayerAlive(client))
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Must be Alive");
		return ITEM_EQUIP_FAIL;
	}

	SpawnEmote(client, iIndex);

	MyStore_SetClientPreviousMenu(client, MENU_PARENT);
	MyStore_DisplayPreviousMenu(client);

	return g_iPerm[iIndex];
}

void SpawnEmote(int client, int index)
{
	if (g_hTimerPreview[client] != null)
	{
		TriggerTimer(g_hTimerPreview[client], false);
	}

	int iEmote = CreateEntityByName("env_sprite_oriented");

	float fPos[3];
	GetClientAbsOrigin(client, fPos);
	fPos[2] += gc_fHeight.FloatValue + ((g_fScale[index] * 5) * (g_fScale[index] * 5));

	DispatchKeyValue(iEmote, "spawnflags", "1");
	DispatchKeyValueFloat(iEmote, "scale", g_fScale[index]);
	DispatchKeyValue(iEmote, "model", g_sMaterial[index]);
	DispatchSpawn(iEmote);

	TeleportEntity(iEmote, fPos, NULL_VECTOR, NULL_VECTOR);

	SetVariantString("!activator");
	AcceptEntityInput(iEmote, "SetParent", client);

	Set_EdictFlags(iEmote);
	
	SDKHook(iEmote, SDKHook_SetTransmit, Hook_SetTransmit);

	g_iSpam[client] = GetTime() + g_iCooldown[index];

	CreateTimer(g_fTime[index], Timer_KillPreview, client);

	if (!g_sSound[index][0])
		return;

	float fAgl[3];
	GetClientEyePosition(client, fPos);
	GetClientEyeAngles(client, fAgl);

	// player`s mouth
	fPos[2] -= 3.0;

	EmitSoundToAll(g_sSound[index], client, SNDCHAN_VOICE, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fVolume[index], SNDPITCH_NORMAL, client, fPos, fAgl, true);
}

public Action Hook_SetTransmit(int entity, int client)
{
	Set_EdictFlags(entity);

	return g_bHide[client] ? Plugin_Handled : Plugin_Continue;
}

void Set_EdictFlags(int edict)
{
	if (GetEdictFlags(edict) & FL_EDICT_ALWAYS)
	{
		SetEdictFlags(edict, (GetEdictFlags(edict) ^ FL_EDICT_ALWAYS));
	}
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
			if (credits >= g_unPrice[i] || MyStore_HasClientItem(client, g_iItemId[i]) || MyStore_IsItemInBoughtPackage(client,g_iItemId[i]))
			{
				SpawnEmote(client, i);

				if (!MyStore_HasClientItem(client, g_iItemId[i]) || !MyStore_IsItemInBoughtPackage(client, g_iItemId[i]))
				{
					MyStore_SetClientCredits(client, credits - g_unPrice[i], "Emote Trigger");
					if (g_iPerm[i] == 1)
					{
						MyStore_GiveItem(client, g_iItemId[i], 0, 0, g_unPrice[i]);
					}
				}
				else if (g_iPerm[i] == 0)
				{
					MyStore_RemoveItem(client, g_iItemId[i]);
				}
			}
			else
			{
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Credit Not Enough", g_sCreditsName);
			}

			break;
		}
	}
}

public void OnClientDisconnect(int client)
{
	if (g_hTimerPreview[client] != null)
	{
		TriggerTimer(g_hTimerPreview[client], false);
	}

	g_bHide[client] = false;
}

public void MyStore_OnPreviewItem(int client, char[] type, int index)
{
	if (g_hTimerPreview[client] != null)
	{
		TriggerTimer(g_hTimerPreview[client], false);
	}

	if (!StrEqual(type, "emote"))
		return;

	int iPreview = CreateEntityByName("env_sprite_oriented");

	DispatchKeyValueFloat(iPreview, "scale", g_fScale[index]);
	DispatchKeyValue(iPreview, "model", g_sMaterial[index]);
	DispatchSpawn(iPreview);

	AcceptEntityInput(iPreview, "Enable");

	float fOrigin[3], fAngles[3], fRad[2], fPosition[3];

	GetClientAbsOrigin(client, fOrigin);
	GetClientAbsAngles(client, fAngles);

	fRad[0] = DegToRad(fAngles[0]);
	fRad[1] = DegToRad(fAngles[1]);

	fPosition[0] = fOrigin[0] + 64 * Cosine(fRad[0]) * Cosine(fRad[1]);
	fPosition[1] = fOrigin[1] + 64 * Cosine(fRad[0]) * Sine(fRad[1]);
	fPosition[2] = fOrigin[2] + 4 * Sine(fRad[0]);

	fAngles[0] *= -1.0;
	fAngles[1] *= -1.0;

	fPosition[2] += 55;

	TeleportEntity(iPreview, fPosition, fAngles, NULL_VECTOR);

	g_iPreviewEntity[client] = EntIndexToEntRef(iPreview);

	SDKHook(iPreview, SDKHook_SetTransmit, Hook_SetTransmit_Preview);

	g_hTimerPreview[client] = CreateTimer(g_fTime[index], Timer_KillPreview, client);

	if (!g_sSound[index][0])
		return;

	EmitSoundToClient(client, g_sSound[index], client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fVolume[index] / 1.5);

	CPrintToChat(client, "%s%t", g_sChatPrefix, "Play Preview", client);
}

public Action Hook_SetTransmit_Preview(int ent, int client)
{
	if (g_iPreviewEntity[client] == INVALID_ENT_REFERENCE)
		return Plugin_Handled;

	if (ent == EntRefToEntIndex(g_iPreviewEntity[client]))
		return Plugin_Continue;

	return Plugin_Handled;
}

public Action Timer_KillPreview(Handle timer, int client)
{
	g_hTimerPreview[client] = null;

	if (g_iPreviewEntity[client] != INVALID_ENT_REFERENCE)
	{
		int entity = EntRefToEntIndex(g_iPreviewEntity[client]);

		if (IsValidEdict(entity))
		{
			AcceptEntityInput(entity, "Kill");
		}
	}
	g_iPreviewEntity[client] = INVALID_ENT_REFERENCE;

	return Plugin_Stop;
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
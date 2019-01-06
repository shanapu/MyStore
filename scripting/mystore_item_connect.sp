#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <geoip>

#include <colors>
#include <mystore>

char g_sChatPrefix[128];

char g_sConnectText[STORE_MAX_ITEMS][128];
char g_sDisconnectText[STORE_MAX_ITEMS][128];
char g_sDisconnectSound[STORE_MAX_ITEMS][128];
char g_sConnectSound[STORE_MAX_ITEMS][128];
float g_fConnectVolume[STORE_MAX_ITEMS];
float g_fDisconnectVolume[STORE_MAX_ITEMS];

int g_iActive[MAXPLAYERS + 1] = {-1, ...};
int g_iCount;

public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");

	MyStore_RegisterHandler("connect", Connect_OnMapStart, Connect_Reset, Connect_Config, Connect_Equip, Connect_UnEquip, true);
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

public void Connect_OnMapStart()
{
	char sBuffer[256];

	for (int i = 0; i < g_iCount; i++)
	{
		FormatEx(sBuffer, sizeof(sBuffer), "sound/%s", g_sConnectSound[i]);
		if (!FileExists(sBuffer, true))
			continue;

		PrecacheSound(g_sConnectSound[i], true);
		AddFileToDownloadsTable(sBuffer);

		FormatEx(sBuffer, sizeof(sBuffer), "sound/%s", g_sDisconnectSound[i]);
		if (!FileExists(sBuffer, true))
			continue;

		PrecacheSound(g_sDisconnectSound[i], true);
		AddFileToDownloadsTable(sBuffer);
	}
}

public void Connect_Reset()
{
	g_iCount = 0;
}

public bool Connect_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, g_iCount);

	kv.GetString("connect_text", g_sConnectText[g_iCount], 128);
	kv.GetString("connect_sound", g_sConnectSound[g_iCount], 128);
	g_fConnectVolume[g_iCount] = kv.GetFloat("connect_sound_volume", 1.0);
	kv.GetString("disconnect_text", g_sDisconnectText[g_iCount], 128);
	kv.GetString("disconnect_sound", g_sDisconnectSound[g_iCount], 128);
	g_fDisconnectVolume[g_iCount] = kv.GetFloat("disconnect_sound_volume", 1.0);

	if (g_fConnectVolume[g_iCount] > 1.0)
	{
		g_fConnectVolume[g_iCount] = 1.0;
	}
	else if (g_fConnectVolume[g_iCount] <= 0.0)
	{
		g_fConnectVolume[g_iCount] = 0.05;
	}

	if (g_fDisconnectVolume[g_iCount] > 1.0)
	{
		g_fDisconnectVolume[g_iCount] = 1.0;
	}
	else if (g_fDisconnectVolume[g_iCount] <= 0.0)
	{
		g_fDisconnectVolume[g_iCount] = 0.05;
	}

	g_iCount++;

	return true;
}

public int Connect_Equip(int client, int itemid)
{
	int iIndex = MyStore_GetDataIndex(itemid);

	g_iActive[client] = iIndex;

	return ITEM_EQUIP_SUCCESS;
}


public int Connect_UnEquip(int client, int itemid)
{
	g_iActive[client] = -1;

	return ITEM_EQUIP_SUCCESS;
}

public void OnClientPutInServer(int client)
{
	if (IsFakeClient(client))
		return;

	CreateTimer(5.0, Timer_OnClientPutInServer, GetClientUserId(client));
}

public Action Timer_OnClientPutInServer(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!client || !IsClientInGame(client) || g_iActive[client] == -1)
		return Plugin_Handled;

	char sBuffer[256];
	strcopy(sBuffer, sizeof(sBuffer), g_sConnectText[g_iActive[client]]);
	char sName[64];
	char sIP[16];
	char sCode[4];
	char sCountry[32];
	GetClientIP(client, sIP, sizeof(sIP));
	GeoipCountry(sIP, sCountry, sizeof(sCountry));
	GeoipCode3(sIP, sCode);
	GetClientName(client, sName, sizeof(sName));

	ReplaceString(sBuffer, sizeof(sBuffer), "{name}", sName);
	ReplaceString(sBuffer, sizeof(sBuffer), "{country}", sCountry);
	ReplaceString(sBuffer, sizeof(sBuffer), "{country_code}", sCode);

	CPrintToChatAll("%s%s", g_sChatPrefix, sBuffer);

	if (!g_sConnectSound[g_iActive[client]][0])
		return Plugin_Handled;

	EmitSoundToAll(g_sConnectSound[g_iActive[client]], SOUND_FROM_WORLD, _, SNDLEVEL_RAIDSIREN, _, g_fConnectVolume[g_iActive[client]]);

	return Plugin_Handled;
}

public void OnClientDisconnect(int client)
{
	if (isValidClient(client) && g_iActive[client] != -1)
	{
		char sBuffer[256];
		strcopy(sBuffer, sizeof(sBuffer), g_sDisconnectText[g_iActive[client]]);
		char sName[64];
		char sIP[16];
		char sCode[4];
		char sCountry[32];
		GetClientIP(client, sIP, sizeof(sIP));
		GeoipCountry(sIP, sCountry, sizeof(sCountry));
		GeoipCode3(sIP, sCode);
		GetClientName(client, sName, sizeof(sName));

		ReplaceString(sBuffer, sizeof(sBuffer), "{name}", sName);
		ReplaceString(sBuffer, sizeof(sBuffer), "{country}", sCountry);
		ReplaceString(sBuffer, sizeof(sBuffer), "{country_code}", sCode);

		CPrintToChatAll("%s%s", g_sChatPrefix, sBuffer);

		if (!g_sDisconnectSound[g_iActive[client]][0])
			return;

		EmitSoundToAll(g_sDisconnectSound[g_iActive[client]], SOUND_FROM_WORLD, _, SNDLEVEL_RAIDSIREN, _, g_fDisconnectVolume[g_iActive[client]]);
	}
}

bool isValidClient(int client)
{
	return (1 <= client <= MaxClients && IsClientInGame(client));
}
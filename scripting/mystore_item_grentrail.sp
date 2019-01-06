#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>

#include <mystore>

#include <colors>
#include <smartdm>

#pragma semicolon 1
#pragma newdecls required

char g_sMaterial[STORE_MAX_ITEMS][PLATFORM_MAX_PATH];
char g_sWeapon[STORE_MAX_ITEMS][16];
float g_fWidth[STORE_MAX_ITEMS];
int g_iColor[STORE_MAX_ITEMS][4];
int g_iCacheID[STORE_MAX_ITEMS];

bool g_bEquipt[MAXPLAYERS + 1] = false;

bool g_bHide[MAXPLAYERS + 1];
Handle g_hHideCookie = INVALID_HANDLE;

ConVar gc_bEnable;

int g_iCount = 0;

char g_sChatPrefix[128];

public void OnPluginStart()
{
	MyStore_RegisterHandler("grenadetrail", GrenadeTrails_OnMapStart, GrenadeTrails_Reset, GrenadeTrails_Config, GrenadeTrails_Equip, GrenadeTrails_Remove, true);

	g_hHideCookie = RegClientCookie("GrenadeTrails_Hide_Cookie", "Cookie to check if GrenadeTrails are blocked", CookieAccess_Private);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!AreClientCookiesCached(i))
			continue;

		OnClientCookiesCached(i);
	}

	RegConsoleCmd("sm_hidegrenadetrails", Command_Hide, "Hide the GrenadeTrails");
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
		CPrintToChat(client, "%s GrenadeTrails disabled", g_sChatPrefix); //todo translate
		SetClientCookie(client, g_hHideCookie, "1");
	}
	else
	{
		CPrintToChat(client, "%s GrenadeTrails enabled", g_sChatPrefix);
		SetClientCookie(client, g_hHideCookie, "0");
	}

	return Plugin_Handled;
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

public void GrenadeTrails_OnMapStart()
{
	for (int i = 0; i < g_iCount; i++)
	{
		g_iCacheID[i] = PrecacheModel(g_sMaterial[i], true);
		Downloader_AddFileToDownloadsTable(g_sMaterial[i]);
	}
}

public void GrenadeTrails_Reset()
{
	g_iCount = 0;
}

public bool GrenadeTrails_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, g_iCount);

	kv.GetString("material", g_sMaterial[g_iCount], PLATFORM_MAX_PATH);

	if (!FileExists(g_sMaterial[g_iCount], true))
	{
		MyStore_LogMessage(0, LOG_ERROR, "Can't find emote material %s.", g_sMaterial[g_iCount]);
		return false;
	}

	g_fWidth[g_iCount] = kv.GetFloat("width", 10.0);
	kv.GetColor("color", g_iColor[g_iCount][0], g_iColor[g_iCount][1], g_iColor[g_iCount][2], g_iColor[g_iCount][3]);

	kv.GetString("grenade", g_sWeapon[g_iCount], PLATFORM_MAX_PATH); //todo

	g_iCount++;

	return true;
}

public int GrenadeTrails_Equip(int client, int itemid)
{
	g_bEquipt[client] = true;

	return ITEM_EQUIP_SUCCESS;
}

public int GrenadeTrails_Remove(int client, int itemid)
{
	g_bEquipt[client] = false;

	return ITEM_EQUIP_SUCCESS;
}

public void OnClientDisconnect(int client)
{
	g_bEquipt[client] = false;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (g_iCount == 0)
		return;

	if (StrContains(classname, "_projectile") > 0)
	{
		SDKHook(entity, SDKHook_SpawnPost, OnEntitySpawnedPost);
	}
}

public void OnEntitySpawnedPost(int entity)
{
	if (!gc_bEnable.BoolValue)
		return;

	int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");

	if (!(0<client <= MaxClients))
		return;

	if (!g_bEquipt[client])
		return;

	int[] clients = new int[MaxClients + 1];
	int numClients = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;

		if (g_bHide[i])
			continue;

		clients[numClients] = i;
		numClients++;
	}

	if (numClients < 1)
		return;

	int iIndex = MyStore_GetDataIndex(MyStore_GetEquippedItem(client, "grenadetrail", 0));

	TE_SetupBeamFollow(entity, g_iCacheID[iIndex], 0, 2.0, g_fWidth[iIndex], g_fWidth[iIndex], 10, g_iColor[iIndex]);

	TE_Send(clients, numClients, 0.0);
}
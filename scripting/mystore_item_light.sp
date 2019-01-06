#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <clientprefs>

#include <mystore>

#include <colors>

char g_sColor[STORE_MAX_ITEMS][16];
char g_sBrightness[STORE_MAX_ITEMS][8];
char g_sStyle[STORE_MAX_ITEMS][4];
float g_fRadius[STORE_MAX_ITEMS];
float g_fDistance[STORE_MAX_ITEMS];

char g_sChatPrefix[128];

ConVar gc_bEnable;

int g_iCount = 0;
int g_iClientLight[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};
int g_iSelectedLight[MAXPLAYERS + 1] = {-1,...};

bool g_bHide[MAXPLAYERS + 1];
Handle g_hHideCookie = INVALID_HANDLE;

public void OnPluginStart()
{
	MyStore_RegisterHandler("light", _, Light_Reset, Light_Config, Light_Equip, Light_Remove, true);

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_team", Event_PlayerTeam);

	g_hHideCookie = RegClientCookie("Lights_Hide_Cookie", "Cookie to check if Lights are blocked", CookieAccess_Private);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!AreClientCookiesCached(i))
			continue;

		OnClientCookiesCached(i);
	}

	RegConsoleCmd("sm_hidelights", Command_Hide, "Hides the Lights");
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
		CPrintToChat(client, "%s Lights disabled", g_sChatPrefix); //todo translate
		SetClientCookie(client, g_hHideCookie, "1");
	}
	else
	{
		CPrintToChat(client, "%s Lights enabled", g_sChatPrefix);
		SetClientCookie(client, g_hHideCookie, "0");
	}

	return Plugin_Handled;
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

public void Light_Reset()
{
	g_iCount = 0;
}

public bool Light_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, g_iCount);

	kv.GetString("color", g_sColor[g_iCount], 16);
	kv.GetString("brightness", g_sBrightness[g_iCount], 8, "5");
	kv.GetString("style", g_sStyle[g_iCount], 4, "0");
	g_fDistance[g_iCount] = kv.GetFloat("distance", 200.0);
	g_fRadius[g_iCount] = kv.GetFloat("radius", 100.0);

	g_iCount++;

	return true;
}

public int Light_Equip(int client, int itemid)
{
	g_iSelectedLight[client] = MyStore_GetDataIndex(itemid);
	ResetLight(client);
	CreateLight(client);

	return ITEM_EQUIP_SUCCESS;
}

public int Light_Remove(int client, int itemid)
{
	ResetLight(client);
	g_iSelectedLight[client] = -1;

	return ITEM_EQUIP_REMOVE;
}

public void OnClientConnected(int client)
{
	g_iSelectedLight[client] = -1;
}

public void OnClientDisconnect(int client)
{
	g_iSelectedLight[client] = -1;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsPlayerAlive(client) || !(CS_TEAM_T <= GetClientTeam(client) <= CS_TEAM_CT))
		return;

	CreateTimer(0.1, Timer_PlayerSpawn_Post, GetClientUserId(client));
}

public Action Timer_PlayerSpawn_Post(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!client || !IsPlayerAlive(client) || !(CS_TEAM_T <= GetClientTeam(client) <= CS_TEAM_CT))
		return Plugin_Continue;

	ResetLight(client);
	CreateLight(client);

	return Plugin_Continue;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client)
		return;

	ResetLight(client);
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client)
		return;

	ResetLight(client);
}

public void CreateLight(int client)
{
	if (!gc_bEnable.BoolValue)
		return;

	if (g_iClientLight[client] != INVALID_ENT_REFERENCE)
		return;

	if (g_iSelectedLight[client] == -1)
		return;

	int iIndex = g_iSelectedLight[client];

	int iEntity = CreateEntityByName("light_dynamic");
	if (!IsValidEntity(iEntity))
		return;

	float fOri[3];
	GetClientAbsOrigin(client, fOri);
	fOri[2] += 5.0;

	DispatchKeyValue(iEntity, "_light", g_sColor[iIndex]);
	DispatchKeyValue(iEntity, "brightness", g_sBrightness[iIndex]);
	DispatchKeyValueFloat(iEntity, "spotlight_radius", g_fRadius[iIndex]);
	DispatchKeyValueFloat(iEntity, "distance", g_fDistance[iIndex]);
	DispatchKeyValue(iEntity, "style", g_sStyle[iIndex]);

	DispatchSpawn(iEntity);
	TeleportEntity(iEntity, fOri, NULL_VECTOR, NULL_VECTOR);

	SetVariantString("!activator");
	AcceptEntityInput(iEntity, "SetParent", client, iEntity, 0);

//	SetVariantString("facemask");
	AcceptEntityInput(iEntity, "SetParentAttachmentMaintainOffset", iEntity, iEntity, 0);

	Set_EdictFlags(iEntity);

	SDKHook(iEntity, SDKHook_SetTransmit, Hook_SetTransmit);

	g_iClientLight[client] = EntIndexToEntRef(iEntity);
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

public void ResetLight(int client)
{
	if (g_iClientLight[client] == INVALID_ENT_REFERENCE)
		return;

	int iEntity = EntRefToEntIndex(g_iClientLight[client]);
	g_iClientLight[client] = INVALID_ENT_REFERENCE;
	if (iEntity == INVALID_ENT_REFERENCE)
		return;

	SDKUnhook(iEntity, SDKHook_SetTransmit, Hook_SetTransmit);
	AcceptEntityInput(iEntity, "Kill");
}
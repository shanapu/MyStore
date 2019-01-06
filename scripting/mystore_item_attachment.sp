#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>

#include <mystore>

#include <colors>
#include <smartdm>

#pragma semicolon 1
#pragma newdecls required

char g_sModel[STORE_MAX_ITEMS][PLATFORM_MAX_PATH];
char g_sAttachment[STORE_MAX_ITEMS][64];
float g_fPosition[STORE_MAX_ITEMS][3];
float g_fAngles[STORE_MAX_ITEMS][3];
int g_iSlot[STORE_MAX_ITEMS];

char g_sChatPrefix[128];

Handle g_hTimerPreview[MAXPLAYERS + 1];

int g_iClientAttachments[MAXPLAYERS + 1][STORE_MAX_SLOTS];
int g_iCount = 0;
int g_iSpecTarget[MAXPLAYERS + 1];
int g_iCountOwners[2048];

bool g_bHide[MAXPLAYERS + 1];
Handle g_hHideCookie = INVALID_HANDLE;

int g_iPreviewEntity[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");

	MyStore_RegisterHandler("attachment", Attachments_OnMapStart, Attachments_Reset, Attachments_Config, Attachments_Equip, Attachments_Remove, true);

	HookEvent("player_spawn", Event_PlayerSpawn_Pre, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeath_Pre, EventHookMode_Pre);
	HookEvent("player_team", Event_PlayerTeam_Pre,  EventHookMode_Pre);

	g_hHideCookie = RegClientCookie("Attachments_Hide_Cookie", "Cookie to check if Attachments are blocked", CookieAccess_Private);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!AreClientCookiesCached(i))
			continue;

		OnClientCookiesCached(i);
	}

	RegConsoleCmd("sm_hideattachments", Command_Hide, "Hides the Attachments");
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
		CPrintToChat(client, "%s Attachments disabled", g_sChatPrefix); //todo translate
		SetClientCookie(client, g_hHideCookie, "1");
	}
	else
	{
		CPrintToChat(client, "%s Attachments enabled", g_sChatPrefix);
		SetClientCookie(client, g_hHideCookie, "0");
	}

	return Plugin_Handled;
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

public void Event_PlayerSpawn_Pre(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (IsFakeClient(client) || GetClientTeam(client) <= 1)
		return;

	RequestFrame(OnClientSpawnPost, client);
}

public void OnClientSpawnPost(int client)
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client))
		return;

	SetClientAttachment(client);
}

public void Event_PlayerDeath_Pre(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (IsFakeClient(client))
		return;

	for (int i = 1; i < STORE_MAX_SLOTS; i++)
	{
		RemoveClientAttachments(client, i);
	}
}

public void Event_PlayerTeam_Pre(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int team = event.GetInt("team");
	int oldteam = event.GetInt("oldteam");

	if (oldteam > 1 && team <= 1)
	{
		for (int i = 1; i < STORE_MAX_SLOTS; i++)
		{
			RemoveClientAttachments(client, i);
		}
	}
}

public bool Attachments_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, g_iCount);

	kv.GetString("model", g_sModel[g_iCount], PLATFORM_MAX_PATH);

	if (!FileExists(g_sModel[g_iCount], true))
	{
		MyStore_LogMessage(0, LOG_ERROR, "Can't find model %s.", g_sModel[g_iCount]);
		return false;
	}

	kv.GetVector("position", g_fPosition[g_iCount]);
	kv.GetVector("angles", g_fAngles[g_iCount]);
	g_iSlot[g_iCount] = kv.GetNum("slot");
	kv.GetString("attachment", g_sAttachment[g_iCount], 64, "facemask");

	g_iCount++;
	return true;
}

public void Attachments_OnMapStart()
{
	for (int a = 1; a <= MaxClients; a++)
	{
		for (int b = 1; b < STORE_MAX_SLOTS; b++)
		{
			g_iClientAttachments[a][b] = INVALID_ENT_REFERENCE;
		}
	}

	for (int i = 0; i < g_iCount; i++)
	{
		PrecacheModel(g_sModel[i], true);
		Downloader_AddFileToDownloadsTable(g_sModel[i]);
	}

	CreateTimer(0.1, Timer_AttachmentsAdjust, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_AttachmentsAdjust(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;

		if (IsClientObserver(i))
		{
			int iObserverMode = GetEntProp(i, Prop_Send, "m_iObserverMode");
			int iObserverTarget = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget");
			g_iSpecTarget[i] = (iObserverMode == 4 && iObserverTarget >= 0) ? iObserverTarget : -1;
		}
		else g_iSpecTarget[i] = i;
	}

	return Plugin_Continue;
}

public void Attachments_Reset()
{
	g_iCount = 0;
}

public int Attachments_Equip(int client, int itemid)
{
	int iIndex = MyStore_GetDataIndex(itemid);
	if (IsPlayerAlive(client))
	{
		RemoveClientAttachments(client, g_iSlot[iIndex]);
		CreateAttachment(client, itemid);
	}

	return g_iSlot[iIndex];
}

public int Attachments_Remove(int client, int itemid)
{
	int iIndex = MyStore_GetDataIndex(itemid);
	RemoveClientAttachments(client, g_iSlot[iIndex]);

	return g_iSlot[iIndex];
}

void SetClientAttachment(int client)
{
	for (int i = 1; i < STORE_MAX_SLOTS; i++)
	{
		RemoveClientAttachments(client, i);
		CreateAttachment(client, -1, i);
	}
}

void CreateAttachment(int client, int itemid = -1, int slot = 0)
{
	int iEquipped = (itemid == -1 ? MyStore_GetEquippedItem(client, "attachment", slot) : itemid);

	if (iEquipped < 0)
		return;

	int iIndex = MyStore_GetDataIndex(iEquipped);

	float fAttachmentOrigin[3];
	float fAttachmentAngles[3];
	float fForward[3];
	float fRight[3];
	float fUp[3];
	GetClientAbsOrigin(client, fAttachmentOrigin);
	GetClientAbsAngles(client, fAttachmentAngles);

	fAttachmentAngles[0] += g_fAngles[iIndex][0];
	fAttachmentAngles[1] += g_fAngles[iIndex][1];
	fAttachmentAngles[2] += g_fAngles[iIndex][2];

	float fOffset[3];
	fOffset[0] = g_fPosition[iIndex][0];
	fOffset[1] = g_fPosition[iIndex][1];
	fOffset[2] = g_fPosition[iIndex][2];

	GetAngleVectors(fAttachmentAngles, fForward, fRight, fUp);

	fAttachmentOrigin[0] += fRight[0] * fOffset[0] + fForward[0] * fOffset[1] + fUp[0] * fOffset[2];
	fAttachmentOrigin[1] += fRight[1] * fOffset[0] + fForward[1] * fOffset[1] + fUp[1] * fOffset[2];
	fAttachmentOrigin[2] += fRight[2] * fOffset[0] + fForward[2] * fOffset[1] + fUp[2] * fOffset[2];

	int iEntity = CreateEntityByName("prop_dynamic_override");
	DispatchKeyValue(iEntity, "model", g_sModel[iIndex]);
	DispatchKeyValue(iEntity, "spawnflags", "256");
	DispatchKeyValue(iEntity, "solid", "0");
	SetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity", client);

	g_iCountOwners[iEntity] = client;

	DispatchSpawn(iEntity);
	AcceptEntityInput(iEntity, "TurnOn", iEntity, iEntity, 0);

	g_iClientAttachments[client][g_iSlot[iIndex]] = EntIndexToEntRef(iEntity);

	TeleportEntity(iEntity, fAttachmentOrigin, fAttachmentAngles, NULL_VECTOR);

	SetVariantString("!activator");
	AcceptEntityInput(iEntity, "SetParent", client, iEntity, 0);

	SetVariantString(g_sAttachment[iIndex]);
	AcceptEntityInput(iEntity, "SetParentAttachmentMaintainOffset", iEntity, iEntity, 0);

	Set_EdictFlags(iEntity);

	SDKHook(iEntity, SDKHook_SetTransmit, Hook_SetTransmit);
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

void RemoveClientAttachments(int client, int slot)
{
	if (g_iClientAttachments[client][slot] == INVALID_ENT_REFERENCE)
		return;

	int entity = EntRefToEntIndex(g_iClientAttachments[client][slot]);
	if (IsValidEdict(entity))
	{
		SDKUnhook(entity, SDKHook_SetTransmit, Hook_SetTransmit);
		AcceptEntityInput(entity, "Kill");
	}
	g_iClientAttachments[client][slot] = INVALID_ENT_REFERENCE;
}

public void OnEntityDestroyed(int entity)
{
	if (entity > 2048 || entity < MaxClients)
		return;

	g_iCountOwners[entity] = -1;
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

	if (!StrEqual(type, "attachment"))
		return;

	int iPreview = CreateEntityByName("prop_dynamic_override");

	DispatchKeyValue(iPreview, "spawnflags", "64");
	DispatchKeyValue(iPreview, "model", g_sModel[index]);

	DispatchSpawn(iPreview);

	SetEntProp(iPreview, Prop_Send, "m_CollisionGroup", 11);

	AcceptEntityInput(iPreview, "Enable");

	int offset = GetEntSendPropOffs(iPreview, "m_clrGlow");
	SetEntProp(iPreview, Prop_Send, "m_bShouldGlow", true, true);
	SetEntProp(iPreview, Prop_Send, "m_nGlowStyle", 0);
	SetEntPropFloat(iPreview, Prop_Send, "m_flGlowMaxDist", 2000.0);

	SetEntData(iPreview, offset, 57, _, true);
	SetEntData(iPreview, offset + 1, 197, _, true);
	SetEntData(iPreview, offset + 2, 187, _, true);
	SetEntData(iPreview, offset + 3, 155, _, true);

	float fOri[3], fAng[3], fRad[2], fPos[3];

	GetClientAbsOrigin(client, fOri);
	GetClientAbsAngles(client, fAng);

	fRad[0] = DegToRad(fAng[0]);
	fRad[1] = DegToRad(fAng[1]);

	fPos[0] = fOri[0] + 64 * Cosine(fRad[0]) * Cosine(fRad[1]);
	fPos[1] = fOri[1] + 64 * Cosine(fRad[0]) * Sine(fRad[1]);
	fPos[2] = fOri[2] + 4 * Sine(fRad[0]);

	fAng[0] += g_fAngles[index][0];
	fAng[1] += g_fAngles[index][1];
	fAng[2] += g_fAngles[index][2];

	fPos[2] += 55;

	TeleportEntity(iPreview, fPos, fAng, NULL_VECTOR);

	g_iPreviewEntity[client] = EntIndexToEntRef(iPreview);

	int iRotator = CreateEntityByName("func_rotating");
	DispatchKeyValueVector(iRotator, "origin", fPos);

	DispatchKeyValue(iRotator, "maxspeed", "20");
	DispatchKeyValue(iRotator, "spawnflags", "64");
	DispatchSpawn(iRotator);

	SetVariantString("!activator");
	AcceptEntityInput(iPreview, "SetParent", iRotator, iRotator);
	AcceptEntityInput(iRotator, "Start");

	SetEntPropEnt(iPreview, Prop_Send, "m_hEffectEntity", iRotator);

	SDKHook(iPreview, SDKHook_SetTransmit, Hook_SetTransmit_Preview);

	g_hTimerPreview[client] = CreateTimer(8.0, Timer_KillPreview, client);

	CPrintToChat(client, "%s%t", g_sChatPrefix, "Spawn Preview", client);
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
			SDKUnhook(entity, SDKHook_SetTransmit, Hook_SetTransmit_Preview);
			AcceptEntityInput(entity, "Kill");
		}
	}
	g_iPreviewEntity[client] = INVALID_ENT_REFERENCE;

	return Plugin_Stop;
}
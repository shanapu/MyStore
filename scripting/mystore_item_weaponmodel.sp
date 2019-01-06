#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

#include <mystore>

#include <colors>
#include <smartdm>

#pragma semicolon 1
#pragma newdecls required

char g_sModelV[STORE_MAX_ITEMS][PLATFORM_MAX_PATH];
char g_sModelW[STORE_MAX_ITEMS][PLATFORM_MAX_PATH];
char g_sModelD[STORE_MAX_ITEMS][PLATFORM_MAX_PATH];
char g_sEntity[STORE_MAX_ITEMS][32];
int g_iSlot[STORE_MAX_ITEMS];
int g_iCacheIdV[STORE_MAX_ITEMS];
int g_iCacheIdW[STORE_MAX_ITEMS];

char g_sChatPrefix[128];

bool g_bHooked[MAXPLAYERS + 1];

char g_sCurWpn[MAXPLAYERS + 1][64];

//ConVar gc_bEnable;

float g_fOldCycle[MAXPLAYERS + 1];

StringMap g_hWeapon[MAXPLAYERS + 1];

int g_iCount = 0;
int g_iRefPVM[MAXPLAYERS + 1];
int g_iOldSequence[MAXPLAYERS + 1];

Handle g_hTimerPreview[MAXPLAYERS + 1];
int g_iPreviewEntity[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");

	MyStore_RegisterHandler("weaponmodel", Models_OnMapStart, Models_Reset, Models_Config, Models_Equip, Models_Remove, true);

	HookEvent("player_death", Event_PlayerDeath);
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

public void Models_OnMapStart()
{
	for (int i = 0; i < g_iCount; i++)
	{
		g_iCacheIdV[i] = PrecacheModel(g_sModelV[i], true); //2
		Downloader_AddFileToDownloadsTable(g_sModelV[i]);

		if (!StrEqual(g_sModelW[i], "none", false))
		{
			g_iCacheIdW[i] = PrecacheModel(g_sModelW[i], true);
			Downloader_AddFileToDownloadsTable(g_sModelW[i]);
			
			if (g_iCacheIdW[i] == 0)
				g_iCacheIdW[i] = -1;
		}
		
		if (!StrEqual(g_sModelD[i], "none", false))
		{
			if (!IsModelPrecached(g_sModelD[i]))
			{
				PrecacheModel(g_sModelD[i], true);
				Downloader_AddFileToDownloadsTable(g_sModelD[i]);
			}
		}
	}
}

public void Models_Reset()
{ 
	g_iCount = 0;
}

public bool Models_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, g_iCount);
	kv.GetString("model", g_sModelV[g_iCount], PLATFORM_MAX_PATH);

	if (!FileExists(g_sModelV[g_iCount], true))
	{
		MyStore_LogMessage(0, LOG_ERROR, "Can't find model %s.", g_sModelV[g_iCount]);
		return false;
	}

	kv.GetString("worldmodel", g_sModelW[g_iCount], PLATFORM_MAX_PATH, "none");
	kv.GetString("dropmodel", g_sModelD[g_iCount], PLATFORM_MAX_PATH, "none");
	kv.GetString("weapon", g_sEntity[g_iCount], 32);
	g_iSlot[g_iCount] = kv.GetNum("slot");

	g_iCount++;

	return true;
}

public int Models_Equip(int client, int itemid)
{
	int iIndex = MyStore_GetDataIndex(itemid);

	if (!Models_AddModels(client, g_sEntity[iIndex], g_iCacheIdV[iIndex], g_iCacheIdW[iIndex], g_sModelD[iIndex]) && IsClientInGame(client))
		CPrintToChat(client, "\x02 unknown error! please contact to admin!");

	return g_iSlot[iIndex];
}

public int Models_Remove(int client, int itemid)
{
	int iIndex = MyStore_GetDataIndex(itemid);

	if (!Models_RemoveModels(client, g_sEntity[iIndex]) && IsClientInGame(client))
		CPrintToChat(client, "\x02 unknown error! please contact to admin!");

	return g_iSlot[iIndex];
}

public void OnClientPutInServer(int client)
{
	g_iRefPVM[client] = INVALID_ENT_REFERENCE;
	g_bHooked[client] = false;

	g_hWeapon[client] = new StringMap();
}

public void OnClientDisconnect(int client)
{
	if (g_hTimerPreview[client] != null)
	{
		TriggerTimer(g_hTimerPreview[client], false);
	}

	if (!IsClientInGame(client))
		return;

	if (g_bHooked[client])
	{
		SDKUnhook(client, SDKHook_PostThinkPost, Hook_PostThinkPost_Models);
		g_bHooked[client] = false;
	}

	if (g_hWeapon[client].Size > 0)
	{
		SDKUnhook(client, SDKHook_WeaponSwitchPost, Hook_WeaponSwitchPost_Models);
		SDKUnhook(client, SDKHook_WeaponSwitch, Hook_WeaponSwitch_Models);
		SDKUnhook(client, SDKHook_WeaponEquip, Hook_WeaponEquip_Models);
		SDKUnhook(client, SDKHook_WeaponDropPost, Hook_WeaponDropPost_Models);
	}

	delete g_hWeapon[client];
}


public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client)
		return;

	if (!g_bHooked[client])
		return;

	SDKUnhook(client, SDKHook_PostThinkPost, Hook_PostThinkPost_Models);
	g_bHooked[client] = false;
}

public void Hook_WeaponSwitchPost_Models(int client, int weapon) 
{
	if (!IsValidEdict(weapon))
		return;

	char classname[32];
	if (!GetWeaponClassname(weapon, classname, 32))
		return;

	if (StrContains(classname, "item", false) == 0)
		return;

	char szGlobalName[256];
	GetEntPropString(weapon, Prop_Data, "m_iGlobalname", szGlobalName, 256);
	if (StrContains(szGlobalName, "custom", false) != 0)
		return;

	ReplaceString(szGlobalName, 256, "custom", "");

	char szData[2][192];
	ExplodeString(szGlobalName, ";", szData, 2, 192);

	int model_index = StringToInt(szData[0]);

	int iPVM = EntRefToEntIndex(g_iRefPVM[client]);
	if (iPVM == INVALID_ENT_REFERENCE)
	{
		g_iRefPVM[client] = GetViewModelReference(client, -1); 
		iPVM = EntRefToEntIndex(g_iRefPVM[client]);
		if (iPVM == INVALID_ENT_REFERENCE) 
			return;
	}

	SetEntProp(weapon, Prop_Send, "m_nModelIndex", 0); 
	SetEntProp(iPVM, Prop_Send, "m_nModelIndex", model_index);

	strcopy(g_sCurWpn[client], 64, classname);
	g_bHooked[client] = SDKHookEx(client, SDKHook_PostThinkPost, Hook_PostThinkPost_Models);
}

public Action Hook_WeaponSwitch_Models(int client, int weapon) 
{
	if (g_bHooked[client])
	{
		SDKUnhook(client, SDKHook_PostThinkPost, Hook_PostThinkPost_Models);
		g_bHooked[client] = false;
	}

	return Plugin_Continue;
}

public Action Hook_WeaponEquip_Models(int client, int weapon)
{
	if (!IsValidEdict(weapon))
		return Plugin_Continue;

	if (GetEntProp(weapon, Prop_Send, "m_hPrevOwner") > 0)
		return Plugin_Continue;

	char classname[32];
	if (!GetWeaponClassname(weapon, classname, 32))
		return Plugin_Continue;

	char szGlobalName[256];
	GetEntPropString(weapon, Prop_Data, "m_iGlobalname", szGlobalName, 256);
	if (StrContains(szGlobalName, "custom", false) == 0)
		return Plugin_Continue;

	char classname_world[32], classname_drop[32];
	FormatEx(classname_world, 32, "%s_world", classname);
	FormatEx(classname_drop,  32, "%s_drop",  classname);

	int model_world;
	if (g_hWeapon[client].GetValue(classname_world, model_world) && model_world != -1)
	{
		int iWorldModel = GetEntPropEnt(weapon, Prop_Send, "m_hWeaponWorldModel"); 
		if (IsValidEdict(iWorldModel))
			SetEntProp(iWorldModel, Prop_Send, "m_nModelIndex", model_world);
	}

	char model_drop[192];
	if (g_hWeapon[client].GetString(classname_drop, model_drop, 192) && !StrEqual(model_drop, "none"))
	{
		if (!IsModelPrecached(model_drop))
		{
			MyStore_LogMessage(client, LOG_ERROR, "Hook_WeaponEquip_Models: 'model_drop' %s not precached", model_drop);
		}
	}

	int model_index;
	if (!g_hWeapon[client].GetValue(classname, model_index) || model_index == -1)
		return Plugin_Continue;

	FormatEx(szGlobalName, 256, "custom%i;%s", model_index, model_drop);
	DispatchKeyValue(weapon, "globalname", szGlobalName);

	return Plugin_Continue;
}

public void Hook_WeaponDropPost_Models(int client, int weapon)
{
	if (!IsValidEdict(weapon))
		return;

	RequestFrame(SetWorldModel, EntIndexToEntRef(weapon));
}

public void Hook_PostThinkPost_Models(int client)
{
	int model = EntRefToEntIndex(g_iRefPVM[client]);

	if (model == INVALID_ENT_REFERENCE)
	{
		SDKUnhook(client, SDKHook_PostThinkPost, Hook_PostThinkPost_Models);
		g_bHooked[client] = false;
		return;
	}

	int iSequence = GetEntProp(model, Prop_Send, "m_nSequence");
	float fCycle = GetEntPropFloat(model, Prop_Data, "m_flCycle");

	if (fCycle < g_fOldCycle[client] && iSequence == g_iOldSequence[client])
	{
		if (StrEqual(g_sCurWpn[client], "weapon_knife"))
		{
			switch(iSequence)
			{
				case  3: SetEntProp(model, Prop_Send, "m_nSequence", 4);
				case  4: SetEntProp(model, Prop_Send, "m_nSequence", 3);
				case  5: SetEntProp(model, Prop_Send, "m_nSequence", 6);
				case  6: SetEntProp(model, Prop_Send, "m_nSequence", 5);
				case  7: SetEntProp(model, Prop_Send, "m_nSequence", 8);
				case  8: SetEntProp(model, Prop_Send, "m_nSequence", 7);
				case  9: SetEntProp(model, Prop_Send, "m_nSequence", 10);
				case 10: SetEntProp(model, Prop_Send, "m_nSequence", 11);
				case 11: SetEntProp(model, Prop_Send, "m_nSequence", 10);
			}
		}
		else if (StrEqual(g_sCurWpn[client], "weapon_ak47"))
		{
			switch(iSequence)
			{
				case 3: SetEntProp(model, Prop_Send, "m_nSequence", 2);
				case 2: SetEntProp(model, Prop_Send, "m_nSequence", 1);
				case 1: SetEntProp(model, Prop_Send, "m_nSequence", 3);
			}
		}
		else if (StrEqual(g_sCurWpn[client], "weapon_mp7"))
		{
			if (iSequence == 3)
				SetEntProp(model, Prop_Send, "m_nSequence", -1);
		}
		else if (StrEqual(g_sCurWpn[client], "weapon_awp"))
		{
			if (iSequence == 1)
				SetEntProp(model, Prop_Send, "m_nSequence", -1);	
		}
		else if (StrEqual(g_sCurWpn[client], "weapon_deagle"))
		{
			switch(iSequence)
			{
				case 3: SetEntProp(model, Prop_Send, "m_nSequence", 2);
				case 2: SetEntProp(model, Prop_Send, "m_nSequence", 1);
				case 1: SetEntProp(model, Prop_Send, "m_nSequence", 3);
			}
		}
	}

	g_iOldSequence[client] = iSequence;
	g_fOldCycle[client] = fCycle;
}

public Action Hook_WeaponCanUse(int client, int weapon)
{
	return Plugin_Handled;
}

void SetWorldModel(int iRef)
{
	int weapon = EntRefToEntIndex(iRef);

	if (!IsValidEdict(weapon))
		return;

	char szGlobalName[256];
	GetEntPropString(weapon, Prop_Data, "m_iGlobalname", szGlobalName, 256);

	if (StrContains(szGlobalName, "custom", false) != 0)
		return;

	ReplaceString(szGlobalName, 64, "custom", "");

	char szData[2][192];
	ExplodeString(szGlobalName, ";", szData, 2, 192);

	if (StrEqual(szData[1], "none"))
		return;

	SetEntityModel(weapon, szData[1]);
}

bool Models_AddModels(int client, const char[] classname, int model_view, int model_world, const char[] model_drop)
{
	if (!IsClientInGame(client) || g_hWeapon[client] == null)
		return false;

	if (g_hWeapon[client].Size == 0)
	{
		SDKHook(client, SDKHook_WeaponSwitchPost, Hook_WeaponSwitchPost_Models); 
		SDKHook(client, SDKHook_WeaponSwitch, Hook_WeaponSwitch_Models); 
		SDKHook(client, SDKHook_WeaponEquip,	 Hook_WeaponEquip_Models);
		SDKHook(client, SDKHook_WeaponDropPost, Hook_WeaponDropPost_Models);
	}

	char world_name[32], drop_name[32];
	FormatEx(world_name, 32, "%s_world", classname);
	FormatEx(drop_name,  32, "%s_drop",  classname);

	g_hWeapon[client].SetValue(classname, model_view);
	g_hWeapon[client].SetValue(world_name, model_world);
	g_hWeapon[client].SetString(drop_name, model_drop);

	RefreshWeapon(client, classname);

	return true;
}

bool Models_RemoveModels(int client, const char[] classname)
{
	if (!IsClientInGame(client) || g_hWeapon[client] == null)
		return false;

	char world_name[32], drop_name[32];
	FormatEx(world_name, 32, "%s_world", classname);
	FormatEx(drop_name,  32, "%s_drop",  classname);

	g_hWeapon[client].Remove(classname);
	g_hWeapon[client].Remove(world_name);
	g_hWeapon[client].Remove(drop_name);

	if (g_hWeapon[client].Size == 0)
	{
		SDKUnhook(client, SDKHook_WeaponSwitchPost, Hook_WeaponSwitchPost_Models);
		SDKUnhook(client, SDKHook_WeaponSwitch, Hook_WeaponSwitch_Models);
		SDKUnhook(client, SDKHook_WeaponEquip, Hook_WeaponEquip_Models);
		SDKUnhook(client, SDKHook_WeaponDropPost, Hook_WeaponDropPost_Models);
	}

	RefreshWeapon(client, classname);

	return true;
}

void RefreshWeapon(int client, const char[] classname)
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client))
		return;

	int weapon = GetClientWeaponIndexByClassname(client, classname);
	
	if (weapon == -1)
		return;

	int iPrimaryAmmoCount = GetEntProp(weapon, Prop_Data, "m_iPrimaryAmmoCount");
	int iSecondaryAmmoCount = GetEntProp(weapon, Prop_Data, "m_iSecondaryAmmoCount");
	int iClip1 = GetEntProp(weapon, Prop_Data, "m_iClip1");
	int iClip2 = GetEntProp(weapon, Prop_Data, "m_iClip2");

	if (GetEntPropEnt(weapon, Prop_Send, "m_hOwner") != client)
	{
		SetEntPropEnt(weapon, Prop_Send, "m_hOwner", client);
	}
	CS_DropWeapon(client, weapon, true, true);
	AcceptEntityInput(weapon, "Kill");

	DataPack pack = new DataPack();
	pack.WriteString(classname);
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(iPrimaryAmmoCount);
	pack.WriteCell(iSecondaryAmmoCount);
	pack.WriteCell(iClip1);
	pack.WriteCell(iClip2);

	CreateTimer(0.2, Timer_GiveBackWeapon, pack);

	if (GetPlayerWeaponSlot(client, 0) == -1 && GetPlayerWeaponSlot(client, 1) == -1 && GetPlayerWeaponSlot(client, 2) == -1 && GetPlayerWeaponSlot(client, 3) == -1 && GetPlayerWeaponSlot(client, 4) == -1)
	{
		CreateTimer(0.25, Timer_RemoveDummyWeapon, GivePlayerItem(client, "weapon_decoy"));
	}

	SDKHook(client, SDKHook_WeaponCanUse, Hook_WeaponCanUse);
}

public Action Timer_GiveBackWeapon(Handle timer, DataPack pack)
{
	pack.Reset();
	char classname[32];
	pack.ReadString(classname, 32);
	int client = GetClientOfUserId(pack.ReadCell());
	int iPrimaryAmmoCount = pack.ReadCell();
	int iSecondaryAmmoCount = pack.ReadCell();
	int iClip1 = pack.ReadCell();
	int iClip2 = pack.ReadCell();
	delete pack;

	if (!client || !IsClientInGame(client))
		return Plugin_Stop;

	SDKUnhook(client, SDKHook_WeaponCanUse, Hook_WeaponCanUse);

	if (!IsPlayerAlive(client))
		return Plugin_Stop;

	int weapon = GivePlayerItem(client, classname);

	if (StrEqual(classname, "weapon_knife"))
		EquipPlayerWeapon(client, weapon);

	if (iPrimaryAmmoCount > -1) SetEntProp(weapon, Prop_Data, "m_iPrimaryAmmoCount", iPrimaryAmmoCount);
	if (iSecondaryAmmoCount > -1) SetEntProp(weapon, Prop_Data, "m_iSecondaryAmmoCount", iSecondaryAmmoCount);
	if (iClip1 > -1) SetEntProp(weapon, Prop_Data, "m_iClip1", iClip1);
	if (iClip2 > -1) SetEntProp(weapon, Prop_Data, "m_iClip2", iClip2);

	return Plugin_Stop;
}

public Action Timer_RemoveDummyWeapon(Handle timer, int weapon)
{
	if (!IsValidEdict(weapon))
		return Plugin_Stop;

	int owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwner");
	if (IsValidClient(owner))
	{
		CS_DropWeapon(owner, weapon, true, true);
	}
	AcceptEntityInput(weapon, "Kill");

	return Plugin_Stop;
}

int GetViewModelReference(int client, int entity)
{
	int owner;

	while ((entity = FindEntityByClassname2(entity, "predicted_viewmodel")) != -1)
	{
		owner = GetEntPropEnt(entity, Prop_Send, "m_hOwner");

		if (owner == client)
			return EntIndexToEntRef(entity);
	}

	return INVALID_ENT_REFERENCE;
}

int FindEntityByClassname2(int start, const char[] classname)
{
	while(start > MaxClients && !IsValidEntity(start))
		start--;

	return FindEntityByClassname(start, classname);
}

stock bool GetWeaponClassname(int weapon, char[] classname, int maxLen)
{
	if (!GetEdictClassname(weapon, classname, maxLen))
		return false;
	
	if (!HasEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex"))
		return false;
	
	switch(GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex"))
	{
		case 60: strcopy(classname, maxLen, "weapon_m4a1_silencer");
		case 61: strcopy(classname, maxLen, "weapon_usp_silencer");
		case 63: strcopy(classname, maxLen, "weapon_cz75a");
		case 64: strcopy(classname, maxLen, "weapon_revolver");
	}
	
	return true;
}

stock int GetClientWeaponIndexByClassname(int client, const char[] classname)
{
	int offset = FindDataMapInfo(client, "m_hMyWeapons") - 4;

	int weapon = -1;
	char weaponclass[32];
	for (int i = 0; i < 48; i++)
	{
		offset += 4;

		weapon = GetEntDataEnt2(client, offset);

		if (!IsValidEdict(weapon) || !GetEdictClassname(weapon, weaponclass, 32) || StrContains(weaponclass, "weapon_") != 0)
			continue;

		if (strcmp(weaponclass, classname) == 0)
			return weapon;
	}

	return -1;
}

bool IsValidClient(int client)
{
	if (client > MaxClients || client < 1)
		return false;

	if (!IsClientInGame(client))
		return false;

	return true;
}

public void MyStore_OnPreviewItem(int client, char[] type, int index)
{
	if (g_hTimerPreview[client] != null)
	{
		TriggerTimer(g_hTimerPreview[client], false);
	}

	if (!StrEqual(type, "weaponmodel"))
		return;

	int iPreview = CreateEntityByName("prop_dynamic_override"); //prop_dynamic_override

	DispatchKeyValue(iPreview, "spawnflags", "64");
	DispatchKeyValue(iPreview, "model", g_sModelW[index]);

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

	int iRotator = CreateEntityByName("func_rotating");
	DispatchKeyValueVector(iRotator, "origin", fPosition);

	DispatchKeyValue(iRotator, "maxspeed", "20");
	DispatchKeyValue(iRotator, "friction", "0");
	DispatchKeyValue(iRotator, "dmg", "0");
	DispatchKeyValue(iRotator, "solid", "0");
	DispatchKeyValue(iRotator, "spawnflags", "64");
	DispatchSpawn(iRotator);

	SetVariantString("!activator");
	AcceptEntityInput(iPreview, "SetParent", iRotator, iRotator);
	AcceptEntityInput(iRotator, "Start");

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
/*
 * MyStore - Lootbox module
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
#include <sdkhooks>

#include <mystore> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/mystore.inc

#include <colors> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/colors.inc
#include <smartdm> //https://forums.alliedmods.net/attachment.php?attachmentid=136152&d=1406298576
#include <autoexecconfig> //https://raw.githubusercontent.com/Impact123/AutoExecConfig/development/autoexecconfig.inc

#pragma semicolon 1
#pragma newdecls required

#define MAX_LOOTBOXES 8

#define LEVEL_GREY 0
#define LEVEL_BLUE 1
#define LEVEL_GREEN 2
#define LEVEL_GOLD 3
#define LEVEL_PINK 4
#define LEVEL_AMOUNT 5

ConVar gc_sPickUpSound;

char g_sPickUpSound[128];

char g_sChatPrefix[128];
char g_sCreditsName[64];
float g_fSellRatio;

char g_sModel[MAX_LOOTBOXES][PLATFORM_MAX_PATH];
char g_sEfxFile[MAX_LOOTBOXES][PLATFORM_MAX_PATH];
char g_sEfxName[MAX_LOOTBOXES][PLATFORM_MAX_PATH];
char g_sLootboxItems[MAX_LOOTBOXES][STORE_MAX_ITEMS / 4][LEVEL_AMOUNT][PLATFORM_MAX_PATH]; //assuming min 4 item on a box
float g_fChance[MAX_LOOTBOXES][LEVEL_AMOUNT];

int g_iLootboxEntity[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};
Handle g_hTimerDelete[MAXPLAYERS + 1];
Handle g_hTimerColor[MAXPLAYERS + 1];
int g_iClientSpeed[MAXPLAYERS + 1];
int g_iClientLevel[MAXPLAYERS + 1];
int g_iClientBox[MAXPLAYERS + 1];

int g_iItemID[MAX_LOOTBOXES];

int g_iBoxCount = 0;
int g_iItemLevelCount[MAX_LOOTBOXES][LEVEL_AMOUNT];

Handle gf_hPreviewItem;

/*
 * Build date: <DATE>
 * Build number: <BUILD>
 * Commit: https://github.com/shanapu/MyStore/commit/<COMMIT>
 */

public Plugin myinfo = 
{
	name = "MyStore - Lootbox module",
	author = "shanapu",
	description = "",
	version = "0.1.<BUILD>",
	url = "github.com/shanapu/MyStore"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	gf_hPreviewItem = CreateGlobalForward("MyStore_OnPreviewItem", ET_Ignore, Param_Cell, Param_String, Param_Cell);

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");

	AutoExecConfig_SetFile("lootbox", "sourcemod/MyStore");
	AutoExecConfig_SetCreateFile(true);

	gc_sPickUpSound = AutoExecConfig_CreateConVar("mystore_lootbox_sound_pickup", "ui/csgo_ui_crate_open.wav", "Path to the pickup sound");

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	gc_sPickUpSound.AddChangeHook(OnSettingChanged);

	MyStore_RegisterHandler("lootbox", Lootbox_OnMapStart, Lootbox_Reset, Lootbox_Config, Lootbox_Equip, _, false);

	HookEvent("round_end", Event_RoundEnd);
}

public void OnSettingChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == gc_sPickUpSound)
	{
		strcopy(g_sPickUpSound, sizeof(g_sPickUpSound), newValue);
	}
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
	strcopy(g_sCreditsName, sizeof(g_sCreditsName), credits);

	g_fSellRatio = FindConVar("mystore_sell_ratio").FloatValue;
	if (g_fSellRatio < 0.1)
	{
		g_fSellRatio = 0.6;
	}
}

public void Lootbox_OnMapStart()
{
	for (int i = 0; i < g_iBoxCount; i++)
	{
		PrecacheModel(g_sModel[i], true);
		Downloader_AddFileToDownloadsTable(g_sModel[i]);

		if (!g_sEfxName[i][0])
			continue;

		PrecacheParticleSystem(g_sEfxName[i]);
		if (FileExists(g_sEfxFile[i], true) && g_sEfxFile[i][0])
		{
			Downloader_AddFileToDownloadsTable(g_sEfxFile[i]);
			PrecacheGeneric(g_sEfxFile[i], true);
		}
	}

	gc_sPickUpSound.GetString(g_sPickUpSound, sizeof(g_sPickUpSound));

	char sBuffer[128];
	FormatEx(sBuffer, sizeof(sBuffer), "sound/%s", g_sPickUpSound);
	if (FileExists(sBuffer, true) && g_sPickUpSound[0])
	{
		AddFileToDownloadsTable(sBuffer);
		PrecacheSound(g_sPickUpSound, true);
	}

	PrecacheModel("models/props_crates/static_crate_40.mdl", true);

	PrecacheSound("ui/csgo_ui_crate_item_scroll.wav", true);
}

public void Lootbox_Reset()
{
	g_iBoxCount = 0;

	for (int i = 0; i < g_iBoxCount; i++)
	{
		for (int j = 0; j < LEVEL_AMOUNT; j++)
		{
			g_iItemLevelCount[i][j] = 0;
		}
	}
}

public bool Lootbox_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, g_iBoxCount);

	kv.GetString("model", g_sModel[g_iBoxCount], PLATFORM_MAX_PATH);

	if (!FileExists(g_sModel[g_iBoxCount], true))
	{
		MyStore_LogMessage(0, LOG_ERROR, "Can't find model %s.", g_sModel[g_iBoxCount]);
		return false;
	}

	kv.GetString("file", g_sEfxFile[g_iBoxCount], PLATFORM_MAX_PATH);
	kv.GetString("name", g_sEfxName[g_iBoxCount], PLATFORM_MAX_PATH);

	float percent = 0.0;
	g_fChance[g_iBoxCount][LEVEL_GREY] = kv.GetFloat("grey", 50.0);
	g_fChance[g_iBoxCount][LEVEL_BLUE] = kv.GetFloat("blue", 20.0);
	g_fChance[g_iBoxCount][LEVEL_GREEN] = kv.GetFloat("green", 15.0);
	g_fChance[g_iBoxCount][LEVEL_GOLD] = kv.GetFloat("gold", 10.0);
	g_fChance[g_iBoxCount][LEVEL_PINK] = kv.GetFloat("pink", 5.0);
	for (int i = 0; i < LEVEL_AMOUNT; i++)
	{
		percent += g_fChance[g_iBoxCount][i];
	}
	if (percent != 100.0)
	{
		MyStore_LogMessage(0, LOG_ERROR, "Lootbox #%i - Sum of levels is not 100%", g_iBoxCount + 1);
		return false;
	}

	g_iItemID[g_iBoxCount] = itemid;

	kv.JumpToKey("Items");
	kv.GotoFirstSubKey(false);
	do
	{
		char sBuffer[16];
		int lvlindex = -1;

		kv.GetSectionName(sBuffer, sizeof(sBuffer));
		if (StrEqual(sBuffer,"grey", false))
		{
			lvlindex = LEVEL_GREY;
		}
		else if (StrEqual(sBuffer,"blue", false))
		{
			lvlindex = LEVEL_BLUE;
		}
		else if (StrEqual(sBuffer,"green", false))
		{
			lvlindex = LEVEL_GREEN;
		}
		else if (StrEqual(sBuffer,"gold", false))
		{
			lvlindex = LEVEL_GOLD;
		}
		else if (StrEqual(sBuffer,"pink", false))
		{
			lvlindex = LEVEL_PINK;
		}

		if (lvlindex == -1)
		{
			MyStore_LogMessage(0, LOG_ERROR, "Lootbox #%i - unknown level color: %s", sBuffer);
			return false;
		}

		kv.GetString(NULL_STRING, g_sLootboxItems[g_iBoxCount][g_iItemLevelCount[g_iBoxCount][lvlindex]][lvlindex], PLATFORM_MAX_PATH);
		g_iItemLevelCount[g_iBoxCount][lvlindex]++;
	}
	while kv.GotoNextKey(false);

	kv.GoBack();
	kv.GoBack();

	g_iBoxCount++;

	return true;
}

public int Lootbox_Equip(int client, int itemid)
{
	if (!IsPlayerAlive(client))
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Must be Alive");
		return ITEM_EQUIP_FAIL;
	}

	if (DropLootbox(client, MyStore_GetDataIndex(itemid)))
		return ITEM_EQUIP_SUCCESS;

	return ITEM_EQUIP_FAIL;
}

bool DropLootbox(int client, int index)
{
	int iLootbox = CreateEntityByName("prop_dynamic_override"); //prop_dynamic_override

	if (!iLootbox)
		return false;

	char sBuffer[32];
	FormatEx(sBuffer, 32, "lootbox_%d", iLootbox);

	float fOri[3], fAng[3], fRad[2], fPos[3];

	GetClientAbsOrigin(client, fOri);
	GetClientAbsAngles(client, fAng);

	fRad[0] = DegToRad(fAng[0]);
	fRad[1] = DegToRad(fAng[1]);

	fPos[0] = fOri[0] + 64 * Cosine(fRad[0]) * Cosine(fRad[1]);
	fPos[1] = fOri[1] + 64 * Cosine(fRad[0]) * Sine(fRad[1]);
	fPos[2] = fOri[2] + 4 * Sine(fRad[0]);

	fAng[0] *= -1.0;
	fAng[1] *= -1.0;

	fPos[2] += 35;

	SetEntPropString(iLootbox, Prop_Data, "m_iName", sBuffer);
	SetEntProp(iLootbox, Prop_Send, "m_usSolidFlags", 12); //FSOLID_NOT_SOLID|FSOLID_TRIGGER
	SetEntProp(iLootbox, Prop_Data, "m_nSolidType", 6); // SOLID_VPHYSICS
	SetEntProp(iLootbox, Prop_Send, "m_CollisionGroup", 1); //COLLISION_GROUP_DEBRIS

	DispatchKeyValue(iLootbox, "model", g_sModel[index]);
	DispatchSpawn(iLootbox);
	AcceptEntityInput(iLootbox, "Enable");
	ActivateEntity(iLootbox);

	TeleportEntity(iLootbox, fPos, fAng, NULL_VECTOR);

	g_iLootboxEntity[client] = EntIndexToEntRef(iLootbox);

	CreateGlow(iLootbox);
	int iLight = CreateLight(iLootbox, fPos);
	int iRotator = CreateRotator(iLootbox, fPos);
	int iTrigger = CreateTriggerProp(iLootbox, fPos, sBuffer);

	DataPack pack = new DataPack();
	g_iClientBox[client] = index;
	pack.WriteCell(client);
	pack.WriteCell(iTrigger);
	pack.WriteCell(iLootbox);
	pack.WriteCell(iRotator);
	pack.WriteCell(iLight);
	g_iClientSpeed[client] = 235;
	g_hTimerDelete[client] = CreateTimer(55.0, Timer_DeleteBox, client);
	g_hTimerColor[client] = CreateTimer(0.2, Timer_Color, pack, TIMER_REPEAT);

	SDKHook(iLootbox, SDKHook_SetTransmit, Hook_SetTransmit_Preview);

	return true;
}

void CreateGlow(int ent)
{
	int iOffset = GetEntSendPropOffs(ent, "m_clrGlow");
	SetEntProp(ent, Prop_Send, "m_bShouldGlow", true, true);
	SetEntProp(ent, Prop_Send, "m_nGlowStyle", 0);
	SetEntPropFloat(ent, Prop_Send, "m_flGlowMaxDist", 2000.0);

	SetEntData(ent, iOffset, 250, _, true);
	SetEntData(ent, iOffset + 1, 210, _, true);
	SetEntData(ent, iOffset + 2, 0, _, true);
	SetEntData(ent, iOffset + 3, 255, _, true);
}

int CreateRotator(int ent, float pos[3])
{
	int iRotator = CreateEntityByName("func_rotating");
	DispatchKeyValueVector(iRotator, "origin", pos);

	DispatchKeyValue(iRotator, "spawnflags", "64");
	DispatchKeyValue(iRotator, "maxspeed", "200");
	DispatchSpawn(iRotator);

	SetVariantString("!activator");
	AcceptEntityInput(ent, "SetParent", iRotator, iRotator);
	AcceptEntityInput(iRotator, "Start");

	return iRotator;
}

int CreateLight(int ent, float pos[3])
{
	int iLight = CreateEntityByName("light_dynamic");

	DispatchKeyValue(iLight, "_light", "255 210 0 255");
	DispatchKeyValue(iLight, "brightness", "7");
	DispatchKeyValueFloat(iLight, "spotlight_radius", 260.0);
	DispatchKeyValueFloat(iLight, "distance", 100.0);
	DispatchKeyValue(iLight, "style", "0");

	DispatchSpawn(iLight); 
	TeleportEntity(iLight, pos, NULL_VECTOR, NULL_VECTOR);

	SetVariantString("!activator");
	AcceptEntityInput(iLight, "SetParent", ent, iLight, 0);

	return iLight;
}

int CreateTriggerProp(int ent, float pos[3], char[] name)
{
	int iTrigger = CreateEntityByName("prop_dynamic_override");

	SetEntPropString(iTrigger, Prop_Data, "m_iName", name);

	DispatchKeyValue(iTrigger, "spawnflags", "64");

	DispatchKeyValue(iTrigger, "model", "models/props_crates/static_crate_40.mdl");
	DispatchSpawn(iTrigger);

	AcceptEntityInput(iTrigger, "Enable");

	SetEntProp(iTrigger, Prop_Data, "m_spawnflags", 64);

	TeleportEntity(iTrigger, pos, NULL_VECTOR, NULL_VECTOR);

	float fMins[3];
	float fMaxs[3];

	GetEntPropVector(ent, Prop_Send, "m_vecMins", fMins);
	GetEntPropVector(ent, Prop_Send, "m_vecMaxs", fMaxs);

	SetEntPropVector(iTrigger, Prop_Send, "m_vecMins", fMins);
	SetEntPropVector(iTrigger, Prop_Send, "m_vecMaxs", fMaxs);
	SetEntProp(iTrigger, Prop_Send, "m_nSolidType", 2);

	int iEffects = GetEntProp(iTrigger, Prop_Send, "m_fEffects");
	iEffects |= 32;
	SetEntProp(iTrigger, Prop_Send, "m_fEffects", iEffects);

	return iTrigger;
}

public void Hook_OnBreak(const char[] output, int ent, int client, float delay)
{
	TriggerTimer(g_hTimerDelete[client]);

	if (IsValidEdict(ent))
	{
		AcceptEntityInput(ent, "Kill");
	}

	char sUId[64];
	strcopy(sUId, sizeof(sUId), g_sLootboxItems[g_iClientBox[client]][GetRandomInt(0, g_iItemLevelCount[g_iClientBox[client]][g_iClientLevel[client]] - 1)][g_iClientLevel[client]]); // sry

	int itemid = MyStore_GetItemIdbyUniqueId(sUId);

	if (itemid == -1)
	{
		MyStore_LogMessage(0, LOG_ERROR, "Can't find item uid %s for lootbox #%i on level #%i.", sUId, g_iClientBox[client], g_iClientLevel[client]);
		return;
	}

	any item[Item_Data];
	MyStore_GetItem(itemid, item);
	any handler[Type_Handler];
	MyStore_GetHandler(item[iHandler], handler);

	if (MyStore_HasClientItem(client, itemid))
	{
		MyStore_SetClientCredits(client, MyStore_GetClientCredits(client) + item[iPrice], "Cashed a box item");
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Already own item from box. Get Credits back", item[szName], handler[szType], item[iPrice], g_sCreditsName);
	}
	else
	{
		MyStore_GiveItem(client, itemid, _, _, item[iPrice]);
		CPrintToChat(client, "%s%t", g_sChatPrefix, "You won lootbox item", item[szName], handler[szType]);

		if (item[bPreview])
		{
			Call_StartForward(gf_hPreviewItem);
			Call_PushCell(client);
			Call_PushString(handler[szType]);
			Call_PushCell(item[iDataIndex]);
			Call_Finish();
		}
	}

	float fVec[3];
	GetClientAbsOrigin(client, fVec);
	EmitAmbientSound(g_sPickUpSound, fVec, _, _, _, _, _, _);

	if (!g_sEfxName[g_iClientBox[client]][0])
		return;

	float fOri[3];
	GetEntPropVector(ent, Prop_Send, "m_vecOrigin", fOri);

	int iEfx = CreateEntityByName("info_particle_system");
	DispatchKeyValue(iEfx, "start_active", "0");
	DispatchKeyValue(iEfx, "effect_name", g_sEfxName[g_iClientBox[client]]);
	DispatchSpawn(iEfx);
	ActivateEntity(iEfx);
	TeleportEntity(iEfx, fOri, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(iEfx, "Start");
	CreateTimer(1.2, Timer_RemoveEfx, EntIndexToEntRef(iEfx));
}

public Action Timer_RemoveEfx(Handle timer, int reference)
{
	int iEnt = EntRefToEntIndex(reference);

	if (IsValidEdict(iEnt))
	{
		AcceptEntityInput(iEnt, "kill");
	}
}

int PrecacheParticleSystem(const char[] particleSystem)
{
	static int particleEffectNames = INVALID_STRING_TABLE;

	if (particleEffectNames == INVALID_STRING_TABLE)
	{
		if ((particleEffectNames = FindStringTable("ParticleEffectNames")) == INVALID_STRING_TABLE)
			return INVALID_STRING_INDEX;
	}

	int index = FindStringIndex2(particleEffectNames, particleSystem);
	if (index == INVALID_STRING_INDEX)
	{
		int numStrings = GetStringTableNumStrings(particleEffectNames);
		if (numStrings >= GetStringTableMaxStrings(particleEffectNames))
			return INVALID_STRING_INDEX;

		AddToStringTable(particleEffectNames, particleSystem);
		index = numStrings;
	}

	return index;
}

int FindStringIndex2(int tableidx, const char[] str)
{
	char buf[1024];

	int numStrings = GetStringTableNumStrings(tableidx);
	for (int i = 0; i < numStrings; i++)
	{
		ReadStringTable(tableidx, i, buf, sizeof(buf));

		if (StrEqual(buf, str))
			return i;
	}

	return INVALID_STRING_INDEX;
}

public Action Hook_SetTransmit_Preview(int ent, int client)
{
	if (g_iLootboxEntity[client] == INVALID_ENT_REFERENCE)
		return Plugin_Handled;

	if (ent == EntRefToEntIndex(g_iLootboxEntity[client]))
		return Plugin_Continue;

	return Plugin_Handled;
}

public Action Timer_Color(Handle timer, DataPack pack)
{
	pack.Reset();
	int client = pack.ReadCell();
	if (g_hTimerDelete[client] == null)
		return Plugin_Stop;

	int trigger = pack.ReadCell();
	int lootbox = pack.ReadCell();
	int rotator = pack.ReadCell();
	int light = pack.ReadCell();
	
	int index = g_iClientBox[client];
	float fPos[3];
	GetEntPropVector(lootbox, Prop_Send, "m_vecOrigin", fPos);
	fPos[2] -= 0.2;
	TeleportEntity(lootbox, fPos, NULL_VECTOR, NULL_VECTOR);
	g_iClientSpeed[client] -= 5;
	EmitAmbientSound("ui/csgo_ui_crate_item_scroll.wav", fPos, _, _, _, _, _, _);

	char sBuffer[128];
	IntToString(g_iClientSpeed[client], sBuffer, sizeof(sBuffer));
	DispatchKeyValue(rotator, "maxspeed", sBuffer);
	AcceptEntityInput(rotator, "Start");

	if (g_iClientSpeed[client] < 1)
	{
		SetEntProp(trigger, Prop_Data, "m_iHealth", 70);
		SetEntProp(trigger, Prop_Data, "m_takedamage", 2);
		HookSingleEntityOutput(trigger, "OnBreak", Hook_OnBreak, true);

		CPrintToChat(client, "%s%t", g_sChatPrefix, "Damage the crate to open");

		Format(sBuffer, sizeof(sBuffer), "%t", "Damage the crate to open");
		CRemoveTags(sBuffer, sizeof(sBuffer));
		PrintHintText(client, sBuffer);

		return Plugin_Stop;
	}

	switch(g_iClientSpeed[client])
	{
		case 120:
		{
			g_hTimerColor[client] = CreateTimer(0.31, Timer_Color, pack, TIMER_REPEAT);
			return Plugin_Stop;
		}
		case 60:
		{
			g_hTimerColor[client] = CreateTimer(0.35, Timer_Color, pack, TIMER_REPEAT);
			return Plugin_Stop;
		}
		case 40:
		{
			g_hTimerColor[client] = CreateTimer(0.4, Timer_Color, pack, TIMER_REPEAT);
			return Plugin_Stop;
		}
		case 10:
		{
			g_hTimerColor[client] = CreateTimer(0.5, Timer_Color, pack, TIMER_REPEAT); //0.6
			return Plugin_Stop;
		}
	}

	int iOffset = GetEntSendPropOffs(lootbox, "m_clrGlow");
	float percent = GetRandomFloat(0.0001, 100.0);

	if (percent < g_fChance[index][LEVEL_GREY])
	{
		SetEntityRenderColor(lootbox, 155, 255, 255, 255);
		g_iClientLevel[client] = LEVEL_GREY;
		SetEntData(lootbox, iOffset, 155, _, true);
		SetEntData(lootbox, iOffset + 1, 255, _, true);
		SetEntData(lootbox, iOffset + 2, 255, _, true);
		SetEntData(lootbox, iOffset + 3, 255, _, true);
		DispatchKeyValue(light, "_light", "155 255 255 255");
		return Plugin_Continue;
	}

	percent -= g_fChance[index][LEVEL_GREY];
	if (percent < g_fChance[index][LEVEL_BLUE])
	{
		SetEntityRenderColor(lootbox, 0, 0, 255, 255);
		SetEntData(lootbox, iOffset, 0, _, true);
		SetEntData(lootbox, iOffset + 1, 0, _, true);
		SetEntData(lootbox, iOffset + 2, 255, _, true);
		SetEntData(lootbox, iOffset + 3, 255, _, true);
		DispatchKeyValue(light, "_light", "0 0 255 255");
		g_iClientLevel[client] = LEVEL_BLUE;
		return Plugin_Continue;
	}

	percent -= g_fChance[index][LEVEL_BLUE];
	if (percent < g_fChance[index][LEVEL_GREEN])
	{
		SetEntityRenderColor(lootbox, 0, 255, 0, 255);
		SetEntData(lootbox, iOffset, 0, _, true);
		SetEntData(lootbox, iOffset + 1, 255, _, true);
		SetEntData(lootbox, iOffset + 2, 0, _, true);
		SetEntData(lootbox, iOffset + 3, 255, _, true);
		DispatchKeyValue(light, "_light", "0 255 0 255");
		g_iClientLevel[client] = LEVEL_GREEN;
		return Plugin_Continue;
	}

	percent -= g_fChance[index][LEVEL_GREEN];
	if (percent < g_fChance[index][LEVEL_GOLD])
	{
		SetEntityRenderColor(lootbox, 255, 210, 0, 255);
		SetEntData(lootbox, iOffset, 255, _, true);
		SetEntData(lootbox, iOffset + 1, 210, _, true);
		SetEntData(lootbox, iOffset + 2, 0, _, true);
		SetEntData(lootbox, iOffset + 3, 255, _, true);
		DispatchKeyValue(light, "_light", "255 210 0 255");
		g_iClientLevel[client] = LEVEL_GOLD;
		return Plugin_Continue;
	}
	

	percent -= g_fChance[index][LEVEL_GOLD];
	if (percent < g_fChance[index][LEVEL_PINK])
	{
		SetEntityRenderColor(lootbox, 255, 0, 255, 255);
		SetEntData(lootbox, iOffset, 255, _, true);
		SetEntData(lootbox, iOffset + 1, 0, _, true);
		SetEntData(lootbox, iOffset + 2, 255, _, true);
		SetEntData(lootbox, iOffset + 3, 255, _, true);
		DispatchKeyValue(light, "_light", "255 0 255 255");
		g_iClientLevel[client] = LEVEL_PINK;
		return Plugin_Continue;
	}

	return Plugin_Continue;
}

public void Event_RoundEnd(Event event, char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_hTimerColor[i] = null;

		if (g_iLootboxEntity[i] != INVALID_ENT_REFERENCE)
		{
			MyStore_GiveItem(i, g_iItemID[g_iClientBox[i]], 0, 0, 0);

			CPrintToChat(i, "%s%t", g_sChatPrefix, "You haven't opend the box in given time");
		}
		g_iClientBox[i] = -1;

		if (g_hTimerDelete[i] != null)
		{
			TriggerTimer(g_hTimerDelete[i]);
		}
	}
}

public Action Timer_DeleteBox(Handle timer, int client)
{
	g_hTimerDelete[client] = null;

	if (g_iLootboxEntity[client] != INVALID_ENT_REFERENCE)
	{
		int entity = EntRefToEntIndex(g_iLootboxEntity[client]);

		if (IsValidEdict(entity))
		{
			SDKUnhook(entity, SDKHook_SetTransmit, Hook_SetTransmit_Preview);
			AcceptEntityInput(entity, "Kill");
		}
	}
	g_iLootboxEntity[client] = INVALID_ENT_REFERENCE;

	return Plugin_Stop;
}
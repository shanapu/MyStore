/*
 * MyStore - Drop-item module
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

#define MAX_DROPS 64

StringMap g_pDrops;

ConVar gc_bEnable;

ConVar gc_bDropEnabled;
ConVar gc_bRotate;
ConVar gc_fRemoveTime;
ConVar gc_iRemoveType;
ConVar gc_sModel;
ConVar gc_sDropSound;
ConVar gc_sPickUpSound;
ConVar gc_sEfxFile;
ConVar gc_sEfxName;
ConVar gc_iRed;
ConVar gc_iBlue;
ConVar gc_iGreen;
ConVar gc_iAlpha;

char g_sEfxFile[128];
char g_sEfxName[128];
char g_sModel[128];
char g_sDropSound[128];
char g_sPickUpSound[128];

char g_sChatPrefix[128];
char g_sCreditsName[64];
int g_iSelectedItem[MAXPLAYERS + 1];
float g_fSellRatio;


public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");

	AutoExecConfig_SetFile("drop", "sourcemod/MyStore");
	AutoExecConfig_SetCreateFile(true);

	gc_bDropEnabled = AutoExecConfig_CreateConVar("mystore_drop_enable", "1", "Enable/disable droping of already bought items.", _, true, 0.0, true, 1.0);
	gc_fRemoveTime = AutoExecConfig_CreateConVar("mystore_drop_remove_time", "60.0", "Seconds until remove a dropped item. 0.0 = on round", _, true, 0.0);
	gc_iRemoveType = AutoExecConfig_CreateConVar("mystore_drop_remove_type", "1", "0 - delete / 1 - give back to owner / 2 - Sell item", _, true, 0.0);
	gc_bRotate = AutoExecConfig_CreateConVar("mystore_drop_rotate", "1", "Enable/disable rotate dropped items.", _, true, 0.0, true, 1.0);
	gc_sModel = AutoExecConfig_CreateConVar("mystore_drop_model", "models/props_crates/static_crate_40.mdl", "Path to the drop model")
	gc_sDropSound = AutoExecConfig_CreateConVar("mystore_drop_sound_drop", "physics/wood/wood_deepimpact1.wav", "Path to the drop sound")
	gc_sPickUpSound = AutoExecConfig_CreateConVar("mystore_drop_sound_pickup", "physics/wood/wood_box_break1.wav", "Path to the pickup sound")
	gc_sEfxFile = AutoExecConfig_CreateConVar("mystore_drop_efx_pickup_file", "particles/2j.pcf", "Path to the .pcf file")
	gc_sEfxName = AutoExecConfig_CreateConVar("mystore_drop_efx_pickup_name", "tornado", "name of the particle effect")
	gc_iRed = AutoExecConfig_CreateConVar("mystore_drop_glow_r", "85", "Red value of glow effect (set R, G , B & alpha values to 0 to disable) (Rgb)", _, true, 0.0, true, 255.0);
	gc_iGreen = AutoExecConfig_CreateConVar("mystore_drop_glow_g", "85", "Green value of glow effect (set R, G, B & alpha values to 0 to disable) (rGb)", _, true, 0.0, true, 255.0);
	gc_iBlue = AutoExecConfig_CreateConVar("mystore_drop_glow_b", "5", "Blue value of glow effect (set R, G, B & alpha values to 0 to disable) (rgB)", _, true, 0.0, true, 255.0);
	gc_iAlpha = AutoExecConfig_CreateConVar("mystore_drop_glow_a", "185", "Alpha value of glow effect (set R, G, B & alpha values to 0 to disable) (alpha)", _, true, 0.0, true, 255.0);

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	gc_sModel.AddChangeHook(OnSettingChanged);
	gc_sDropSound.AddChangeHook(OnSettingChanged);
	gc_sPickUpSound.AddChangeHook(OnSettingChanged);

	g_pDrops = new StringMap();

	HookEvent("round_end", Event_RoundEnd);

	MyStore_RegisterItemHandler("drop", Store_OnMenu, Store_OnHandler);
}

public void OnSettingChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == gc_sModel)
	{
		strcopy(g_sModel, sizeof(g_sModel), newValue);
	}
	else if (convar == gc_sDropSound)
	{
		strcopy(g_sDropSound, sizeof(g_sDropSound), newValue);
	}
	else if (convar == gc_sPickUpSound)
	{
		strcopy(g_sPickUpSound, sizeof(g_sPickUpSound), newValue);
	}
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
	strcopy(g_sCreditsName, sizeof(g_sCreditsName), credits);
	gc_sEfxFile.GetString(g_sEfxFile, sizeof(g_sEfxFile));
	gc_sEfxName.GetString(g_sEfxName, sizeof(g_sEfxName));

	g_fSellRatio = FindConVar("mystore_sell_ratio").FloatValue;
	if (g_fSellRatio < 0.1)
	{
		g_fSellRatio = 0.6;
	}
}

public void OnMapStart()
{
	g_pDrops.Clear();

	gc_sModel.GetString(g_sModel, sizeof(g_sModel));
	gc_sDropSound.GetString(g_sDropSound, sizeof(g_sDropSound));
	gc_sPickUpSound.GetString(g_sPickUpSound, sizeof(g_sPickUpSound));

	PrecacheModel(g_sModel, true);
	PrecacheModel("models/props_crates/static_crate_40.mdl", true);
	Downloader_AddFileToDownloadsTable(g_sModel);

	char sBuffer[128];
	FormatEx(sBuffer, sizeof(sBuffer), "sound/%s", g_sDropSound);
	if (FileExists(sBuffer, true) && g_sDropSound[0])
	{
		AddFileToDownloadsTable(sBuffer);
		PrecacheSound(g_sDropSound, true);
	}

	FormatEx(sBuffer, sizeof(sBuffer), "sound/%s", g_sPickUpSound);
	if (FileExists(sBuffer, true) && g_sPickUpSound[0])
	{
		AddFileToDownloadsTable(sBuffer);
		PrecacheSound(g_sPickUpSound, true);
	}

	PrecacheParticleSystem(g_sEfxName);
	if (FileExists(g_sEfxFile, true) && g_sEfxFile[0])
	{
		Downloader_AddFileToDownloadsTable(g_sEfxFile);
		PrecacheGeneric(g_sEfxFile, true);
	}
}

public void Store_OnMenu(Menu &menu, int client, int itemid)
{
	if (!gc_bDropEnabled.BoolValue)
		return;

	if (!MyStore_HasClientItem(client, itemid) || MyStore_IsItemInBoughtPackage(client, itemid))
		return;

	if (MyStore_IsClientVIP(client))
		return;

	any item[Item_Data];
	MyStore_GetItem(itemid, item);

	if (item[iFlagBits] != 0)  ///todo test
		return;

	int clientItem[CLIENT_ITEM_SIZE];
	MyStore_GetClientItem(client, itemid, clientItem);

	if (clientItem[PRICE_PURCHASE] <= 0)
		return;

	any handler[Type_Handler];
	MyStore_GetHandler(item[iHandler], handler);

	char sBuffer[128];
	if (StrEqual(handler[szType], "package"))
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Package Drop");
		menu.AddItem("drop_package", sBuffer, ITEMDRAW_DEFAULT);
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Item Drop");
		menu.AddItem("drop_item", sBuffer, ITEMDRAW_DEFAULT);
	}
}

public bool Store_OnHandler(int client, char[] selection, int itemid)
{
	if (strcmp(selection, "drop_package") == 0 || strcmp(selection, "drop_item") == 0)
	{
		any item[Item_Data];
		MyStore_GetItem(itemid, item);

		g_iSelectedItem[client] = itemid;

		any handler[Type_Handler];
		MyStore_GetHandler(item[iHandler], handler);

		if (MyStore_ShouldConfirm())
		{
			char sTitle[128];
			Format(sTitle, sizeof(sTitle), "%t", "Confirm_Drop", item[szName], handler[szType]);
			MyStore_DisplayConfirmMenu(client, sTitle, Store_OnConfirmHandler, 1);
		}
		else
		{
			DropItem(client, itemid);
			MyStore_DisplayPreviousMenu(client);
		}

		return true;
	}

	return false;
}

public void Store_OnConfirmHandler(Menu menu, MenuAction action, int client, int param2)
{
	DropItem(client, g_iSelectedItem[client]);
	MyStore_DisplayPreviousMenu(client);
}

void DropItem(int client, int itemid)
{
	if (!gc_bEnable.BoolValue)
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Store Disabled");
		return;
	}

	int iDrop = CreateEntityByName("prop_dynamic_override"); //prop_dynamic_override

	if (!iDrop)
		return;

	char sBuffer[32];
	FormatEx(sBuffer, 32, "drop_%d", iDrop);
	SetEntPropString(iDrop, Prop_Data, "m_iName", sBuffer);

	SetEntProp(iDrop, Prop_Send, "m_usSolidFlags", 12); //FSOLID_NOT_SOLID|FSOLID_TRIGGER
	SetEntProp(iDrop, Prop_Data, "m_nSolidType", 6); // SOLID_VPHYSICS
	SetEntProp(iDrop, Prop_Send, "m_CollisionGroup", 1); //COLLISION_GROUP_DEBRIS

	DispatchKeyValue(iDrop, "model", g_sModel);
	DispatchSpawn(iDrop);

	AcceptEntityInput(iDrop, "Enable");
	ActivateEntity(iDrop);

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

	fPos[2] += 10;

	TeleportEntity(iDrop, fPos, fAng, NULL_VECTOR);

	CreateGlow(iDrop);
	CreateRotator(iDrop, fPos);

	CreateTriggerProp(iDrop, fPos, sBuffer);

	int clientItem[CLIENT_ITEM_SIZE];
	MyStore_GetClientItem(client, itemid, clientItem);

	DataPack pack = new DataPack();
	pack.WriteCell(itemid); // itemid
	pack.WriteCell(client); // client
	pack.WriteCell(iDrop); // model
	pack.WriteCell(clientItem[DATE_PURCHASE]); // date purchase
	pack.WriteCell(clientItem[DATE_EXPIRATION]); // date expiration
	pack.WriteCell(clientItem[PRICE_PURCHASE]); // price
	g_pDrops.SetValue(sBuffer, pack);

	MyStore_RemoveItem(client, itemid);

	if (gc_fRemoveTime.FloatValue > 0.0)
	{
		CreateTimer(gc_fRemoveTime.FloatValue, Timer_KillDrop, EntIndexToEntRef(iDrop));
	}

	EmitAmbientSound(g_sDropSound, fPos, _, _, _, _, _, _);

	CPrintToChatAll("%s%t", g_sChatPrefix, "Dropped an item", client);
}

void CreateRotator(int ent, float pos[3])
{
	if (gc_bRotate.BoolValue)
	{
		int iRotator = CreateEntityByName("func_rotating");
		DispatchKeyValueVector(iRotator, "origin", pos);

		DispatchKeyValue(iRotator, "spawnflags", "64");
		DispatchKeyValue(iRotator, "maxspeed", "20");
		DispatchSpawn(iRotator);

		SetVariantString("!activator");
		AcceptEntityInput(ent, "SetParent", iRotator, iRotator);
		AcceptEntityInput(iRotator, "Start");
	}
}

void CreateGlow(int ent)
{
	int iOffset = GetEntSendPropOffs(ent, "m_clrGlow");
	SetEntProp(ent, Prop_Send, "m_bShouldGlow", true, true);
	SetEntProp(ent, Prop_Send, "m_nGlowStyle", 0);
	SetEntPropFloat(ent, Prop_Send, "m_flGlowMaxDist", 2000.0);


	SetEntData(ent, iOffset, gc_iRed.IntValue, _, true);
	SetEntData(ent, iOffset + 1, gc_iGreen.IntValue, _, true);
	SetEntData(ent, iOffset + 2, gc_iBlue.IntValue, _, true);
	SetEntData(ent, iOffset + 3, gc_iAlpha.IntValue, _, true);
}

void CreateTriggerProp(int ent, float pos[3], char[] name)
{
	int iEnt = CreateEntityByName("prop_dynamic_override");

	SetEntPropString(iEnt, Prop_Data, "m_iName", name);

	DispatchKeyValue(iEnt, "spawnflags", "64");

	DispatchKeyValue(iEnt, "model", "models/props_crates/static_crate_40.mdl");
	DispatchSpawn(iEnt);

	AcceptEntityInput(iEnt, "Enable");

	SetEntProp(iEnt, Prop_Data, "m_spawnflags", 64);

	TeleportEntity(iEnt, pos, NULL_VECTOR, NULL_VECTOR);

	float fMins[3];
	float fMaxs[3];

	GetEntPropVector(ent, Prop_Send, "m_vecMins", fMins);
	GetEntPropVector(ent, Prop_Send, "m_vecMaxs", fMaxs);

	fMins[0] += -5.0;
	fMins[1] += -5.0;
	fMins[2] += -5.0;
	fMaxs[0] += 5.0;
	fMaxs[1] += 5.0;
	fMaxs[2] += 5.0;

	SetEntPropVector(iEnt, Prop_Send, "m_vecMins", fMins);
	SetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", fMaxs);
	SetEntProp(iEnt, Prop_Send, "m_nSolidType", 2);

	int iEffects = GetEntProp(iEnt, Prop_Send, "m_fEffects");
	iEffects |= 32;
	SetEntProp(iEnt, Prop_Send, "m_fEffects", iEffects);

	SDKHook(iEnt, SDKHook_StartTouch, Hook_StartTouch);
}

public Action Timer_KillDrop(Handle timer, int entRef)
{
	int entity = EntRefToEntIndex(entRef);
	if (entity == INVALID_ENT_REFERENCE || !IsValidEntity(entity))
		return Plugin_Stop;

	if (IsValidEdict(entity))
	{
		AcceptEntityInput(entity, "Kill");
	}

	char sBuffer[32];
	FormatEx(sBuffer, 32, "drop_%d", entity);

	DataPack pack;
	if (!g_pDrops.GetValue(sBuffer, pack))
		return Plugin_Stop;

	g_pDrops.Remove(sBuffer);

	pack.Reset();
	int itemid = pack.ReadCell(); // itemid
	int dropper = pack.ReadCell(); // client
	int entity_model = pack.ReadCell(); // model
	int purchase = pack.ReadCell(); // date purchase
	int expiration = pack.ReadCell(); // date expiration
	int price = pack.ReadCell(); // price
	delete pack;

	if (IsValidEdict(entity_model))
	{
		AcceptEntityInput(entity_model, "Kill");
	}

	switch(gc_iRemoveType.IntValue)
	{
		case 0: CPrintToChat(dropper, "%s%t", g_sChatPrefix, "No pick up - removed");
		case 1:
		{
			MyStore_GiveItem(dropper, itemid, purchase, expiration, price);
			CPrintToChat(dropper, "%s%t", g_sChatPrefix, "No pick up - back to you");
		}
		case 2:
		{
			MyStore_GiveItem(dropper, itemid, purchase, expiration, price);
			CPrintToChat(dropper, "%s%t", g_sChatPrefix, "No pick up - back to you");
			
		}
	}

	return Plugin_Stop;
}

public void Event_RoundEnd(Event event, char[] name, bool dontBroadcast)
{
	int entity;
	char sBuffer[32];
	while ((entity = FindEntityByClassname(entity, "prop_dynamic_override")) != INVALID_ENT_REFERENCE)
	{
		GetEntPropString(entity, Prop_Data, "m_iName", sBuffer, sizeof(sBuffer))
		DataPack pack;
		if (g_pDrops.GetValue(sBuffer, pack))
		{
			g_pDrops.Remove(sBuffer);

			pack.Reset();
			int itemid = pack.ReadCell(); // itemid
			int dropper = pack.ReadCell(); // client
			int entity_model = pack.ReadCell(); // model
			int purchase = pack.ReadCell(); // date purchase
			int expiration = pack.ReadCell(); // date expiration
			int price = pack.ReadCell(); // price
			delete pack;

			if (IsValidEdict(entity_model))
			{
				AcceptEntityInput(entity_model, "Kill");
			}

			switch(gc_iRemoveType.IntValue)
			{
				case 0: CPrintToChat(dropper, "%s%t", g_sChatPrefix, "No pick up - removed");
				case 1:
				{
					MyStore_GiveItem(dropper, itemid, purchase, expiration, price);
					CPrintToChat(dropper, "%s%t", g_sChatPrefix, "No pick up - back to you");
				}
				case 2:
				{
					MyStore_GiveItem(dropper, itemid, purchase, expiration, price);
					CPrintToChat(dropper, "%s%t", g_sChatPrefix, "No pick up - back to you");
					MyStore_SellClientItem(dropper, itemid, g_fSellRatio);
				}
			}

			if (IsValidEdict(entity))
			{
				AcceptEntityInput(entity, "Kill");
			}
		}
		delete pack;
	}
}

public void Hook_StartTouch(int entity, int client)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
		return;

	if (MyStore_IsClientVIP(client))
		return;

	char sBuffer[32];
	GetEntPropString(entity, Prop_Data, "m_iName", sBuffer, sizeof(sBuffer));

	DataPack pack;
	if (!g_pDrops.GetValue(sBuffer, pack))
		return;

	pack.Reset();
	int itemid = pack.ReadCell(); // itemid
	int dropper = pack.ReadCell(); // client
	int entity_model = pack.ReadCell(); // model
	int purchase = pack.ReadCell(); // date purchase
	int expiration = pack.ReadCell(); // date expiration
	int price = pack.ReadCell(); // price

	any item[Item_Data];
	MyStore_GetItem(itemid, item);

	if (MyStore_HasClientItem(client, itemid) && gc_iRemoveType.IntValue != 2)
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Cannot pickup", item[szName]);
		return;
	}
	else if (MyStore_HasClientItem(client, itemid) && gc_iRemoveType.IntValue == 2)
	{
		MyStore_GiveItem(client, itemid, purchase, expiration, price);
		MyStore_SellClientItem(client, itemid, g_fSellRatio);
	}
	else
	{
		MyStore_GiveItem(client, itemid, purchase, expiration, price);
	}

	float fVec[3];
	GetClientAbsOrigin(client, fVec);
	EmitAmbientSound(g_sPickUpSound, fVec, _, _, _, _, _, _);

	g_pDrops.Remove(sBuffer);
	delete pack;

	if (IsValidEdict(entity_model))
	{
		AcceptEntityInput(entity_model, "Kill");
	}
	if (IsValidEdict(entity))
	{
		AcceptEntityInput(entity, "Kill");
	}

	CPrintToChat(dropper, "%s%t", g_sChatPrefix, "Your drop picked up", item[szName], client);
	CPrintToChat(client, "%s%t", g_sChatPrefix, "You picked up", item[szName], dropper);
	MyStore_LogMessage(client, LOG_EVENT, "Picked up item '%s' dropped by %L worth: %i credits", item[szName], dropper, price);

	if (!g_sEfxName[0])
		return;

	float fOri[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fOri);

	int iEfx = CreateEntityByName("info_particle_system");
	DispatchKeyValue(iEfx, "start_active", "0");
	DispatchKeyValue(iEfx, "effect_name", g_sEfxName);
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
		if (IsValidEntity(iEnt))
		AcceptEntityInput(iEnt, "kill");
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
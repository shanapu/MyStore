/*
 * MyStore - Jetpack item module
 * by: shanapu
 * https://github.com/shanapu/
 * 
 * Copyright (C) 2018-2019 Thomas Schmidt (shanapu)
 * Credits: gubka & FrozDark - https://forums.alliedmods.net/showthread.php?p=2369671
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
#include <cstrike>

#include <mystore> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/mystore.inc

#include <smartdm> //https://forums.alliedmods.net/attachment.php?attachmentid=136152&d=1406298576
#include <colors> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/colors.inc
#include <autoexecconfig> //https://raw.githubusercontent.com/Impact123/AutoExecConfig/development/autoexecconfig.inc

#pragma semicolon 1
#pragma newdecls required

bool g_bJetpacking[MAXPLAYERS + 1] = {false,...};
bool g_bEquipt[MAXPLAYERS + 1] = false;
bool g_bDelay[MAXPLAYERS + 1];
bool g_bParachute[MAXPLAYERS + 1];

char g_sChatPrefix[128];

ConVar gc_bCommand;
ConVar gc_bEnable;

Handle g_hTimerFly[MAXPLAYERS + 1];
Handle g_hTimerReload[MAXPLAYERS + 1];

int g_iCount = 0;
int g_iJumps[MAXPLAYERS + 1];
int g_iParaEntRef[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

enum Jetpack
{
	String:szModel[PLATFORM_MAX_PATH],
	Float:fJetPackBoost,
	Float:fReloadDelay,
	Float:fJetPackMax,
	iJetPackAngle,
	iTeam,
	bool:bEffect
}
any g_aJetpack[STORE_MAX_ITEMS][Jetpack];

/*
 * Build date: <DATE>
 * Build number: <BUILD>
 * Commit: https://github.com/shanapu/MyStore/commit/<COMMIT>
 */

public Plugin myinfo = 
{
	name = "MyStore - Jetpack item module",
	author = "shanapu",
	description = "",
	version = "0.1.<BUILD>",
	url = "github.com/shanapu/MyStore"
};

public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");

	AutoExecConfig_SetFile("items", "sourcemod/MyStore");
	AutoExecConfig_SetCreateFile(true);

	RegConsoleCmd("+jetpack", Command_JetpackON);
	RegConsoleCmd("-jetpack", Command_JetpackOFF);

	MyStore_RegisterHandler("jetpack", Jetpack_OnMapStart, Jetpack_Reset, Jetpack_Config, Jetpack_Equip, Jetpack_Remove, true);

	gc_bCommand = AutoExecConfig_CreateConVar("store_jetpack_cmd", "0", "0 - DUCK & JUMP, 1 - +/-jetpack", _, true, 0.0, true, 1.0);

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	HookEvent("player_death", OnPlayerDeath);
}


public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}


public void Jetpack_OnMapStart()
{
	for (int i = 0; i < g_iCount; i++)
	{
		if (!g_aJetpack[i][szModel][0])
			continue;

		Downloader_AddFileToDownloadsTable(g_aJetpack[i][szModel]);

		if (IsModelPrecached(g_aJetpack[i][szModel]))
			continue;

		PrecacheModel(g_aJetpack[i][szModel], true);
	}
}

public void Jetpack_Reset()
{
	g_iCount = 0;
}

public void OnClientConnected(int client)
{
	g_bJetpacking[client] = false;
}

public bool Jetpack_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, g_iCount);

	kv.GetString("model", g_aJetpack[g_iCount][szModel], PLATFORM_MAX_PATH, "");

	g_aJetpack[g_iCount][fJetPackBoost] = kv.GetFloat("boost", 400.0);
	g_aJetpack[g_iCount][iJetPackAngle] = kv.GetNum("angle", 50);
	g_aJetpack[g_iCount][fJetPackMax] = kv.GetFloat("max_time", 10.0);
	g_aJetpack[g_iCount][fReloadDelay] = kv.GetFloat("delay", 60.0);
	g_aJetpack[g_iCount][iTeam] = kv.GetNum("team", 0);
	g_aJetpack[g_iCount][bEffect] = view_as<bool>(kv.GetNum("effect", 1));

	g_iCount++;

	return true;
}

public int Jetpack_Equip(int client, int itemid)
{
	g_bEquipt[client] = true;

	return ITEM_EQUIP_SUCCESS;
}

public int Jetpack_Remove(int client, int itemid)
{
	g_bEquipt[client] = false;

	return ITEM_EQUIP_REMOVE;
}

public void OnClientDisconnect(int client)
{
	g_bEquipt[client] = false;
}

public void OnClientDisconnect_Post(int client)
{
	g_iJumps[client] = 0;
	g_bDelay[client] = false;

	delete g_hTimerReload[client];
}

public void OnPlayerDeath(Event event, const char [] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (g_bDelay[client])
	{
		OnClientDisconnect_Post(client);
	}
}

public Action Command_JetpackON(int client, int args)
{
	if (!gc_bEnable.BoolValue)
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Store Disabled");
		return Plugin_Handled;
	}

	if (gc_bCommand.BoolValue)
	{
		g_hTimerFly[client] = CreateTimer(0.1, Timer_Fly, GetClientUserId(client), TIMER_REPEAT);
	}

	return Plugin_Handled;
}

public Action Command_JetpackOFF(int client, int args)
{
	delete g_hTimerFly[client];
	DisableParachute(client);

	return Plugin_Handled;
}


public Action Timer_Fly(Handle tmr, int userid)
{
	int client = GetClientOfUserId(userid);

	if (!g_bEquipt[client])
		return Plugin_Continue;

	if (!gc_bEnable.BoolValue)
		return Plugin_Continue;

	if (!IsClientConnected(client) || g_bDelay[client])
		return Plugin_Handled;

	if ((GetClientTeam(client) != CS_TEAM_T && g_aJetpack[g_iCount][iTeam] == 1) || (GetClientTeam(client) != CS_TEAM_CT && g_aJetpack[g_iCount][iTeam] == 2) || !IsPlayerAlive(client))
		return Plugin_Handled;

	int iEquipped = MyStore_GetEquippedItem(client, "jetpack");
	if (iEquipped < 0)
		return Plugin_Continue;

	int iIndex = MyStore_GetDataIndex(iEquipped);

	if (0 <= g_iJumps[client] <= g_aJetpack[iIndex][fJetPackMax])
	{
		if (g_aJetpack[iIndex][fJetPackMax] != 0.0)
		{
			g_iJumps[client]++;
		}

		float ClientEyeAngle[3];
		float ClientAbsOrigin[3];
		float Velocity[3];

		GetClientEyeAngles(client, ClientEyeAngle);
		GetClientAbsOrigin(client, ClientAbsOrigin);

		float newAngle = g_aJetpack[g_iCount][iJetPackAngle] * -1.0;
		ClientEyeAngle[0] = newAngle;
		GetAngleVectors(ClientEyeAngle, Velocity, NULL_VECTOR, NULL_VECTOR);

		ScaleVector(Velocity, g_aJetpack[g_iCount][fJetPackBoost]);

		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, Velocity);

		g_bDelay[client] = true;
		CreateTimer(0.1, Timer_DelayOff, GetClientUserId(client));

		if (g_aJetpack[g_iCount][bEffect])
		{
			CreateEffect(client, ClientAbsOrigin, ClientEyeAngle);
		}

		if (g_aJetpack[client][szModel][0] && !g_bParachute[client])
		{
			// Open parachute
			int iEntity = CreateEntityByName("prop_dynamic_override");
			DispatchKeyValue(iEntity, "model", g_aJetpack[client][szModel]);
			DispatchSpawn(iEntity);

			SetEntityMoveType(iEntity, MOVETYPE_NOCLIP);

			// Teleport to player
			float fPos[3];
			float fAng[3];
			GetClientAbsOrigin(client, fPos);
			GetClientAbsAngles(client, fAng);
			fAng[0] = 0.0;
			TeleportEntity(iEntity, fPos, fAng, NULL_VECTOR);

			// Parent to player
			char sClient[16];
			Format(sClient, 16, "client%i", client);
			DispatchKeyValue(client, "targetname", sClient);
			SetVariantString(sClient);
			AcceptEntityInput(iEntity, "SetParent", iEntity, iEntity, 0);
			g_iParaEntRef[client] = EntIndexToEntRef(iEntity);
			g_bParachute[client] = true;
		}

		if (g_iJumps[client] == g_aJetpack[g_iCount][fJetPackMax] && g_aJetpack[g_iCount][fReloadDelay] != 0)
		{
			delete g_hTimerFly[client];
			DisableParachute(client);

			g_hTimerReload[client] = CreateTimer(g_aJetpack[g_iCount][fReloadDelay], Timer_Reload, GetClientUserId(client));

			PrintCenterText(client, "%t", "Jetpack Empty");

			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}


void DisableParachute(int client)
{
	int iEntity = EntRefToEntIndex(g_iParaEntRef[client]);
	if (iEntity != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(iEntity, "ClearParent");
		AcceptEntityInput(iEntity, "kill");
	}

	g_bParachute[client] = false;
	g_iParaEntRef[client] = INVALID_ENT_REFERENCE;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (!g_bEquipt[client])
		return Plugin_Continue;

	if (gc_bCommand.BoolValue)
		return Plugin_Continue;

	if (!gc_bEnable.BoolValue)
		return Plugin_Continue;

	if (!IsPlayerAlive(client) || g_bDelay[client])
		return Plugin_Continue;

	if ((GetClientTeam(client) != 2 && g_aJetpack[g_iCount][iTeam] == 1) || (GetClientTeam(client) != 3 && g_aJetpack[g_iCount][iTeam] == 2))
		return Plugin_Continue;

	int iEquipped = MyStore_GetEquippedItem(client, "jetpack");
	if (iEquipped < 0)
		return Plugin_Continue;

	int iIndex = MyStore_GetDataIndex(iEquipped);

	if (buttons & IN_JUMP && buttons & IN_DUCK)
	{
		if (0 <= g_iJumps[client] <= g_aJetpack[iIndex][fJetPackMax])
		{
			if (g_aJetpack[iIndex][fJetPackMax] != 0.0)
			{
				g_iJumps[client]++;
			}

			float ClientEyeAngle[3];
			float ClientAbsOrigin[3];
			float Velocity[3];

			GetClientEyeAngles(client, ClientEyeAngle);
			GetClientAbsOrigin(client, ClientAbsOrigin);

			float newAngle = g_aJetpack[iIndex][iJetPackAngle] * -1.0;
			ClientEyeAngle[0] = newAngle;
			GetAngleVectors(ClientEyeAngle, Velocity, NULL_VECTOR, NULL_VECTOR);

			ScaleVector(Velocity, g_aJetpack[iIndex][fJetPackBoost]);

			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, Velocity);

			g_bDelay[client] = true;
			CreateTimer(0.1, Timer_DelayOff, GetClientUserId(client));

			if (g_aJetpack[g_iCount][bEffect])
			{
				CreateEffect(client, ClientAbsOrigin, ClientEyeAngle);
			}

			if (g_aJetpack[client][szModel][0] && !g_bParachute[client])
			{
				// Open parachute
				int iEntity = CreateEntityByName("prop_dynamic_override");
				DispatchKeyValue(iEntity, "model", g_aJetpack[client][szModel]);
				DispatchSpawn(iEntity);

				SetEntityMoveType(iEntity, MOVETYPE_NOCLIP);

				// Teleport to player
				float fPos[3];
				float fAng[3];
				GetClientAbsOrigin(client, fPos);
				GetClientAbsAngles(client, fAng);
				fAng[0] = 0.0;
				TeleportEntity(iEntity, fPos, fAng, NULL_VECTOR);

				// Parent to player
				char sClient[16];
				Format(sClient, 16, "client%i", client);
				DispatchKeyValue(client, "targetname", sClient);
				SetVariantString(sClient);
				AcceptEntityInput(iEntity, "SetParent", iEntity, iEntity, 0);
				g_iParaEntRef[client] = EntIndexToEntRef(iEntity);
				g_bParachute[client] = true;
			}


			if (g_iJumps[client] == g_aJetpack[iIndex][fJetPackMax] && g_aJetpack[iIndex][fReloadDelay] != 0.0)
			{
				g_hTimerReload[client] = CreateTimer(g_aJetpack[iIndex][fReloadDelay], Timer_Reload, GetClientUserId(client));
				DisableParachute(client);
				PrintCenterText(client, "%t", "Jetpack Empty");
			}
		}
		else
		{
			DisableParachute(client);
		}
	}
	else if (g_bParachute[client])
	{
		DisableParachute(client);
	}

	return Plugin_Continue;
}

void CreateEffect(int client, float vecorigin[3], float vecangle[3])
{
	vecangle[0] = 110.0;
	vecorigin[2] += 25.0;

	char tName[128];
	Format(tName, sizeof(tName), "target%i", client);
	DispatchKeyValue(client, "targetname", tName);

	// Create the fire
	char fire_name[128];
	Format(fire_name, sizeof(fire_name), "fire%i", client);
	int fire = CreateEntityByName("env_sprite");
	DispatchKeyValue(fire,"targetname", fire_name);
	DispatchKeyValue(fire, "parentname", tName);
	DispatchKeyValue(fire,"SpawnFlags", "1");
	DispatchKeyValue(fire,"Type", "0");
	DispatchKeyValue(fire,"InitialState", "1");
	DispatchKeyValue(fire,"Spreadspeed", "10");
	DispatchKeyValue(fire,"Speed", "400");
	DispatchKeyValue(fire,"Startsize", "20");
	DispatchKeyValue(fire,"EndSize", "600");
	DispatchKeyValue(fire,"Rate", "30");
	DispatchKeyValue(fire,"JetLength", "200");
	DispatchKeyValue(fire,"RenderColor", "255 100 30");
	DispatchKeyValue(fire,"RenderAmt", "180");
	DispatchSpawn(fire);

	TeleportEntity(fire, vecorigin, vecangle, NULL_VECTOR);
	SetVariantString(tName);
	AcceptEntityInput(fire, "SetParent", fire, fire, 0);

	AcceptEntityInput(fire, "TurnOn");

	char fire_name2[128];
	Format(fire_name2, sizeof(fire_name2), "fire2%i", client);
	int fire2 = CreateEntityByName("env_sprite");
	DispatchKeyValue(fire2,"targetname", fire_name2);
	DispatchKeyValue(fire2, "parentname", tName);
	DispatchKeyValue(fire2,"SpawnFlags", "1");
	DispatchKeyValue(fire2,"Type", "1");
	DispatchKeyValue(fire2,"InitialState", "1");
	DispatchKeyValue(fire2,"Spreadspeed", "10");
	DispatchKeyValue(fire2,"Speed", "400");
	DispatchKeyValue(fire2,"Startsize", "20");
	DispatchKeyValue(fire2,"EndSize", "600");
	DispatchKeyValue(fire2,"Rate", "10");
	DispatchKeyValue(fire2,"JetLength", "200");
	DispatchSpawn(fire2);
	TeleportEntity(fire2, vecorigin, vecangle, NULL_VECTOR);
	SetVariantString(tName);
	AcceptEntityInput(fire2, "SetParent", fire2, fire2, 0);
	AcceptEntityInput(fire2, "TurnOn");

	DataPack firedata = new DataPack();
	firedata.WriteCell(fire);
	firedata.WriteCell(fire2);
	CreateTimer(0.5, Killfire, firedata);
}

public Action Killfire(Handle timer, DataPack firedata)
{
	firedata.Reset();
	int ent1 = firedata.ReadCell();
	int ent2 = firedata.ReadCell();
	delete firedata;

	char classname[256];

	if (IsValidEntity(ent1))
	{
		AcceptEntityInput(ent1, "TurnOff");
		GetEdictClassname(ent1, classname, sizeof(classname));
		if (!strcmp(classname, "env_steam", false))
			AcceptEntityInput(ent1, "kill");
	}

	if (IsValidEntity(ent2))
	{
		AcceptEntityInput(ent2, "TurnOff");
		GetEdictClassname(ent2, classname, sizeof(classname));
		if (StrEqual(classname, "env_steam", false))
			AcceptEntityInput(ent2, "kill");
	}
}

public Action Timer_DelayOff(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);

	if (!client)
		return Plugin_Stop;

	g_bDelay[client] = false;

	return Plugin_Stop;
}

public Action Timer_Reload(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);

	if (!client)
		return Plugin_Stop;

	if (g_hTimerReload[client] != null)
	{
		g_iJumps[client] = 0;
		PrintCenterText(client, "%t", "Jetpack Reloaded");
		g_hTimerReload[client] = null;
	}

	return Plugin_Stop;
}
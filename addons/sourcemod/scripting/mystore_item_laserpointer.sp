/*
 * MyStore - Laser pointer item module
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

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <clientprefs>

#include <mystore> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/mystore.inc

#include <colors> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/colors.inc

int g_iColors[STORE_MAX_ITEMS][4];

bool g_bRandom[STORE_MAX_ITEMS];
bool g_bPerm[STORE_MAX_ITEMS];
bool g_bEquipt[MAXPLAYERS + 1] = false;
int g_iEquipt[MAXPLAYERS + 1] = {-1, ...};

ConVar gc_bEnable;

int g_iCount = 0;
int g_iBeamSprite = -1;
int g_iHaloSprite = -1;

bool g_bHide[MAXPLAYERS + 1];
Handle g_hHideCookie = INVALID_HANDLE;

char g_sChatPrefix[128];

/*
 * Build date: <DATE>
 * Build number: <BUILD>
 * Commit: https://github.com/shanapu/MyStore/commit/<COMMIT>
 */

public Plugin myinfo = 
{
	name = "MyStore - Laser pointer item module",
	author = "shanapu", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "",
	version = "0.1.<BUILD>", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = "github.com/shanapu/MyStore"
};

public void OnPluginStart()
{
	if (MyStore_RegisterHandler("laserpointer", LaserPointer_OnMapStart, LaserPointer_Reset, LaserPointer_Config, LaserPointer_Equip, LaserPointer_Remove, true) == -1)
	{
		SetFailState("Can't Register module to core - Reached max module types(%i).", STORE_MAX_TYPES);
	}

	RegConsoleCmd("sm_hidelaserpointer", Command_Hide, "Hide the LaserPointer");

	g_hHideCookie = RegClientCookie("LaserPointer_Hide_Cookie", "Cookie to check if LaserPointer are blocked", CookieAccess_Private);
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
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Item hidden", "laserpointer");
		SetClientCookie(client, g_hHideCookie, "1");
	}
	else
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Item visible", "laserpointer");
		SetClientCookie(client, g_hHideCookie, "0");
	}

	return Plugin_Handled;
}


public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

public void LaserPointer_OnMapStart()
{
	g_iBeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt", true); 
	g_iHaloSprite = PrecacheModel("materials/sprites/glow01.vmt", true); 
}

public void LaserPointer_Reset()
{
	g_iCount = 0;
}

public bool LaserPointer_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, g_iCount);

	kv.GetColor("color", g_iColors[g_iCount][0], g_iColors[g_iCount][1], g_iColors[g_iCount][2], g_iColors[g_iCount][3]);
	if (g_iColors[g_iCount][3] == 0)
	{
		g_iColors[g_iCount][3] = 255;
	}

	g_bRandom[g_iCount] = kv.GetNum("random", 0) ? true : false;
	g_bPerm[g_iCount] = kv.GetNum("perm", 0) ? true : false;

	g_iCount++;

	return true;
}

public int LaserPointer_Equip(int client, int itemid)
{
	g_bEquipt[client] = true;
	g_iEquipt[client] = MyStore_GetDataIndex(itemid);

	return ITEM_EQUIP_SUCCESS;
}

public int LaserPointer_Remove(int client, int itemid)
{
	g_bEquipt[client] = false;

	return ITEM_EQUIP_REMOVE;
}

public void OnClientDisconnect(int client)
{
	g_bEquipt[client] = false;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (!g_bEquipt[client])
		return Plugin_Continue;

	if (!gc_bEnable.BoolValue)
		return Plugin_Continue;

	if (buttons & IN_USE || g_bPerm[g_iEquipt[client]])
	{
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
			return Plugin_Continue;

		int iIndex = g_iEquipt[client];
		if (g_bRandom[iIndex])
		{
			iIndex = GetRandomInt(0, g_iCount);
		}

		float fOri[3];
		float fImpact[3];

		GetClientEyePosition(client, fOri);
		GetClientSightEnd(client, fImpact);
		TE_SetupBeamPoints(fOri, fImpact, g_iBeamSprite, 0, 0, 0, 0.1, 0.12, 0.0, 1, 0.0, g_iColors[iIndex], 0);

		TE_Send(clients, numClients, 0.0);
		TE_SetupGlowSprite(fImpact, g_iHaloSprite, 0.1, 0.25, g_iColors[iIndex][3]);
		TE_Send(clients, numClients, 0.0);
	}

	return Plugin_Continue;
}

Handle GetClientSightEnd(int client, float out[3])
{
	float fEyes[3];
	float fOri[3];
	GetClientEyePosition(client, fEyes);
	GetClientEyeAngles(client, fOri);
	TR_TraceRayFilter(fEyes, fOri, MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitPlayers);

	if (TR_DidHit())
	{
		TR_GetEndPosition(out);
	}
}

public bool TraceRayDontHitPlayers(int entity, int mask, any data)
{
	if (0 < entity <= MaxClients)
	{
		return false;
	}

	return true;
}
/*
 * MyStore - Jumpstyles item module
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

#include <mystore> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/mystore.inc

bool g_bEquiptBunny[MAXPLAYERS + 1] = false;
bool g_bEquiptFroggy[MAXPLAYERS + 1] = false;
bool g_bEquiptHunter[MAXPLAYERS + 1] = false;

int g_iBunny = -1;
int g_iFroggy = -1;
int g_iHunter = -1;

bool g_bPressed[MAXPLAYERS + 1] = {false, ...};
float g_LeapLastTime[MAXPLAYERS + 1];

ConVar gc_bEnable;

int g_iJumped[MAXPLAYERS + 1] = {0, ...};

public void OnPluginStart()
{
	MyStore_RegisterHandler("bunnyhob", _, _, Bunnyhop_Config, Bunnyhop_Equip, Bunnyhop_Remove, true);
	MyStore_RegisterHandler("froggyjump", _, _, FroggyJump_Config, FroggyJump_Equip, FroggyJump_Remove, true);
//	MyStore_RegisterHandler("hunterjump", _, _, HunterJump_Config, HunterJump_Equip, HunterJump_Remove, true); //todo
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
}

public bool Bunnyhop_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, 0);
	g_iBunny = itemid;

	return true;
}

public bool FroggyJump_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, 0);
	g_iFroggy = itemid;

	return true;
}

public bool HunterJump_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, 0);
	g_iHunter = itemid;

	return true;
}

public int Bunnyhop_Equip(int client, int itemid)
{
	g_bEquiptBunny[client] = true;
	g_bEquiptFroggy[client] = false;
	g_bEquiptHunter[client] = false;
	MyStore_UnequipItem(client, g_iFroggy);
	MyStore_UnequipItem(client, g_iHunter);

	return ITEM_EQUIP_SUCCESS;
}

public int FroggyJump_Equip(int client, int itemid)
{
	g_bEquiptFroggy[client] = true;
	g_bEquiptBunny[client] = false;
	g_bEquiptHunter[client] = false;
	MyStore_UnequipItem(client, g_iBunny);
	MyStore_UnequipItem(client, g_iHunter);

	return ITEM_EQUIP_SUCCESS;
}


public int HunterJump_Equip(int client, int itemid)
{
	g_bEquiptHunter[client] = true;
	g_bEquiptBunny[client] = false;
	g_bEquiptFroggy[client] = false;
	MyStore_UnequipItem(client, g_iBunny);
	MyStore_UnequipItem(client, g_iFroggy);

	return ITEM_EQUIP_SUCCESS;
}

public int Bunnyhop_Remove(int client, int itemid)
{
	g_bEquiptBunny[client] = false;

	return ITEM_EQUIP_REMOVE;
}

public int FroggyJump_Remove(int client, int itemid)
{
	g_bEquiptFroggy[client] = false;

	return ITEM_EQUIP_REMOVE;
}

public int HunterJump_Remove(int client, int itemid)
{
	g_bEquiptHunter[client] = false;

	return ITEM_EQUIP_REMOVE;
}

public void OnClientDisconnect(int client)
{
	g_bEquiptHunter[client] = false;
	g_bEquiptFroggy[client] = false;
	g_bEquiptBunny[client] = false;
}


public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (!gc_bEnable.BoolValue)
		return Plugin_Continue;

	if (!IsPlayerAlive(client))
		return Plugin_Continue;

	if (g_bEquiptBunny[client])
	{
		if (buttons & IN_JUMP)
		{
			int iWater = GetEntProp(client, Prop_Data, "m_nWaterLevel");
			if (iWater > 1)
				return Plugin_Continue;

			if (!(GetEntityMoveType(client) & MOVETYPE_LADDER))
			{
				SetEntPropFloat(client, Prop_Send, "m_flStamina", 0.0);
				if (!(GetEntityFlags(client) & FL_ONGROUND))
				{
					buttons &=  ~IN_JUMP;
				}
			}
		}
	}
	else if (g_bEquiptFroggy[client])
	{
		// Reset when on Ground
		if (GetEntityFlags(client) & FL_ONGROUND)
		{
			g_iJumped[client] = 0;
			g_bPressed[client] = false;
		}
		else
		{
			// Player pressed jump button?
			if (buttons & IN_JUMP)
			{
				// For second time?
				if (!g_bPressed[client] && g_iJumped[client]++ == 1)
				{
					float velocity[3];
					float velocity0;
					float velocity1;
					float velocity2;
					float velocity2_new;

					// Get player velocity
					velocity0 = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[0]");
					velocity1 = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[1]");
					velocity2 = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[2]");

					velocity2_new = 200.0;

					// calculate new velocity^^
					if (velocity2 < 150.0) velocity2_new = velocity2_new + 20.0;
				
					if (velocity2 < 100.0) velocity2_new = velocity2_new + 30.0;
				
					if (velocity2 < 50.0) velocity2_new = velocity2_new + 40.0;
				
					if (velocity2 < 0.0) velocity2_new = velocity2_new + 50.0;
				
					if (velocity2 < -50.0) velocity2_new = velocity2_new + 60.0;
				
					if (velocity2 < -100.0) velocity2_new = velocity2_new + 70.0;
				
					if (velocity2 < -150.0) velocity2_new = velocity2_new + 80.0;
				
					if (velocity2 < -200.0) velocity2_new = velocity2_new + 90.0;

					// Set new velocity
					velocity[0] = velocity0 * 0.1;
					velocity[1] = velocity1 * 0.1;
					velocity[2] = velocity2_new;

					// Double Jump
					SetEntPropVector(client, Prop_Send, "m_vecBaseVelocity", velocity);
				}

				g_bPressed[client] = true;
			}
			else g_bPressed[client] = false;
		}
	}
	else if (g_bEquiptHunter[client])
	{
		if (!(buttons & IN_JUMP))
			return Plugin_Continue;

		if (GetGameTime() - g_LeapLastTime[client] < 6.0)
		{
			PrintHintText(client, "Reloading - %.1f", 6.0 - (GetGameTime() - g_LeapLastTime[client]));
			return Plugin_Continue;
		}	

		if (!(GetEntityFlags(client) & FL_ONGROUND) || RoundToNearest(GetVectorLength(vel)) < 80)
			return Plugin_Continue;

		static float fwd[3];
		static float velocity[3];
		static float up[3];
		GetAngleVectors(angles, fwd, velocity, up);
		NormalizeVector(fwd, velocity);
		ScaleVector(velocity, 950.0);

		float fOriginClient[3];
		GetClientAbsOrigin(client, fOriginClient);

		SetEntPropVector(client, Prop_Data, "m_vecBaseVelocity", velocity);

		g_LeapLastTime[client] = GetGameTime();
	}

	return Plugin_Continue;
}
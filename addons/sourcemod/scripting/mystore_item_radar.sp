/*
 * MyStore - Radar item module
 * by: shanapu
 * https://github.com/shanapu/
 * 
 * Copyright (C) 2018-2019 Thomas Schmidt (shanapu)
 * Credits: Totenfluch - https://github.com/Totenfluch/StammFeaturesForStore
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

#include <autoexecconfig> //https://raw.githubusercontent.com/Impact123/AutoExecConfig/development/autoexecconfig.inc

bool g_bEquiptDistance[MAXPLAYERS + 1] = false;
bool g_bEquiptDirection[MAXPLAYERS + 1] = false;
bool g_bEquiptName[MAXPLAYERS + 1] = false;
ConVar gc_bEnable;
ConVar gc_fTime;
ConVar gc_bFFA;

/*
 * Build date: <DATE>
 * Build number: <BUILD>
 * Commit: https://github.com/shanapu/MyStore/commit/<COMMIT>
 */

public Plugin myinfo = 
{
	name = "MyStore - Radar item module",
	author = "shanapu",
	description = "",
	version = "0.1.<BUILD>",
	url = "github.com/shanapu/MyStore"
};

public void OnPluginStart()
{
	gc_fTime = AutoExecConfig_CreateConVar("mystore_radar_time", "3.0", "Time between HUD refreshes");
	MyStore_RegisterHandler("distance", _, _, Distance_Config, Distance_Equip, Distance_Remove, true);
	MyStore_RegisterHandler("direction", _, _, Direction_Config, Direction_Equip, Direction_Remove, true);
	MyStore_RegisterHandler("nearest", _, _, Name_Config, Name_Equip, Name_Remove, true);
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;

	CreateTimer(gc_fTime.FloatValue, Timer_CheckPosition, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	if (FindConVar("sv_hudhint_sound") != INVALID_HANDLE)
	{
		FindConVar("sv_hudhint_sound").IntValue = 0;
	}

	gc_bFFA = FindConVar("mp_teammates_are_enemies");
}

public bool Distance_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, 0);

	return true;
}

public int Distance_Equip(int client, int itemid)
{
	g_bEquiptDistance[client] = true;

	return ITEM_EQUIP_SUCCESS;
}

public int Distance_Remove(int client, int itemid)
{
	g_bEquiptDistance[client] = false;

	return ITEM_EQUIP_REMOVE;
}

public bool Direction_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, 0);

	return true;
}

public int Direction_Equip(int client, int itemid)
{
	g_bEquiptDirection[client] = true;

	return ITEM_EQUIP_SUCCESS;
}

public int Direction_Remove(int client, int itemid)
{
	g_bEquiptDirection[client] = false;

	return ITEM_EQUIP_REMOVE;
}

public bool Name_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, 0);

	return true;
}

public int Name_Equip(int client, int itemid)
{
	g_bEquiptName[client] = true;

	return ITEM_EQUIP_SUCCESS;
}

public int Name_Remove(int client, int itemid)
{
	g_bEquiptName[client] = false;

	return ITEM_EQUIP_REMOVE;
}

public Action Timer_CheckPosition(Handle timer)
{
	if (!gc_bEnable.BoolValue)
		return Plugin_Continue;

	char unitString[12];
	char unitStringOne[12];

	float clientOrigin[3];
	float searchOrigin[3];
	float near;
	float distance;

	int nearest;

	Format(unitString, sizeof(unitString), "meters");
	Format(unitStringOne, sizeof(unitStringOne), "meter");

	for (int i = 1; i <= MaxClients; i++)
	{
		if ((g_bEquiptDirection[i] || g_bEquiptDirection[i] || g_bEquiptName[i]) && IsValidClient(i, true, false))
		{
			nearest = 0;
			near = 0.0;

			// Get origin
			GetClientAbsOrigin(i, clientOrigin);

			// Next client loop
			for (int search = 1; search <= MaxClients; search++)
			{
				if (!IsClientInGame(search) || !IsPlayerAlive(search) || search == i || (GetClientTeam(i) == GetClientTeam(search) && !gc_bFFA.BoolValue))
					continue;

				// Get distance to first client
				GetClientAbsOrigin(search, searchOrigin);

				distance = GetVectorDistance(clientOrigin, searchOrigin);

				// Is he more near to the player as the player before?
				if (near == 0.0)
				{
					near = distance;
					nearest = search;
				}

				if (distance < near)
				{
					near = distance;
					nearest = search;
				}

			}

			// Found a player?
			if (nearest != 0)
			{
				float fDist;
				float vecPoints[3];
				float vecAngles[3];
				float clientAngles[3];
				char directionString[64];
				char textToPrint[64];

				// Client get Direction?
				if (g_bEquiptDirection[i])
				{
					// Get the origin of the nearest player
					GetClientAbsOrigin(nearest, searchOrigin);

					// Angles
					GetClientAbsAngles(i, clientAngles);

					// Angles from origin
					MakeVectorFromPoints(clientOrigin, searchOrigin, vecPoints);
					GetVectorAngles(vecPoints, vecAngles);

					// Differenz
					float diff = clientAngles[1] - vecAngles[1];

					// Correct it
					if (diff < -180)
					{
						diff = 360 + diff;
					}

					if (diff > 180)
					{
						diff = 360 - diff;
					}

					// Now geht the direction
					if (diff >= -22.5 && diff < 22.5)
					{
						Format(directionString, sizeof(directionString), "\xe2\x86\x91");
					}
					else if (diff >= 22.5 && diff < 67.5)
					{
						Format(directionString, sizeof(directionString), "\xe2\x86\x97");
					}
					else if (diff >= 67.5 && diff < 112.5)
					{
						Format(directionString, sizeof(directionString), "\xe2\x86\x92");
					}
					else if (diff >= 112.5 && diff < 157.5)
					{
						Format(directionString, sizeof(directionString), "\xe2\x86\x98");
					}
					else if (diff >= 157.5 || diff < -157.5)
					{
						Format(directionString, sizeof(directionString), "\xe2\x86\x93");
					}
					else if (diff >= -157.5 && diff < -112.5)
					{
						Format(directionString, sizeof(directionString), "\xe2\x86\x99");
					}
					else if (diff >= -112.5 && diff < -67.5)
					{
						Format(directionString, sizeof(directionString), "\xe2\x86\x90");
					}
					else if (diff >= -67.5 && diff < -22.5)
					{
						Format(directionString, sizeof(directionString), "\xe2\x86\x96");
					}

					// Add to text
					if (g_bEquiptDistance[i])
					{
						Format(textToPrint, sizeof(textToPrint), "%s\n", directionString);
					}
					else
					{
						Format(textToPrint, sizeof(textToPrint), directionString);
					}
				}

				// Client get Distance?
				if (g_bEquiptDistance[i])
				{
					// Distance to meters
					fDist = near * 0.01905;

					// Add to text
					if (g_bEquiptName[i])
					{
						Format(textToPrint, sizeof(textToPrint), "%s(%i %s)\n", textToPrint, RoundFloat(fDist), (RoundFloat(fDist) == 1 ? unitStringOne : unitString));
					}
					else
					{
						Format(textToPrint, sizeof(textToPrint), "%s(%i %s)", textToPrint, RoundFloat(fDist), (RoundFloat(fDist) == 1 ? unitStringOne : unitString));
					}
				}

				// Add name
				if (g_bEquiptName[i])
				{
					Format(textToPrint, sizeof(textToPrint), "%s%N", textToPrint, nearest);
				}

				// Print text
				PrintHintText(i, textToPrint);
			}
		}
	}

	return Plugin_Continue;
}

bool IsValidClient(int client, bool bots = true, bool dead = true)
{
	if (client <= 0)
		return false;

	if (client > MaxClients)
		return false;

	if (!IsClientInGame(client))
		return false;

	if (IsFakeClient(client) && !bots)
		return false;

	if (IsClientSourceTV(client))
		return false;

	if (IsClientReplay(client))
		return false;

	if (!IsPlayerAlive(client) && !dead)
		return false;

	return true;
}
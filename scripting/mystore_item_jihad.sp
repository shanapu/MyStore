#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

#include <mystore>

#include <colors>
#include <smartdm>

#pragma semicolon 1
#pragma newdecls required

float g_fRadius[STORE_MAX_ITEMS];
float g_fDelay[STORE_MAX_ITEMS];
float g_fFailrate[STORE_MAX_ITEMS];
char g_sPreSound[STORE_MAX_ITEMS][PLATFORM_MAX_PATH];
char g_sPostSound[STORE_MAX_ITEMS][PLATFORM_MAX_PATH];
int g_iTeam[STORE_MAX_ITEMS];

int g_iCount = 0;

char g_sChatPrefix[128];

public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");

	MyStore_RegisterHandler("jihad", Jihad_OnMapStart, Jihad_Reset, Jihad_Config, Jihad_Equip, INVALID_FUNCTION, false);
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

public void Jihad_OnMapStart()
{
	char sBuffer[256];

	for (int i = 0; i < g_iCount; i++)
	{
		FormatEx(sBuffer, sizeof(sBuffer), "sound/%s", g_sPreSound[i]);
		if (FileExists(sBuffer, true) && g_sPreSound[i][0])
		{
			PrecacheSound(g_sPreSound[i], true);
			AddFileToDownloadsTable(sBuffer);
		}

		FormatEx(sBuffer, sizeof(sBuffer), "sound/%s", g_sPostSound[i]);
		if (FileExists(sBuffer, true) && g_sPostSound[i][0])
		{
			PrecacheSound(g_sPostSound[i], true);
			AddFileToDownloadsTable(sBuffer);
		}
	}

	PrecacheModel("materials/sprites/xfireball3.vmt");
}

public void Jihad_Reset()
{
	g_iCount = 0;
}

public bool Jihad_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, g_iCount);

	g_fRadius[g_iCount] = kv.GetFloat("radius", 300.0);
	g_fDelay[g_iCount] = kv.GetFloat("delay", 0.0);
	g_fFailrate[g_iCount] = kv.GetFloat("failrate", 0.0);
	g_iTeam[g_iCount] = kv.GetNum("team", 0);
	kv.GetString("presound", g_sPreSound[g_iCount], PLATFORM_MAX_PATH);
	kv.GetString("postsound", g_sPostSound[g_iCount], PLATFORM_MAX_PATH);

	g_iCount++;

	return true;
}

public int Jihad_Equip(int client, int itemid)
{
	int iIndex = MyStore_GetDataIndex(itemid);

	if (g_iTeam[g_iCount] != 0 && g_iTeam[g_iCount] != GetClientTeam(client) - 1)
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Wrong Team");
		return ITEM_EQUIP_FAIL;
	}

	if (!IsPlayerAlive(client))
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Must be Alive");
		return ITEM_EQUIP_FAIL;
	}

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(iIndex);

	CreateTimer(g_fDelay[iIndex], Jihad_TriggerBomb, pack);

	if (!g_sPreSound[iIndex][0])
		return ITEM_EQUIP_SUCCESS;

	float fVec[3];
	GetClientAbsOrigin(client, fVec);
	EmitAmbientSound(g_sPreSound[iIndex], fVec, client);

	return ITEM_EQUIP_SUCCESS;
}

// Detonate Bomb / Kill Player
public Action Jihad_TriggerBomb(Handle timer, DataPack pack)
{
	pack.Reset();
	int client = GetClientOfUserId(pack.ReadCell());
	int iIndex = pack.ReadCell();
	delete pack;

	if (GetRandomFloat(0.0, 1.1) <= g_fFailrate[iIndex])
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Jihad Failed");
		CPrintToChatAll("%s%t", g_sChatPrefix, "Jihad Failed All", client);
		return Plugin_Stop;
	}

	float fVec[3];
	GetClientAbsOrigin(client, fVec);

	for (int i = 1; i <= MaxClients; i++)
	{
		// Check that client is a real player who is alive and is a CT
		if (!IsClientInGame(i) || !IsPlayerAlive(i))
			continue;

		float ct_vec[3];
		GetClientAbsOrigin(i, ct_vec);

		float distance = GetVectorDistance(ct_vec, fVec, false);

		// If Player was in explosion radius, damage or kill them
		// Formula used: damage = 200 - (d/2)
		int damage = RoundToFloor(GetClientTeam(i) == CS_TEAM_T ? g_fRadius[iIndex] - (distance / 2.0) : g_fRadius[iIndex] - (distance / 2.0));

		if (damage <= 0) // this player was not damaged 
			continue;

		// damage the surrounding players
		int curHP = GetClientHealth(i);

		if (curHP - damage <= 0) 
		{
			SDKHooks_TakeDamage(i, client, client, view_as<float>(damage), DMG_BLAST, -1, fVec);
		}
		else
		{ // Survivor
			SDKHooks_TakeDamage(i, client, client, view_as<float>(damage), DMG_BLAST, -1, fVec);
			IgniteEntity(i, 2.0);
		}
	}

	int explosion = CreateEntityByName("env_explosion");
	if (explosion == -1)
		return Plugin_Stop;

	SetEntProp(explosion, Prop_Data, "m_spawnflags", 65); // No damage, no sound

	DispatchSpawn(explosion);

	DispatchKeyValueVector(explosion, "origin", fVec);

	DispatchKeyValue(explosion, "fireballsprite", "materials/sprites/xfireball3.vmt");

	AcceptEntityInput(explosion, "Explode");

	RemoveEdict(explosion);

	SDKHooks_TakeDamage(client, client, client, 5000.0, DMG_BLAST, -1, fVec);


	if (!g_sPostSound[iIndex][0])
		return Plugin_Stop;

	EmitAmbientSound(g_sPostSound[iIndex], fVec, client);

	return Plugin_Stop;
}

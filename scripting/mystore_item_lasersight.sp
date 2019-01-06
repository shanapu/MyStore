#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <clientprefs>

#include <mystore>

int g_iColors[STORE_MAX_ITEMS][4];
int g_iEquipt[MAXPLAYERS + 1] = {-1, ...};

bool g_bEquipt[MAXPLAYERS + 1] = false;

ConVar gc_bEnable;

int g_iCount = 0;
int g_iLaserBeam = -1;
int g_iLaserDot = -1;

char g_sChatPrefix[128];

StringMap g_hSnipers;

public void OnPluginStart()
{
	MyStore_RegisterHandler("lasersight", LaserSight_OnMapStart, LaserSight_Reset, LaserSight_Config, LaserSight_Equip, LaserSight_Remove, true);

	g_hSnipers = new StringMap();

	g_hSnipers.SetValue("awp", 1);
	g_hSnipers.SetValue("ssg08", 1);

	g_hSnipers.SetValue("sg556", 1);
	g_hSnipers.SetValue("aug", 1);

	g_hSnipers.SetValue("g3sg1", 1);
	g_hSnipers.SetValue("scar20", 1);
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

public void LaserSight_OnMapStart()
{
	g_iLaserBeam = PrecacheModel("materials/sprites/laserbeam.vmt", true); 
	g_iLaserDot = PrecacheModel("materials/sprites/redglow1.vmt", true); 
}

public void LaserSight_Reset()
{
	g_iCount = 0;
}

public bool LaserSight_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, g_iCount);

	kv.GetColor("color", g_iColors[g_iCount][0], g_iColors[g_iCount][1], g_iColors[g_iCount][2], g_iColors[g_iCount][3]);
	if (g_iColors[g_iCount][3] == 0)
	{
		g_iColors[g_iCount][3] = 255;
	}

	g_iCount++;

	return true;
}

public int LaserSight_Equip(int client, int itemid)
{
	g_bEquipt[client] = true;
	g_iEquipt[client] = MyStore_GetDataIndex(itemid);

	return ITEM_EQUIP_SUCCESS;
}

public int LaserSight_Remove(int client, int itemid)
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

	char sWeapon[64];
	GetClientWeapon(client, sWeapon, sizeof(sWeapon));

	int iBuffer;
	if (!g_hSnipers.GetValue(sWeapon[7], iBuffer))
		return Plugin_Continue;

	int iFOV = GetEntProp(client, Prop_Data, "m_iFOV");
	if (iFOV == 0 || iFOV == 90)
		return Plugin_Continue;

	float fOrigin[3];
	GetClientEyePosition(client, fOrigin);

	float fImpact[3];
	GetClientSightEnd(client, fImpact);

	TE_SetupBeamPoints(fOrigin, fImpact, g_iLaserBeam, 0, 0, 0, 0.1, 0.12, 0.0, 1, 0.0, g_iColors[g_iEquipt[client]], 0);
	TE_SendToClient(client, 0.0);

	TE_SetupGlowSprite(fImpact, g_iLaserDot, 0.1, 0.25, g_iColors[g_iEquipt[client]][3]);
	TE_SendToClient(client, 0.0);

	return Plugin_Continue;
}

Handle GetClientSightEnd(int client, float out[3])
{
	float fEyes[3];
	float fOrigin[3];
	GetClientEyePosition(client, fEyes);
	GetClientEyeAngles(client, fOrigin);
	TR_TraceRayFilter(fEyes, fOrigin, MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitPlayers);
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
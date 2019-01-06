#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <clientprefs>

#include <mystore>

#include <colors>

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

public void OnPluginStart()
{
	MyStore_RegisterHandler("laserpointer", LaserPointer_OnMapStart, LaserPointer_Reset, LaserPointer_Config, LaserPointer_Equip, LaserPointer_Remove, true);

	g_hHideCookie = RegClientCookie("LaserPointer_Hide_Cookie", "Cookie to check if LaserPointer are blocked", CookieAccess_Private);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!AreClientCookiesCached(i))
			continue;

		OnClientCookiesCached(i);
	}

	RegConsoleCmd("sm_hidelaserpointer", Command_Hide, "Hide the LaserPointer");
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
		CPrintToChat(client, "%s LaserPointer disabled", g_sChatPrefix); //todo translate
		SetClientCookie(client, g_hHideCookie, "1");
	}
	else
	{
		CPrintToChat(client, "%s LaserPointer enabled", g_sChatPrefix);
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
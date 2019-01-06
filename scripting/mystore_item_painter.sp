#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <clientprefs>

#include <mystore>

#include <colors>

#define MAX_BUTTONS 25

int g_iColors[STORE_MAX_ITEMS][4];

bool g_bRandom[STORE_MAX_ITEMS];
bool g_bEquipt[MAXPLAYERS + 1] = false;

ConVar gc_bEnable;

int g_iCount = 0;
int g_iBeamSprite = -1;
int g_iLastButtons[MAXPLAYERS+1];

bool g_bPainterUse[MAXPLAYERS+1] = {false, ...};

float g_fLastPainter[MAXPLAYERS+1][3];

bool g_bHide[MAXPLAYERS + 1];
Handle g_hHideCookie = INVALID_HANDLE;

char g_sChatPrefix[128];

public void OnPluginStart()
{
	MyStore_RegisterHandler("painter", Painter_OnMapStart, Painter_Reset, Painter_Config, Painter_Equip, Painter_Remove, true);

	g_hHideCookie = RegClientCookie("Painter_Hide_Cookie", "Cookie to check if Tracer are blocked", CookieAccess_Private);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!AreClientCookiesCached(i))
			continue;

		OnClientCookiesCached(i);
	}

	RegConsoleCmd("sm_hidepainter", Command_Hide, "Hide the Painter");
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
		CPrintToChat(client, "%s Painter disabled", g_sChatPrefix); //todo translate
		SetClientCookie(client, g_hHideCookie, "1");
	}
	else
	{
		CPrintToChat(client, "%s Painter enabled", g_sChatPrefix);
		SetClientCookie(client, g_hHideCookie, "0");
	}

	return Plugin_Handled;
}
public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

public void Painter_OnMapStart()
{
	CreateTimer(0.1, Print_Painter, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	g_iBeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt", true);
}

public void Painter_Reset()
{
	g_iCount = 0;
}

public bool Painter_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, g_iCount);

	kv.GetColor("color", g_iColors[g_iCount][0], g_iColors[g_iCount][1], g_iColors[g_iCount][2], g_iColors[g_iCount][3]);
	if (g_iColors[g_iCount][3] == 0)
	{
		g_iColors[g_iCount][3] = 255;
	}

	g_bRandom[g_iCount] = kv.GetNum("random", 0) ? true : false;

	g_iCount++;

	return true;
}

public int Painter_Equip(int client, int itemid)
{
	g_bEquipt[client] = true;

	return ITEM_EQUIP_SUCCESS;
}

public int  Painter_Remove(int client, int itemid)
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


	if ((buttons & IN_USE))
	{
		if (!(g_iLastButtons[client] & IN_USE))
		{
			TraceEye(client, g_fLastPainter[client]);
			g_bPainterUse[client] = true;
		}
	}
	else if ((g_iLastButtons[client] & IN_USE))
	{
		g_fLastPainter[client][0] = 0.0;
		g_fLastPainter[client][1] = 0.0;
		g_fLastPainter[client][2] = 0.0;
		g_bPainterUse[client] = false;
	}

	g_iLastButtons[client] = buttons;

	return Plugin_Continue;
}

public Action TraceEye(int client, float g_fPos[3])
{
	float vAngles[3], vOrigin[3];
	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);
	TR_TraceRayFilter(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);

	if (TR_DidHit(INVALID_HANDLE)) TR_GetEndPosition(g_fPos, INVALID_HANDLE);
	return;
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
	return (entity > GetMaxClients() || !entity);
}

public Action Print_Painter(Handle timer)
{
	float g_fPos[3];

	for (int i = 1; i <= MaxClients;i++)
	{
		if (!IsClientInGame(i) || !g_bEquipt[i] || !g_bPainterUse[i])
			continue;

		int iIndex = MyStore_GetDataIndex(MyStore_GetEquippedItem(i, "painter", 0));

		if (g_bRandom[iIndex])
		{
			iIndex = GetRandomInt(0, g_iCount);
		}

		TraceEye(i, g_fPos);
		if (GetVectorDistance(g_fPos, g_fLastPainter[i]) > 6.0)
		{
			Connect_Painter(g_fLastPainter[i], g_fPos, g_iColors[iIndex]);
			g_fLastPainter[i][0] = g_fPos[0];
			g_fLastPainter[i][1] = g_fPos[1];
			g_fLastPainter[i][2] = g_fPos[2];
		}
	}
}

void Connect_Painter(float start[3], float end[3], int color[4])
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
		return;

	TE_SetupBeamPoints(start, end, g_iBeamSprite, 0, 0, 0, 25.0, 2.0, 2.0, 10, 0.0, color, 0);

	TE_Send(clients, numClients, 0.0);
}

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <clientprefs>

#include <mystore>

#include <colors>
#include <autoexecconfig>

bool g_bRandom[STORE_MAX_ITEMS];
bool g_bEquipt[MAXPLAYERS + 1] = false;

char g_sMaterials[STORE_MAX_ITEMS][32];

ConVar gc_iTracerLife;
ConVar gc_iTracerWidth;

ConVar gc_bEnable;

int g_aColors[STORE_MAX_ITEMS][4];
int g_iMaterial[STORE_MAX_ITEMS] = {-1, ...};
int g_iCount = 0;

bool g_bHide[MAXPLAYERS + 1];
Handle g_hHideCookie = INVALID_HANDLE;

char g_sChatPrefix[128];

public void OnPluginStart()
{
	AutoExecConfig_SetFile("items", "MyStore");
	AutoExecConfig_SetCreateFile(true);

	gc_iTracerLife = AutoExecConfig_CreateConVar("mystore_tracer_life", "0.5", "Life of a tracer in seconds", _, true, 0.1);
	gc_iTracerWidth = AutoExecConfig_CreateConVar("mystore_tracer_width", "1.0", "Life of a tracer in seconds", _, true, 0.1);

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	MyStore_RegisterHandler("tracer", Tracers_OnMapStart, Tracers_Reset, Tracers_Config, Tracers_Equip, Tracers_Remove, true);

	HookEvent("bullet_impact", Event_BulletImpact);

	g_hHideCookie = RegClientCookie("Tracer_Hide_Cookie", "Cookie to check if Tracer are blocked", CookieAccess_Private);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!AreClientCookiesCached(i))
			continue;

		OnClientCookiesCached(i);
	}

	RegConsoleCmd("sm_hidegrenadetracer", Command_Hide, "Hide the Tracer");
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
		CPrintToChat(client, "%s Tracer disabled", g_sChatPrefix); //todo translate
		SetClientCookie(client, g_hHideCookie, "1");
	}
	else
	{
		CPrintToChat(client, "%s Tracer enabled", g_sChatPrefix);
		SetClientCookie(client, g_hHideCookie, "0");
	}

	return Plugin_Handled;
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

public void Tracers_OnMapStart()
{
	for (int i = 0; i < g_iCount; i++)
	{
		if (!FileExists(g_sMaterials[i], true) || !g_sMaterials[i][0])
			continue;

		g_iMaterial[i] = PrecacheModel(g_sMaterials[i], true);
		AddFileToDownloadsTable(g_sMaterials[i]);
	}
}

public void Tracers_Reset()
{
	g_iCount = 0;
}

public bool Tracers_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, g_iCount);

	kv.GetString("material", g_sMaterials[g_iCount], PLATFORM_MAX_PATH);
	kv.GetColor("color", g_aColors[g_iCount][0], g_aColors[g_iCount][1], g_aColors[g_iCount][2], g_aColors[g_iCount][3]);
	if (g_aColors[g_iCount][3] == 0)
	{
		g_aColors[g_iCount][3] = 255;
	}

	g_bRandom[g_iCount] = kv.GetNum("random", 0) ? true : false;

	g_iCount++;

	return true;
}

public int Tracers_Equip(int client, int itemid)
{
	g_bEquipt[client] = true;

	return ITEM_EQUIP_SUCCESS;
}

public int Tracers_Remove(int client, int itemid)
{
	g_bEquipt[client] = false;

	return ITEM_EQUIP_REMOVE;
}

public void OnClientDisconnect(int client)
{
	g_bEquipt[client] = false;
}

public void Event_BulletImpact(Event event, char[] name, bool dontBroadcast)
{
	if (!gc_bEnable.BoolValue)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!client)
		return;

	if (!g_bEquipt[client])
		return;

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

	int iIndex = MyStore_GetDataIndex(MyStore_GetEquippedItem(client, "tracer", 0));

	if (g_bRandom[iIndex])
	{
		iIndex = GetRandomInt(0, g_iCount);
	}

	float fOrigin[3], fImpact[3];

	GetClientEyePosition(client, fOrigin);
	fImpact[0] = GetEventFloat(event, "x");
	fImpact[1] = GetEventFloat(event, "y");
	fImpact[2] = GetEventFloat(event, "z");

	TE_SetupBeamPoints(fOrigin, fImpact, g_iMaterial[iIndex], 0, 0, 0, gc_iTracerLife.FloatValue, gc_iTracerWidth.FloatValue, gc_iTracerWidth.FloatValue, 1, 0.0, g_aColors[iIndex], 0);

	TE_Send(clients, numClients, 0.0);
}
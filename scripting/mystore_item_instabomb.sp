#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#include <mystore>

#include <autoexecconfig>

bool g_bEquipt[MAXPLAYERS + 1] = false;

ConVar gc_bEnable;
ConVar gc_iType;

public void OnPluginStart()
{
	MyStore_RegisterHandler("instabomb", _, _, InstaBomb_Config, InstaBomb_Equip, InstaBomb_Remove, true);

	AutoExecConfig_SetFile("items", "MyStore");
	AutoExecConfig_SetCreateFile(true);

	gc_iType = AutoExecConfig_CreateConVar("mystore_instabomb_type", "2", "1 - instadefuse only / 2 - instadefuse & instaplant / 3 - instaplant only", _, true, 1.0, true, 3.0);

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	HookEvent("bomb_begindefuse", Event_Defuse);
	HookEvent("bomb_beginplant", Event_Plant);
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
}

public bool InstaBomb_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, 0);

	return true;
}

public int InstaBomb_Equip(int client, int itemid)
{
	g_bEquipt[client] = true;

	return ITEM_EQUIP_SUCCESS;
}

public int  InstaBomb_Remove(int client, int itemid)
{
	g_bEquipt[client] = false;

	return ITEM_EQUIP_REMOVE;
}

public void OnClientDisconnect(int client)
{
	g_bEquipt[client] = false;
}

public void Event_Defuse(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!g_bEquipt[client])
		return;

	if (!gc_bEnable.BoolValue || gc_iType.IntValue == 3)
		return;

	CreateTimer(0.1, Timer_Defuse);
}

public Action Timer_Defuse(Handle timer)
{
	int bomb = FindEntityByClassname(-1, "planted_c4");
	if (!bomb)
		return Plugin_Handled;

	SetEntPropFloat(bomb, Prop_Send, "m_flDefuseCountDown", GetGameTime());

	return Plugin_Handled;
}

public void Event_Plant(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!g_bEquipt[client])
		return;

	if (!gc_bEnable.BoolValue || gc_iType.IntValue == 1)
		return;

	CreateTimer(0.1, Timer_Plant, GetClientUserId(client));
}

public Action Timer_Plant(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!client)
		return Plugin_Handled;

	int bomb = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	char sBuffer[16];
	GetEntityClassname(bomb, sBuffer, sizeof(sBuffer));

	if (!StrEqual(sBuffer, "weapon_c4"))
		return Plugin_Handled;

	SetEntPropFloat(bomb, Prop_Send, "m_fArmedTime", GetGameTime());

	return Plugin_Handled;
}
// https://forums.alliedmods.net/showthread.php?p=2042310

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#include <mystore>

#include <autoexecconfig>

ConVar gc_bEnable;
ConVar bSnd;

bool g_bEquipt[MAXPLAYERS + 1] = false;


public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");

	AddCommandListener(Command_LAW, "+lookatweapon");
	RegConsoleCmd("sm_flashlight", Command_FlashLight);

	AutoExecConfig_SetFile("items", "MyStore");
	AutoExecConfig_SetCreateFile(true);

	bSnd = AutoExecConfig_CreateConVar("mystore_flashlight_sound", "1", "Enable sound when a player uses the flash light.", _, true, 0.0, true, 1.0);

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	MyStore_RegisterHandler("flashlight", Flashlight_OnMapStart, _, Flashlight_Config, Flashlight_Equip, _, true);
}

public void Flashlight_OnMapStart()
{
	PrecacheSound("items/flashlight1.wav", true);
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
}

public bool Flashlight_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, 0);

	return true;
}

public int Flashlight_Equip(int client, int itemid)
{
	g_bEquipt[client] = true;

	return ITEM_EQUIP_SUCCESS;
}

public int Flashlight_Remove(int client, int itemid)
{
	g_bEquipt[client] = false;

	return ITEM_EQUIP_REMOVE;
}

public void OnClientDisconnect(int client)
{
	g_bEquipt[client] = false;
}

public Action Command_FlashLight(int client, int args)
{
	if (!gc_bEnable.BoolValue)
		return Plugin_Handled;

	if (!IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Handled;

	ToggleFlashlight(client);

	return Plugin_Handled;
}

public Action Command_LAW(int client, const char[] command, int args)
{
	if (!gc_bEnable.BoolValue)
		return Plugin_Continue;

	if (!IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Continue;

	ToggleFlashlight(client);

	return Plugin_Continue;
}

void ToggleFlashlight(int client)
{
	SetEntProp(client, Prop_Send, "m_fEffects", GetEntProp(client, Prop_Send, "m_fEffects") ^ 4);

	if (!bSnd.BoolValue)
		return;

	EmitSoundToClient(client, "items/flashlight1.wav");
}
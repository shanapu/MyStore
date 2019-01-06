#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#include <mystore>

#include <autoexecconfig>

ConVar gc_bEnable;

ConVar gc_bAlive;
ConVar gc_iRed;
ConVar gc_iBlue;
ConVar gc_iGreen;
ConVar gc_iAlpha;
ConVar gc_fX;
ConVar gc_fY;

Handle g_hHUD;

char g_sCreditsName[64];

public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");

	AutoExecConfig_SetFile("hud", "MyStore");
	AutoExecConfig_SetCreateFile(true);

	gc_bAlive = AutoExecConfig_CreateConVar("mystore_hud_alive", "1", "0 - show hud only to alive player, 1 - show hud to dead & alive player", _, true, 0.0, true, 1.0);
	gc_fX = AutoExecConfig_CreateConVar("mystore_hud_x", "0.05", "x coordinate, from 0 to 1. -1.0 is the center", _, true, -1.0, true, 1.0);
	gc_fY = AutoExecConfig_CreateConVar("mystore_hud_y", "0.65", "y coordinate, from 0 to 1. -1.0 is the center", _, true, -1.0, true, 1.0);
	gc_iRed = AutoExecConfig_CreateConVar("mystore_hud_red", "200", "Color of sm_hud_type '1' (set R, G and B values to 255 to disable) (Rgb): x - red value", _, true, 0.0, true, 255.0);
	gc_iGreen = AutoExecConfig_CreateConVar("mystore_hud_green", "200", "Color of sm_hud_type '1' (set R, G and B values to 255 to disable) (rGb): x - green value", _, true, 0.0, true, 255.0);
	gc_iBlue = AutoExecConfig_CreateConVar("mystore_hud_blue", "0", "Color of sm_hud_type '1' (set R, G and B values to 255 to disable) (rgB): x - blue value", _, true, 0.0, true, 255.0);
	gc_iAlpha = AutoExecConfig_CreateConVar("mystore_hud_alpha", "200", "Alpha value of sm_hud_type '1' (set value to 255 to disable for transparency)", _, true, 0.0, true, 255.0);

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	g_hHUD = CreateHudSynchronizer();
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
	strcopy(g_sCreditsName, sizeof(g_sCreditsName), credits);
}

public void OnConfigsExecuted()
{
	CreateTimer(1.0, Timer_ShowHUD, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_ShowHUD(Handle timer, Handle pack)
{
	if (!gc_bEnable.BoolValue)
		return Plugin_Handled;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i, false, gc_bAlive.BoolValue))
			continue;

		ClearSyncHud(i, g_hHUD);
		SetHudTextParams(gc_fX.FloatValue, gc_fY.FloatValue, 5.0, gc_iRed.IntValue, gc_iGreen.IntValue, gc_iBlue.IntValue, gc_iAlpha.IntValue, 1, 1.0, 0.0, 0.0);

		ShowSyncHudText(i, g_hHUD, "%t", "Title Credits", g_sCreditsName, MyStore_GetClientCredits(i));
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
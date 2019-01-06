#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#include <mystore>

#include <colors>

#include <autoexecconfig>

ConVar gc_bEnable;

ConVar gc_fTime;
ConVar gc_iPause;
ConVar gc_iMin;
ConVar gc_iMax;
ConVar gc_iFee;

char g_sCreditsName[64];
char g_sChatPrefix[128];

char g_sMenuItem[64];
char g_sMenuExit[64];

ArrayList g_hJackPot;
Handle g_hTimer;
bool g_bActive = false;
bool g_bUsed[MAXPLAYERS + 1] = {false, ...};
int g_iBet[MAXPLAYERS + 1] = {0, ...};
int g_iPause = 0;
int g_iPlayer = 0;

public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");
	LoadTranslations("common.phrases");

	RegConsoleCmd("sm_jackpot", Command_JackPot, "Open the jackpot menu and/or set a bet");

	AutoExecConfig_SetFile("gamble", "MyStore");
	AutoExecConfig_SetCreateFile(true);

	gc_fTime = AutoExecConfig_CreateConVar("mystore_jackpot_time", "60", "how many seconds should the game run until we find a winner?", _, true, 10.0);
	gc_iPause = AutoExecConfig_CreateConVar("mystore_jackpot_cooldown", "120", "how many seconds should we wait until new game is availble?", _, true, 10.0);
	gc_iMin = AutoExecConfig_CreateConVar("mystore_jackpot_min", "20", "Minium amount of credits to spend", _, true, 1.0);
	gc_iMax = AutoExecConfig_CreateConVar("mystore_jackpot_max", "2000", "Maximum amount of credits to spend", _, true, 2.0);
	gc_iFee = AutoExecConfig_CreateConVar("mystore_jackpot_fee", "5", "The fee in percent that the casino retains from the winpot", _, true, 0.0);

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	g_hJackPot = new ArrayList();

	MyStore_RegisterHandler("jackpot", JackPot_OnMapStart, _, _, JackPot_Menu, _, false, true);
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
	strcopy(g_sCreditsName, sizeof(g_sCreditsName), credits);
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);

	ReadCoreCFG();
}

public void JackPot_OnMapStart()
{
	g_hJackPot.Clear();
}

public void JackPot_Menu(int client, int itemid)
{
	Panel_JackPot(client);
}

void Panel_JackPot(int client)
{
	char sBuffer[255];
	int iCredits = MyStore_GetClientCredits(client); // Get credits
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "jackpot", "Title Credits", g_sCreditsName, iCredits);
	panel.SetTitle(sBuffer);
	panel.DrawText(" ");
	if (g_iPause > GetTime())
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Jackpot paused");
		panel.DrawText(sBuffer);
		panel.DrawText(" ");
		Format(sBuffer, sizeof(sBuffer), "%t", "You can start a new Jackpot");
		panel.DrawText(sBuffer);

		SecToTime(g_iPause - GetTime(), sBuffer, sizeof(sBuffer));
		Format(sBuffer, sizeof(sBuffer), "%t", "in x time", sBuffer);
		panel.DrawText(sBuffer);
		panel.DrawText(" ");
		panel.CurrentKey = 3;
		Format(sBuffer, sizeof(sBuffer), "%t", "Bet Minium", gc_iMin.IntValue);
		panel.DrawItem(sBuffer, ITEMDRAW_DISABLED);
		panel.CurrentKey = 4;
		Format(sBuffer, sizeof(sBuffer), "%t", "Bet Maximum", iCredits > gc_iMax.IntValue ? gc_iMax.IntValue : iCredits);
		panel.DrawItem(sBuffer, ITEMDRAW_DISABLED);
		panel.CurrentKey = 5;
		Format(sBuffer, sizeof(sBuffer), "%t", "Bet Random", gc_iMin.IntValue, iCredits > gc_iMax.IntValue ? gc_iMax.IntValue : iCredits);
		panel.DrawItem(sBuffer, ITEMDRAW_DISABLED);
	}
	else if (!g_bActive)
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "No active Jackpot");
		panel.DrawText(sBuffer);
		panel.DrawText(" ");
		Format(sBuffer, sizeof(sBuffer), "%t\n%t", "Type in chat !jackpot", "or use buttons below");
		panel.DrawText(sBuffer);
		panel.DrawText(" ");
		panel.CurrentKey = 3;
		Format(sBuffer, sizeof(sBuffer), "%t", "Bet Minium", gc_iMin.IntValue);
		panel.DrawItem(sBuffer, iCredits < gc_iMin.IntValue ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
		panel.CurrentKey = 4;
		Format(sBuffer, sizeof(sBuffer), "%t", "Bet Maximum", iCredits > gc_iMax.IntValue ? gc_iMax.IntValue : iCredits);
		panel.DrawItem(sBuffer, iCredits < gc_iMin.IntValue ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
		panel.CurrentKey = 5;
		Format(sBuffer, sizeof(sBuffer), "%t", "Bet Random", gc_iMin.IntValue, iCredits > gc_iMax.IntValue ? gc_iMax.IntValue : iCredits);
		panel.DrawItem(sBuffer, iCredits < gc_iMin.IntValue ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Jackpot: x Credits", g_hJackPot.Length, g_sCreditsName);
		panel.DrawText(sBuffer);

		if (g_bUsed[client])
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "Your Bet - Chance", g_iBet[client], g_sCreditsName, GetChance(client));
			panel.DrawText(sBuffer);
		}
		panel.DrawText(" ");

		for (int i = 0; i <= MaxClients; i++)
		{
			if (!IsValidClient(i, false, true) || !g_bUsed[i])
				continue;

			if (client == i)
				continue;

			Format(sBuffer, sizeof(sBuffer), "%t", "Jackpot chances", i, GetChance(client), g_iBet[client], g_sCreditsName);
			panel.DrawText(sBuffer);
		}
		panel.DrawText(" ");

		if (!g_bUsed[client])
		{
			Format(sBuffer, sizeof(sBuffer), "%t\n%t", "Type in chat !jackpot", "or use buttons below");
			panel.DrawText(sBuffer);
			panel.CurrentKey = 3;
			Format(sBuffer, sizeof(sBuffer), "%t", "Bet Minium", gc_iMin.IntValue);
			panel.DrawItem(sBuffer, iCredits < gc_iMin.IntValue ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
			panel.CurrentKey = 4;
			Format(sBuffer, sizeof(sBuffer), "%t", "Bet Maximum", iCredits > gc_iMax.IntValue ? gc_iMax.IntValue : iCredits);
			panel.DrawItem(sBuffer, iCredits < gc_iMin.IntValue ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
			panel.CurrentKey = 5;
			Format(sBuffer, sizeof(sBuffer), "%t", "Bet Random", gc_iMin.IntValue, iCredits > gc_iMax.IntValue ? gc_iMax.IntValue : iCredits);
			panel.DrawItem(sBuffer, iCredits < gc_iMin.IntValue ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
		}
	}
	panel.DrawText(" ");
	panel.CurrentKey = 7;
	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	panel.DrawItem("", ITEMDRAW_SPACER);
	panel.CurrentKey = 9;
	Format(sBuffer, sizeof(sBuffer), "%t", "Exit");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);

	panel.Send(client, PanelHandler_Info, MENU_TIME_FOREVER);
}

void SetBet(int client, int bet)
{
	g_bUsed[client] = true;
	g_iBet[client] = bet;
	g_iPlayer++;

	FakeClientCommand(client, "play sound/%s", g_sMenuItem);
	MyStore_SetClientCredits(client, MyStore_GetClientCredits(client) - bet, "JackPot Bet");

	int iAccountID = GetSteamAccountID(client, true);
	for (int i = 0; i < bet; i++)
	{
		g_hJackPot.Push(iAccountID);
	}

	if (!g_bActive)
	{
		g_bActive = true;
		delete g_hTimer;
		g_hTimer = CreateTimer(gc_fTime.FloatValue, Timer_EndJackPot, TIMER_FLAG_NO_MAPCHANGE);
		CPrintToChatAll("%s%t", g_sChatPrefix, "Player opened jackpot", client, bet, g_sCreditsName);
		char sBuffer[64];
		SecToTime(RoundFloat(gc_fTime.FloatValue), sBuffer, sizeof(sBuffer));
		CPrintToChatAll("%s%s %s", g_sChatPrefix, "the prize will be drawn in", sBuffer);
	}
	else
	{
		CPrintToChatAll("%s%t", g_sChatPrefix, "Player added to jackpot", client, bet, GetChance(client), g_hJackPot.Length, g_sCreditsName);
		for (int i = 0; i <= MaxClients; i++)
		{
			if (!IsValidClient(i, false, true) || !g_bUsed[i])
				continue;

			CPrintToChat(i, "%s%t", g_sChatPrefix, "Your current winning chance has changed", GetChance(i));
		}
	}

	Panel_JackPot(client);
}

float GetChance(int client)
{
	return float(g_iBet[client]) / float(g_hJackPot.Length) * 100.0;
}

public int PanelHandler_Info(Handle menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		int credits = MyStore_GetClientCredits(client);
		switch(param2)
		{
			case 3: SetBet(client, gc_iMin.IntValue);
			case 4: SetBet(client, credits > gc_iMax.IntValue ? gc_iMax.IntValue : credits);
			case 5: SetBet(client, GetRandomInt(gc_iMin.IntValue, credits > gc_iMax.IntValue ? gc_iMax.IntValue : credits));
			case 7:
			{
				FakeClientCommand(client, "play sound/%s", g_sMenuExit);
				MyStore_SetClientPreviousMenu(client, MENU_PARENT);
				MyStore_DisplayPreviousMenu(client);
			}
			case 9: FakeClientCommand(client, "play sound/%s", g_sMenuExit);
		}
	}

	delete menu;
}

public Action Command_JackPot(int client, int args)
{
	if (!client)
	{
		CReplyToCommand(client, "%s%t", g_sChatPrefix, "Command is in-game only");

		return Plugin_Handled;
	}

	if (!gc_bEnable.BoolValue)
	{
		CReplyToCommand(client, "%s%t", g_sChatPrefix, "Store Disabled");

		return Plugin_Handled;
	}

	if (!MyStore_HasClientAccess(client))
	{
		CReplyToCommand(client, "%s%t", g_sChatPrefix, "You dont have permission");

		return Plugin_Handled;
	}

	if (g_iPause > GetTime())
	{
		char sBuffer[64];
		SecToTime(g_iPause - GetTime(), sBuffer, sizeof(sBuffer));
		CReplyToCommand(client, "%s%t %t", g_sChatPrefix, "Jackpot paused", "You can start a new Jackpot in", sBuffer);

		return Plugin_Handled;
	}

	Panel_JackPot(client);

	if (g_bUsed[client])
	{
		CReplyToCommand(client, "%s%t", g_sChatPrefix, "You already cashed in", g_iBet[client], g_sCreditsName, GetChance(client), g_hJackPot.Length);

		return Plugin_Handled;
	}

	if (args != 1)
	{
		CReplyToCommand(client, "%s%t", g_sChatPrefix, "Type in chat !jackpot");

		return Plugin_Handled;
	}

	char sBuffer[32];
	GetCmdArg(1, sBuffer, 32);
	int iBet;
	int iCredits = MyStore_GetClientCredits(client);

	if (IsCharNumeric(sBuffer[0]))
	{
		iBet = StringToInt(sBuffer);
	}
	else if (StrEqual(sBuffer,"all"))
	{
		iBet = iCredits;
	}
	else if (StrEqual(sBuffer,"half"))
	{
		iBet = RoundFloat(iCredits / 2.0);
	}
	else if (StrEqual(sBuffer,"third"))
	{
		iBet = RoundFloat(iCredits / 3.0);
	}
	else if (StrEqual(sBuffer,"quater"))
	{
		iBet = RoundFloat(iCredits / 4.0);
	}

	if (iBet < gc_iMin.IntValue)
	{
		CReplyToCommand(client, "%s%t", g_sChatPrefix, "You have to spend at least x credits.", gc_iMin.IntValue, g_sCreditsName);

		return Plugin_Handled;
	}
	else if (iBet > gc_iMax.IntValue)
	{
		CReplyToCommand(client, "%s%t", g_sChatPrefix, "You can't spend that much credits", gc_iMax.IntValue, g_sCreditsName);

		return Plugin_Handled;
	}

	if (iBet > iCredits)
	{
		CReplyToCommand(client, "%s%t", g_sChatPrefix, "Not enough Credits");

		return Plugin_Handled;
	}

	SetBet(client, iBet);

	return Plugin_Handled;
}

public Action Timer_EndJackPot(Handle timer)
{
	g_hTimer = null;

	PayOut_JackPot();

	return Plugin_Stop;
}

public void OnMapEnd()
{
	if (!g_bActive)
		return;

	delete g_hTimer;

	PayOut_JackPot();
}


public void OnPluginEnd()
{
	if (!g_bActive)
		return;

	delete g_hTimer;

	PayOut_JackPot();
}


int GetClientOfSteamAccountID(int accountID)
{
	for (int i = 0; i <= MaxClients; i++)
	{
		if (!IsValidClient(i, false, true))
			continue;

		if (accountID == GetSteamAccountID(i, true))
		{
			return i;
		}
	}

	return -1;
}

void PayOut_JackPot()
{
	int jackpot = g_hJackPot.Length;
	int winner_accountID = g_hJackPot.Get(GetRandomInt(0, jackpot - 1));
	int winner = GetClientOfSteamAccountID(winner_accountID);

	if (g_iPlayer < 2)
	{
		MyStore_SetClientCredits(winner, MyStore_GetClientCredits(winner) + jackpot, "JackPot Refund");

		Reset_JackPot();

		CPrintToChat(winner, "%s%t", g_sChatPrefix, "Noone else cashed in", jackpot, g_sCreditsName);
		return;
	}

	if (winner == -1)
	{
		CPrintToChatAll("%s%t", g_sChatPrefix, "Winner is not in game anymore");

		int iIndex;
		while ((iIndex = g_hJackPot.FindValue(winner_accountID)) != -1)
		{
			g_hJackPot.Erase(iIndex);
		}

		winner_accountID = g_hJackPot.Get(GetRandomInt(0, g_hJackPot.Length - 1));
		winner = GetClientOfSteamAccountID(winner_accountID);

		if (winner == -1)
		{
			CPrintToChatAll("%s%t", g_sChatPrefix, "Second Winner is not in game anymore");
			for (int i = 0; i <= MaxClients; i++)
			{
				if (!IsValidClient(i, false, true) || !g_bUsed[i])
					continue;

				winner = i;
				break;
			}
		
		}
	}

	if (winner == -1)
	{
		CPrintToChatAll("%s%t", g_sChatPrefix, "All players disconnect", jackpot, g_sCreditsName);

		Reset_JackPot();

		return;
	}

	CPrintToChatAll("%s%t", g_sChatPrefix, "Player won the Jackpot", winner, jackpot, g_sCreditsName);

	if (gc_iFee.IntValue != 0)
	{
		int fee = jackpot * gc_iFee.IntValue / 100;
		CPrintToChat(winner, "%s%t", g_sChatPrefix, "You won the Jackpot - Fee", jackpot, g_sCreditsName, fee, gc_iFee.IntValue);
		jackpot -= fee;
	}
	else
	{
		CPrintToChat(winner, "%s%t", g_sChatPrefix, "You won the Jackpot", jackpot, g_sCreditsName);
	}

	MyStore_SetClientCredits(winner, MyStore_GetClientCredits(winner) + jackpot, "JackPot Win");

	Reset_JackPot();
}

void Reset_JackPot()
{
	for (int i = 0; i <= MaxClients; i++)
	{
		g_bUsed[i] = false;
		g_iBet[i] = 0;
	}

	g_iPlayer = 0;
	g_bActive = false;

	g_hJackPot.Clear();
	g_iPause = gc_iPause.IntValue + GetTime();
}

int SecToTime(int time, char[] buffer, int size)
{
	int iHours = 0;
	int iMinutes = 0;
	int iSeconds = time;

	while(iSeconds > 3600)
	{
		iHours++;
		iSeconds -= 3600;
	}
	while(iSeconds > 60)
	{
		iMinutes++;
		iSeconds -= 60;
	}

	if (iHours >= 1)
	{
		Format(buffer, size, "%t", "x hours, x minutes, x seconds", iHours, iMinutes, iSeconds);
	}
	else if (iMinutes >= 1)
	{
		Format(buffer, size, "%t", "x minutes, x seconds", iMinutes, iSeconds);
	}
	else
	{
		Format(buffer, size, "%t", "x seconds", iSeconds);
	}
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

void ReadCoreCFG()
{
	char sFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFile, sizeof(sFile), "configs/core.cfg");

	Handle hParser = SMC_CreateParser();
	char error[128];
	int line = 0;
	int col = 0;

	SMC_SetReaders(hParser, INVALID_FUNCTION, Callback_CoreConfig, INVALID_FUNCTION);
	SMC_SetParseEnd(hParser, INVALID_FUNCTION);

	SMCError result = SMC_ParseFile(hParser, sFile, line, col);
	delete hParser;

	if (result == SMCError_Okay)
		return;

	SMC_GetErrorString(result, error, sizeof(error));
	MyStore_LogMessage(0, LOG_ERROR, "ReadCoreCFG: Error: %s on line %i, col %i of %s", error, line, col, sFile);
}

public SMCResult Callback_CoreConfig(Handle parser, char[] key, char[] value, bool key_quotes, bool value_quotes)
{
	if (StrEqual(key, "MenuItemSound", false))
	{
		strcopy(g_sMenuItem, sizeof(g_sMenuItem), value);
	}
	else if (StrEqual(key, "MenuExitBackSound", false))
	{
		strcopy(g_sMenuExit, sizeof(g_sMenuExit), value);
	}

	return SMCParse_Continue;
}
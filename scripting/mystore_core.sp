/*
 * MyStore - Core plugin
 * by: shanapu
 * https://github.com/shanapu/
 * 
 * Copyright (C) 2018-2019 Thomas Schmidt (shanapu)
 * Credits: Kxnrl - https://github.com/Kxnrl/Store
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
#include <cstrike>

#include <mystore> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/mystore.inc

#include <colors> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/colors.inc
#include <autoexecconfig> //https://raw.githubusercontent.com/Impact123/AutoExecConfig/development/autoexecconfig.inc

#undef REQUIRE_PLUGIN
#include <adminmenu>
#define REQUIRE_PLUGIN


int g_iEquipment[MAXPLAYERS + 1][STORE_MAX_TYPES * STORE_MAX_SLOTS];
int g_iEquipmentSynced[MAXPLAYERS + 1][STORE_MAX_TYPES * STORE_MAX_SLOTS];
int g_iPlayerID[MAXPLAYERS + 1] = {0, ...};
int g_bLastJoin[MAXPLAYERS + 1] = {0, ...};
int g_iItems[MAXPLAYERS + 1] = {0, ...};
int g_iCredits[MAXPLAYERS + 1] = {0, ...};
bool g_bLoaded[MAXPLAYERS + 1] = {false, ...};

char g_sItemID[STORE_MAX_ITEM_HANDLERS][64];
Handle g_hItemPlugin[STORE_MAX_ITEM_HANDLERS];
Function g_fnItemMenu[STORE_MAX_ITEM_HANDLERS];
Function g_fnItemHandler[STORE_MAX_ITEM_HANDLERS];

char g_sPlanName[STORE_MAX_ITEMS][STORE_MAX_PLANS][ITEM_NAME_LENGTH];
int g_iPlanPrice[STORE_MAX_ITEMS][STORE_MAX_PLANS];
int g_iPlanTime[STORE_MAX_ITEMS][STORE_MAX_PLANS];

any g_aItems[STORE_MAX_ITEMS][Item_Data];
any g_aTypeHandlers[STORE_MAX_TYPES][Type_Handler];

int g_iPlayerItems[MAXPLAYERS + 1][STORE_MAX_ITEMS][CLIENT_ITEM_SIZE];
bool g_bMySQL = false;
bool g_bInvMode[MAXPLAYERS + 1];
bool g_bIsInRecurringMenu[MAXPLAYERS + 1] = {false, ...};

char g_sChatPrefix[128];
char g_sName[64];
char g_sCreditsName[64];
char g_sSelectedClient[MAXPLAYERS + 1][256];

ConVar gc_bEnable;
ConVar gc_iDBRetries;
ConVar gc_iDBTimeout;
ConVar gc_iCreditsStart;
ConVar gc_sMinFlags;
ConVar gc_sVIPFlags;
ConVar gc_bConfirm;
ConVar gc_sAdminFlags;
ConVar gc_bSaveOnDeath;
ConVar gc_bShowVIP;
ConVar gc_iLogging;
ConVar gc_iLoggingLevel;
ConVar gc_bSilent;
ConVar gc_sPrefix;
ConVar gc_sName;
ConVar gc_sCustomCommand;
ConVar gc_sCreditsName;
ConVar gc_bGenerateUId;

Database g_hDatabase = null;

File g_hLogFile = null;

Handle gf_hOnItemEquipt;
Handle gf_hPreviewItem;
Handle gf_hOnBuyItem;
Handle gf_hOnConfigExecuted;
Handle gf_hOnGetEndPrice;

int g_iItemCount = 0;
int g_iTypeHandlers = 0;
int g_iItemHandlers = 0;
int g_iPackageHandler = -1;
int g_iDatabaseRetries = 0;
int g_iPublicChatTrigger = 0;
int g_iSilentChatTrigger = 0;
int g_iMinFlags = 0;
int g_iVIPFlags = 0;
int g_iAdminFlags = 0;
int g_iMenuBack[MAXPLAYERS + 1];
int g_iLastSelection[MAXPLAYERS + 1];
int g_iSelectedItem[MAXPLAYERS + 1];
int g_iSelectedPlan[MAXPLAYERS + 1];
int g_iMenuClient[MAXPLAYERS + 1];
int g_iMenuNum[MAXPLAYERS + 1];
int g_iSpam[MAXPLAYERS + 1];

TopMenu g_hTopMenu = null;

TopMenuObject g_hTopMenuObject;


public Plugin myinfo = 
{
	name = "MyStore - MyResurrection of the Resurrection",
	author = "shanapu, Zephyrus",
	description = "A completely old Store system - completely rewritten.",
	version = "0.1",
	url = "github.com/shanapu/MyStore"
};

public void OnPluginStart()
{
	// Load the translations file
	LoadTranslations("mystore.phrases");
	LoadTranslations("common.phrases");

	// Register Commands
	RegConsoleCmd("sm_reloadconfig", Command_ReloadConfig);

	RegConsoleCmd("sm_store", Command_Store);
	RegConsoleCmd("sm_shop", Command_Store);
	RegConsoleCmd("sm_inv", Command_Inventory);
	RegConsoleCmd("sm_inventory", Command_Inventory);

	RegConsoleCmd("sm_givecredits", Command_GiveCredits);
	RegConsoleCmd("sm_resetplayer", Command_ResetPlayer);

	RegConsoleCmd("sm_credits", Command_Credits);

	DirExistsEx("cfg/sourcemod/MyStore");
	AutoExecConfig_SetFile("core", "sourcemod/MyStore");
	AutoExecConfig_SetCreateFile(true);

	// Register ConVars
	gc_bEnable = AutoExecConfig_CreateConVar("mystore_enable", "1", "Enable/disable plugin", _, true, 0.0, true, 1.0);
	gc_iDBRetries = AutoExecConfig_CreateConVar("mystore_database_retries", "4", "Number of retries if the connection fails to estabilish with timeout", _, true, 0.0, true, 10.0);
	gc_iDBTimeout = AutoExecConfig_CreateConVar("mystore_database_timeout", "10", "Timeout in seconds to wait for database connection before retry", _, true, 0.0, true, 6.0);
	gc_iCreditsStart = AutoExecConfig_CreateConVar("mystore_startcredits", "0", "Number of credits a client starts with", _, true, 0.0);
	gc_sMinFlags = AutoExecConfig_CreateConVar("mystore_access_flag", "", "Flag to access the !store menu. Leave blank to disable.");
	gc_sVIPFlags = AutoExecConfig_CreateConVar("mystore_vip_flag", "", "Flag for VIP access (all items unlocked). Leave blank to disable.");
	gc_sAdminFlags = AutoExecConfig_CreateConVar("mystore_admin_flag", "z", "Flag for admin access. Leave blank to disable.");
	gc_bConfirm = AutoExecConfig_CreateConVar("mystore_confirm", "1", "Enable/disable confirmation windows.", _, true, 0.0, true, 1.0);
	gc_bSaveOnDeath = AutoExecConfig_CreateConVar("mystore_save_on_death", "0", "Enable/disable client data saving on client death.", _, true, 0.0, true, 1.0);
	gc_sPrefix = AutoExecConfig_CreateConVar("mystore_chat_tag", "{green}[MyStore] {default}", "The chat tag to use for displaying messages (with colors).");
	gc_sName = AutoExecConfig_CreateConVar("mystore_name", "MyStore", "Name for the store for displaying messages & menus (no colors).");
	gc_bShowVIP = AutoExecConfig_CreateConVar("mystore_show_vip_items", "0", "If you enable this, items with flags will be shown in grey.", _, true, 0.0, true, 1.0);
	gc_iLogging = AutoExecConfig_CreateConVar("mystore_logging", "0", "Set this to 1 for file logging and 2 to SQL logging. Leaving on 0 = disabled. ", _, true, 0.0, true, 2.0);
	gc_iLoggingLevel = AutoExecConfig_CreateConVar("mystore_logging_level", "4", "4 = Log all events - Error, Admin, Event & Credit / 3 = No log credits - Log Error, Admin & Event / 2 = No log credits & events - Log Error & Admin / 1 = Only Log Error", _, true, 1.0, true, 4.0);
	gc_bSilent = AutoExecConfig_CreateConVar("mystore_silent_givecredits", "0", "Controls the give credits message visibility. 0 = public 1 = private 2 = no message", _, true, 0.0, true, 2.0);
	gc_sCustomCommand = AutoExecConfig_CreateConVar("mystore_cmds", "shop, item, mystore", "Set your custom chat commands for the store(!store (no 'sm_'/'!')(seperate with comma ', ')(max. 12 commands)");
	gc_sCreditsName = AutoExecConfig_CreateConVar("mystore_credits_name", "Credits", "Set your credits name");
	gc_bGenerateUId = AutoExecConfig_CreateConVar("mystore_generate_uids", "0", "Enable to generate unique_id for items. Beware can really fuck up your item.txt on bad formating");

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	// Add ConVars Hooks
	gc_sPrefix.AddChangeHook(OnSettingChanged);
	gc_sName.AddChangeHook(OnSettingChanged);
	gc_sCustomCommand.AddChangeHook(OnSettingChanged);
	gc_sCreditsName.AddChangeHook(OnSettingChanged);
	gc_sAdminFlags.AddChangeHook(OnSettingChanged);
	gc_sVIPFlags.AddChangeHook(OnSettingChanged);
	gc_sMinFlags.AddChangeHook(OnSettingChanged);

	// Hook events
	HookEvent("player_death", Event_PlayerDeath);

	// Initiaze the fake package handler
	g_iPackageHandler = MyStore_RegisterHandler("package", _, _, _, _);

	// Initiaze admin menu
	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
	{
		OnAdminMenuReady(topmenu);
	}

	// Read core.cfg for chat triggers
	ReadCoreCFG();

	// Add a say command listener for shortcuts
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");

	// Late Load
	for (int i = 1; i <= MaxClients; i++)
	{
		g_iCredits[i] = -1;
		g_iItems[i] = -1;

		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		OnClientConnected(i);
		OnClientPostAdminCheck(i);
	}
}

public void OnSettingChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	// Add custom commands
	if (convar == gc_sCustomCommand)
	{
		int iCount = 0;
		char sCommands[128], sCommandsL[12][32], sCommand[32];

		gc_sCustomCommand.GetString(sCommands, sizeof(sCommands));
		ReplaceString(sCommands, sizeof(sCommands), " ", "");
		iCount = ExplodeString(sCommands, ", ", sCommandsL, sizeof(sCommandsL), sizeof(sCommandsL[]));

		for (int i = 0; i < iCount; i++)
		{
			Format(sCommand, sizeof(sCommand), "sm_%s", sCommandsL[i]);
			if (GetCommandFlags(sCommand) != INVALID_FCVAR_FLAGS)
				continue;

			RegConsoleCmd(sCommand, Command_Store);
		}

		return;
	}
	// Get new convar strings
	else if (convar == gc_sAdminFlags)
	{
		g_iAdminFlags = ReadFlagString(newValue);
		return;
	}
	else if (convar == gc_sVIPFlags)
	{
		g_iVIPFlags = ReadFlagString(newValue);
		return;
	}
	else if (convar == gc_sMinFlags)
	{
		g_iMinFlags = ReadFlagString(newValue);
		return;
	}
	else if (convar == gc_sPrefix)
	{
		strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), newValue);
	}
	else if (convar == gc_sName)
	{
		strcopy(g_sName, sizeof(g_sName), newValue);
	}
	else if (convar == gc_sCreditsName)
	{
		strcopy(g_sCreditsName, sizeof(g_sCreditsName), newValue);
	}

	// Call foward MyStore_OnConfigsExecuted
	Forward_OnConfigsExecuted();
}

public void OnConfigsExecuted()
{
	// Connect to database
	if (g_hDatabase == null)
	{
		Database.Connect(SQLCallback_Connect, "mystore");
	}

	// Start timer for database connection retry
	if (gc_iDBRetries.IntValue > 0)
	{
		CreateTimer(gc_iDBTimeout.FloatValue, Timer_DatabaseTimeout);
	}

	// Add custom commands
	int iCount = 0;
	char sCommands[128], sCommandsL[12][32], sCommand[32];

	gc_sCustomCommand.GetString(sCommands, sizeof(sCommands));
	ReplaceString(sCommands, sizeof(sCommands), " ", "");
	iCount = ExplodeString(sCommands, ", ", sCommandsL, sizeof(sCommandsL), sizeof(sCommandsL[]));

	for (int i = 0; i < iCount; i++)
	{
		Format(sCommand, sizeof(sCommand), "sm_%s", sCommandsL[i]);
		if (GetCommandFlags(sCommand) != INVALID_FCVAR_FLAGS)
			continue;

		RegConsoleCmd(sCommand, Command_Store);
	}

	// Get convar strings
	char sBuffer[16];
	gc_sAdminFlags.GetString(sBuffer, sizeof(sBuffer));
	g_iAdminFlags = ReadFlagString(sBuffer);

	gc_sMinFlags.GetString(sBuffer, sizeof(sBuffer));
	g_iMinFlags = ReadFlagString(sBuffer);

	gc_sVIPFlags.GetString(sBuffer, sizeof(sBuffer));
	g_iVIPFlags = ReadFlagString(sBuffer);

	gc_sPrefix.GetString(g_sChatPrefix, sizeof(g_sChatPrefix));
	gc_sName.GetString(g_sName, sizeof(g_sName));
	gc_sCreditsName.GetString(g_sCreditsName, sizeof(g_sCreditsName));

	// Call foward MyStore_OnConfigsExecuted
	Forward_OnConfigsExecuted();

	// Open log file
	if (gc_iLogging.IntValue != 1 || g_hLogFile != null)
		return;

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "logs/mystore.log");
	g_hLogFile = OpenFile(sPath, "at");
}

public void OnPluginEnd()
{
	// Save all client data
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		if (!g_bLoaded[i])
			continue;

		OnClientDisconnect(i);
	}
}

/******************************************************************************
                   Commands
******************************************************************************/

public Action Command_Say(int client, char [] command, int args)
{
	if (!gc_bEnable.BoolValue)
		return Plugin_Continue;

	// Monitor chat for menu shortcuts
	if (args < 1)
		return Plugin_Continue;

	char sArg[65];
	GetCmdArg(1, sArg, sizeof(sArg));

	// Check for sourcemod chattriggers ./sourcemod/configs/core.cfg
	if (strlen(sArg) > 1 && (sArg[0] == g_iPublicChatTrigger || sArg[0] == g_iSilentChatTrigger))
	{
		for (int i = 0; i < g_iItemCount; i++)
		{
			//Have we found a shortcut?
			if (strcmp(g_aItems[i][szShortcut], sArg[1]) == 0 && g_aItems[i][szShortcut][0] != 0)
			{
				g_bInvMode[client] = false;
				g_iMenuClient[client] = client;
				g_iSelectedItem[client] = i;

				//Already has item? Show menu
				if (MyStore_HasClientItem(client, i))
				{
					if (g_aItems[i][bPreview])
					{
						DisplayPreviewMenu(client, i);
					}
					else
					{
						DisplayItemMenu(client, i);
					}
				}
				//Don't has item? show a buy menu or buy item
				else
				{
					if (g_aItems[i][iPlans] != 0)
					{
						DisplayPlanMenu(client, i);
					}
					else if (gc_bConfirm.BoolValue)
					{
						char sTitle[128];
						Format(sTitle, sizeof(sTitle), "%t", "Confirm_Buy", g_aItems[i][szName], g_aTypeHandlers[g_aItems[i][iHandler]][szType]);
						MyStore_DisplayConfirmMenu(client, sTitle, MenuHandler_Store, 0);
					}
					else
					{
						BuyItem(client, i);
					}
				}

				break;
			}
		}

		//used the silent trigger? don't show it.
		if (sArg[0] == g_iSilentChatTrigger)
		{
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

public Action Command_ReloadConfig(int client, int params)
{
	if (client && !IsClientAdmin(client))
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "You dont have permission");
		return Plugin_Handled;
	}

	Forward_OnConfigsExecuted();

	// Reload items from ./sourcemod/configs/MyStore/items.cfg
	ReloadConfig();
	return Plugin_Handled;
}

public Action Command_Store(int client, int params)
{
	//Buisness as usual
	if (!gc_bEnable.BoolValue)
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Store Disabled");
		return Plugin_Handled;
	}

	if (g_iMinFlags != 0 && !HasClientAccess(client))
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "You dont have permission");
		return Plugin_Handled;
	}

	if ((g_iCredits[client] == -1 && g_iItems[client] == -1) || !g_bLoaded[client])
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Inventory hasnt been fetched");
		return Plugin_Handled;
	}

	g_bInvMode[client] = false;
	g_iMenuClient[client] = client;

	//Display Store Menu ...
	DisplayStoreMenu(client);

	return Plugin_Handled;
}

public Action Command_Inventory(int client, int params)
{
	//Buisness as usual
	if (!gc_bEnable.BoolValue)
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Store Disabled");
		return Plugin_Handled;
	}

	if (g_iMinFlags != 0 && !HasClientAccess(client))
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "You dont have permission");
		return Plugin_Handled;
	}

	if ((g_iCredits[client] == -1 && g_iItems[client] == -1) || !g_bLoaded[client])
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Inventory hasnt been fetched");
		return Plugin_Handled;
	}

	g_bInvMode[client] = true;
	g_iMenuClient[client] = client;
	DisplayStoreMenu(client);

	return Plugin_Handled;
}

public Action Command_GiveCredits(int client, int params)
{
	//Buisness as usual
	if (!gc_bEnable.BoolValue)
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Store Disabled");
		return Plugin_Handled;
	}

	if (client && !IsClientAdmin(client))
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "You dont have permission");
		return Plugin_Handled;
	}

	//Credits
	char sTmp[64];
	GetCmdArg(2, sTmp, sizeof(sTmp));

	int iCredit = StringToInt(sTmp);

	//Client
	bool bTmp;
	int iTargets[1];
	GetCmdArg(1, sTmp, sizeof(sTmp));

	int iReceiver = -1;
	if (strncmp(sTmp, "STEAM_", 6) == 0)
	{
		iReceiver = GetClientBySteamID(sTmp);
		// SteamID is not ingame
		if (iReceiver == 0)
		{
			char sQuery[512];
			if (g_bMySQL)
			{
				Format(sQuery, sizeof(sQuery), "INSERT IGNORE INTO mystore_players (authid, credits) VALUES (\"%s\", %i) ON DUPLICATE KEY UPDATE credits = credits+%i", sTmp[8], iCredit, iCredit);
			}
			else
			{
				Format(sQuery, sizeof(sQuery), "INSERT OR IGNORE INTO mystore_players (authid) VALUES (\"%s\")", sTmp[8]);

				g_hDatabase.Query(SQLCallback_Void_Error, sQuery);

				Format(sQuery, sizeof(sQuery), "UPDATE mystore_players SET credits = credits + %i WHERE authid = \"%s\"", iCredit, sTmp[8]);
			}

			g_hDatabase.Query(SQLCallback_Void_Error, sQuery);
			CPrintToChatAll("%s%t", g_sChatPrefix, "Credits Given", sTmp[8], iCredit, g_sCreditsName);
			iReceiver = -1;
		}
	}
	else if (strcmp(sTmp, "@all") == 0)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i))
				continue;

			FakeClientCommandEx(client, "sm_givecredits \"%N\" %i", i, iCredit);
		}
	}
	else if (strcmp(sTmp, "@t") == 0)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i))
				continue;

			if (GetClientTeam(i) != CS_TEAM_T)
				continue;

			FakeClientCommandEx(client, "sm_givecredits \"%N\" %i", i, iCredit);
		}
	}
	else if (strcmp(sTmp, "@ct") == 0)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i))
				continue;

			if (GetClientTeam(i) != CS_TEAM_CT)
				continue;

			FakeClientCommandEx(client, "sm_givecredits \"%N\" %i", i, iCredit);
		}
	}
	else
	{
		int iClients = ProcessTargetString(sTmp, 0, iTargets, 1, 0, sTmp, sizeof(sTmp), bTmp);
		if (iClients > 2)
		{
			ReplyToCommand(client, "%s%t", g_sChatPrefix, "Credit Too Many Matches");
			return Plugin_Handled;
		}
		else if (iClients != 1)
		{
			ReplyToCommand(client, "%s%t", g_sChatPrefix, "Credit No Match");
			return Plugin_Handled;
		}

		iReceiver = iTargets[0];
	}

	// The player is on the server
	if (iReceiver != -1)
	{
		g_iCredits[iReceiver] += iCredit;
		if (gc_bSilent.IntValue == 1)
		{
			ReplyToCommand(client, "%s%t", g_sChatPrefix, "Credits Given", iReceiver, iCredit, g_sCreditsName);
			CPrintToChat(iReceiver, "%s%t", g_sChatPrefix, "Credits Given", iReceiver, iCredit, g_sCreditsName);
		}
		else if (gc_bSilent.IntValue == 0)
		{
			CPrintToChatAll("%s%t", g_sChatPrefix, "Credits Given", iReceiver, iCredit, g_sCreditsName);
		}

		MyLogMessage(client, LOG_ADMIN, "%i credits to %L", iCredit, iReceiver);
		MyLogMessage(iReceiver, LOG_CREDITS, "%i credits given by %L", iCredit, client);
	}

	return Plugin_Handled;
}

public Action Command_ResetPlayer(int client, int params)
{
	if (client && !IsClientAdmin(client))
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "You dont have permission");
		return Plugin_Handled;
	}

	char sTmp[64];
	bool bTmp;
	int iTargets[1];
	GetCmdArg(1, sTmp, sizeof(sTmp));

	int iReceiver = -1;
	if (strncmp(sTmp, "STEAM_", 6) == 0)
	{
		iReceiver = GetClientBySteamID(sTmp);
		// SteamID is not ingame
		if (iReceiver == 0)
		{
			char sQuery[512];
			Format(sQuery, sizeof(sQuery), "SELECT id, authid FROM mystore_players WHERE authid = \"%s\"", sTmp[9]);
			g_hDatabase.Query(SQLCallback_ResetPlayer, sQuery, GetClientUserId(client));
		}
	}
	else
	{
		int iClients = ProcessTargetString(sTmp, 0, iTargets, 1, 0, sTmp, sizeof(sTmp), bTmp);
		if (iClients>2)
		{
			CPrintToChat(client, "%s%t", g_sChatPrefix, "Credit Too Many Matches");
			return Plugin_Handled;
		}

		if (iClients != 1)
		{
			CPrintToChat(client, "%s%t", g_sChatPrefix, "Credit No Match");
			return Plugin_Handled;
		}

		iReceiver = iTargets[0];
	}

	// The player is on the server
	if (iReceiver != -1)
	{
		g_iCredits[iReceiver] = 0;
		for (int i = 0; i < g_iItems[iReceiver]; i++)
		{
			MyStore_RemoveItem(iReceiver, g_iPlayerItems[iReceiver][i][UNIQUE_ID]);
		}

		MyLogMessage(client, LOG_ADMIN, "%L resetted. Removed %i credits & %i items", iReceiver, g_iCredits[iReceiver], g_iItems[iReceiver]);
		MyLogMessage(iReceiver, LOG_CREDITS, "%i credits & %i items resetted by %L", g_iCredits[iReceiver], g_iItems[iReceiver], client);

		CPrintToChatAll("%s%t", g_sChatPrefix, "Player Resetted", iReceiver);
	}

	return Plugin_Handled;
}

public Action Command_Credits(int client, int params)
{
	//Buisness as usual
	if (!gc_bEnable.BoolValue)
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Store Disabled");
		return Plugin_Handled;
	}

	if (g_iCredits[client] == -1 && g_iItems[client] == -1)
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Inventory hasnt been fetched");
		return Plugin_Handled;
	}

	if (g_iSpam[client] < GetTime())
	{
		CPrintToChatAll("%s%t", g_sChatPrefix, "Player Credits", client, g_iCredits[client], g_sCreditsName);
		g_iSpam[client] = GetTime() + 20;
	}
	else
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Spam Cooldown", g_iSpam[client] - GetTime());
	}

	return Plugin_Handled;
}

/******************************************************************************
                   Events
******************************************************************************/

public void Event_PlayerDeath(Event event, char[] name, bool dontBroadcast)
{
	if (!gc_bSaveOnDeath.BoolValue)
		return;

	int victim = GetClientOfUserId(event.GetInt("userid"));

	SQL_SaveClientData(victim);
	SQL_SaveClientInventory(victim);
	SQL_SaveClientEquipment(victim);
}

/******************************************************************************
                   Sourcemod forwards
******************************************************************************/

public void OnMapStart()
{
	for (int i = 0; i < g_iTypeHandlers; i++)
	{
		if (g_aTypeHandlers[i][fnMapStart] == INVALID_FUNCTION)
			continue;

		Call_StartFunction(g_aTypeHandlers[i][hPlugin], g_aTypeHandlers[i][fnMapStart]);
		Call_PushString(g_sChatPrefix);
		Call_Finish();
	}
}

public void OnClientConnected(int client)
{
	//Reset variables
	g_iSpam[client] = 0;
	g_iCredits[client] = -1;
	g_iItems[client] = -1;
	g_bLoaded[client] = false;

	for (int i = 0; i < STORE_MAX_TYPES; i++)
	{
		for (int a = 0; a < STORE_MAX_SLOTS; a++)
		{
			g_iEquipment[client][i * STORE_MAX_SLOTS + a] = -2;
			g_iEquipmentSynced[client][i * STORE_MAX_SLOTS + a] = -2;
		}
	}
}

public void OnClientPostAdminCheck(int client)
{
	if (IsFakeClient(client))
		return;

	SQL_LoadClientInventory(client);
}

public void OnClientDisconnect(int client)
{
	if (IsFakeClient(client))
		return;

	SQL_SaveClientData(client);
	SQL_SaveClientInventory(client);
	SQL_SaveClientEquipment(client);

	MyLogMessage(client, LOG_EVENT, "Left game with %i credits & %i items", g_iCredits[client], g_iItems[client]);

	g_iCredits[client] = -1;
	g_iItems[client] = -1;
	g_bLoaded[client] = false;
	g_bIsInRecurringMenu[client] = false;
}

public void OnAdminMenuReady(Handle topmenu)
{
	if (topmenu == g_hTopMenu)
		return;

	g_hTopMenu = view_as<TopMenu>(topmenu);

	g_hTopMenuObject = AddToTopMenu(g_hTopMenu, "MyStore Admin", TopMenuObject_Category, CategoryHandler_StoreAdmin, INVALID_TOPMENUOBJECT);
	AddToTopMenu(g_hTopMenu, "sm_resetdb", TopMenuObject_Item, AdminMenu_ResetDb, g_hTopMenuObject, "sm_resetdb", g_iAdminFlags);
	AddToTopMenu(g_hTopMenu, "sm_reloadconfig", TopMenuObject_Item, AdminMenu_ReloadConfig, g_hTopMenuObject, "sm_reloadconfig", g_iAdminFlags);
	AddToTopMenu(g_hTopMenu, "sm_resetplayer", TopMenuObject_Item, AdminMenu_ResetPlayer, g_hTopMenuObject, "sm_resetplayer", g_iAdminFlags);
	AddToTopMenu(g_hTopMenu, "sm_givecredits", TopMenuObject_Item, AdminMenu_GiveCredits, g_hTopMenuObject, "sm_givecredits", g_iAdminFlags);
	AddToTopMenu(g_hTopMenu, "sm_viewinventory", TopMenuObject_Item, AdminMenu_ViewInventory, g_hTopMenuObject, "sm_viewinventory", g_iAdminFlags);
}

/******************************************************************************
                   Menus & Handler
******************************************************************************/

public void CategoryHandler_StoreAdmin(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int param, char[] sBuffer, int maxlength)
{
	if (action == TopMenuAction_DisplayTitle || action == TopMenuAction_DisplayOption)
	{
		Format(sBuffer, maxlength, "Store Admin");
	}
}

public void AdminMenu_ReloadConfig(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int client, char[] sBuffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(sBuffer, maxlength, "Reload configs");
	}
	else if (action == TopMenuAction_SelectOption)
	{
		g_iMenuNum[client] = 0;
		MyStore_DisplayConfirmMenu(client, "Do you want to reload configs/MyStore/items.txt?", FakeMenuHandler_ReloadConfig, 0);
	}
}


public void AdminMenu_ResetDb(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int client, char[] sBuffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(sBuffer, maxlength, "Reset database");
	}
	else if (action == TopMenuAction_SelectOption)
	{
		g_iMenuNum[client] = 0;
		MyStore_DisplayConfirmMenu(client, "Do you want to reset database?\nAfter that, you have to restart the server!", FakeMenuHandler_ResetDatabase, 0);
	}
}

public void FakeMenuHandler_ResetDatabase(Menu menu, MenuAction action, int client, int param2)
{
	float time = GetEngineTime();
	Transaction tnx = new Transaction();

	tnx.AddQuery("DROP TABLE mystore_players");
	tnx.AddQuery("DROP TABLE mystore_items");
	tnx.AddQuery("DROP TABLE mystore_equipment");

	g_hDatabase.Execute(tnx, SQLTXNCallback_Success, SQLTXNCallback_Error, time);

//	ServerCommand("_restart;");
}

public void FakeMenuHandler_ReloadConfig(Menu menu, MenuAction action, int client, int param2)
{
	Forward_OnConfigsExecuted();

	ReloadConfig();
}

public void AdminMenu_ResetPlayer(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int client, char[] sBuffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(sBuffer, maxlength, "Reset player");
	}
	else if (action == TopMenuAction_SelectOption)
	{
		g_iMenuNum[client] = 4;
		Menu menu = new Menu(MenuHandler_ResetPlayer);
		menu.SetTitle("Choose a player to reset");
		menu.ExitBackButton = true;

		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientConnected(i) || !IsClientAuthorized(i))
				continue;

			char sName[64];
			char sAuthId[32];
			GetClientName(i, sName, sizeof(sName));
			GetLegacyAuthString(i, sAuthId, sizeof(sAuthId));
			menu.AddItem(sAuthId, sName);
		}
		menu.Display(client, MENU_TIME_FOREVER);
	}
}

public int MenuHandler_ResetPlayer(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_End)
	{
		menu.Cancel();
	}
	else if (action == MenuAction_Select)
	{
		if (menu == null)
		{
			FakeClientCommandEx(client, "sm_resetplayer \"%s\"", g_sSelectedClient[client]);
		}
		else
		{
			int style;
			char sName[64];
			menu.GetItem(param2, g_sSelectedClient[client], sizeof(g_sSelectedClient[]), style, sName, sizeof(sName));

			char sTitle[256];
			Format(sTitle, sizeof(sTitle), "Do you want to reset %s?", sName);
			MyStore_DisplayConfirmMenu(client, sTitle, MenuHandler_ResetPlayer, 0);
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		RedisplayAdminMenu(g_hTopMenu, client);
	}
}

public void AdminMenu_GiveCredits(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int client, char[] sBuffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(sBuffer, maxlength, "Give credits");
	}
	else if (action == TopMenuAction_SelectOption)
	{
		g_iMenuNum[client] = 5;
		Menu menu = new Menu(MenuHandler_GiveCredits);
		menu.SetTitle("Choose a player to give credits to");
		menu.ExitBackButton = true;

		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientConnected(i) || !IsClientAuthorized(i))
				continue;

			char sName[64];
			char sAuthId[32];
			GetClientName(i, sName, sizeof(sName));
			GetLegacyAuthString(i, sAuthId, sizeof(sAuthId));
			menu.AddItem(sAuthId, sName);
		}
		menu.Display(client, MENU_TIME_FOREVER);
	}
}

public int MenuHandler_GiveCredits(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_End)
	{
		menu.Cancel();
	}
	else if (action == MenuAction_Select)
	{
		if (param2 != -1)
		{
			menu.GetItem(param2, g_sSelectedClient[client], sizeof(g_sSelectedClient[]));
		}

		Menu mMenu = new Menu(MenuHandler_GiveCredits2);

		int target = GetClientBySteamID(g_sSelectedClient[client]);
		if (target == 0)
		{
			AdminMenu_GiveCredits(g_hTopMenu, TopMenuAction_SelectOption, g_hTopMenuObject, client, "", 0);
			return;
		}

		mMenu.SetTitle("Choose the amount of %s\n%N - %i %s", g_sCreditsName, target, g_iCredits[target], g_sCreditsName);
		mMenu.ExitBackButton = true;
		mMenu.AddItem("-1000", "-1000");
		mMenu.AddItem("-100", "-100");
		mMenu.AddItem("-10", "-10");
		mMenu.AddItem("10", "10");
		mMenu.AddItem("100", "100");
		mMenu.AddItem("1000", "1000");
		mMenu.Display(client, MENU_TIME_FOREVER);
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		RedisplayAdminMenu(g_hTopMenu, client);
	}
}

public int MenuHandler_GiveCredits2(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_End)
	{
		menu.Cancel();
	}
	else if (action == MenuAction_Select)
	{
		char sData[11];
		menu.GetItem(param2, sData, sizeof(sData));
		FakeClientCommand(client, "sm_givecredits \"%s\" %s", g_sSelectedClient[client], sData);
		MenuHandler_GiveCredits(null, MenuAction_Select, client, -1);  //null oder menu  ??
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		AdminMenu_GiveCredits(g_hTopMenu, TopMenuAction_SelectOption, g_hTopMenuObject, client, "", 0);
	}
}

public void AdminMenu_ViewInventory(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int client, char[] sBuffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(sBuffer, maxlength, "View inventory");
	}
	else if (action == TopMenuAction_SelectOption)
	{
		g_iMenuNum[client] = 4;
		Menu menu = new Menu(MenuHandler_ViewInventory);
		menu.SetTitle("Choose a player");
		menu.ExitBackButton = true;

		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientConnected(i) || !IsClientAuthorized(i))
				continue;

			char sName[64];
			char sAuthId[32];
			GetClientName(i, sName, sizeof(sName));
			GetLegacyAuthString(i, sAuthId, sizeof(sAuthId));
			menu.AddItem(sAuthId, sName);
		}
		menu.Display(client, MENU_TIME_FOREVER);
	}
}

public int MenuHandler_ViewInventory(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_End)
	{
		menu.Cancel();
	}
	else if (action == MenuAction_Select)
	{
		menu.GetItem(param2, g_sSelectedClient[client], sizeof(g_sSelectedClient[]));
		int target = GetClientBySteamID(g_sSelectedClient[client]);
		if (target == 0)
		{
			AdminMenu_ViewInventory(g_hTopMenu, TopMenuAction_SelectOption, g_hTopMenuObject, client, "", 0);
			return;
		}

		g_bInvMode[client] = true;
		g_iMenuClient[client] = target;
		DisplayStoreMenu(client);
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		RedisplayAdminMenu(g_hTopMenu, client);
	}
}

// The main store menu
void DisplayStoreMenu(int client, int parent = -1, int last = -1)
{
	if (!client)
		return;

	if (!gc_bEnable.BoolValue)
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Store Disabled");
		return;
	}

	g_iMenuNum[client] = 1;
	int target = g_iMenuClient[client];

	if (!target || !IsClientInGame(target) || IsFakeClient(target))
	{
		g_iMenuClient[client] = client;

		//Display Store Menu ...
		DisplayStoreMenu(client);
		return;
	}

	Menu menu = new Menu(MenuHandler_Store);

	// Build menu title
	if (parent != -1)
	{
		menu.ExitBackButton = true;
		if (client == target)
		{
			menu.SetTitle("%s\n%s\n%t", g_aItems[parent][szName], g_aItems[parent][szDescription], "Title Credits", g_sCreditsName, g_iCredits[target]);
		}
		else
		{
			menu.SetTitle("%N\n%s\n%t", target, g_aItems[parent][szName], "Title Credits", g_sCreditsName, g_iCredits[target]);
		}

		g_iMenuBack[client] = g_aItems[parent][iParent];
	}
	else if (g_bInvMode[client])
	{
		menu.SetTitle("%t\n%t", "Title Inventory", "Title Credits", g_sCreditsName, g_iCredits[target]);
	}
	else if (client == target)
	{
		menu.SetTitle("%t\n%t", "Title Store", g_sName, "Title Credits", g_sCreditsName, g_iCredits[target]);
	}
	else
	{
		menu.SetTitle("%N\n%t\n%t", target, "Title Store", g_sName, "Title Credits", g_sCreditsName, g_iCredits[target]);
	}

	char sId[11];
	int iFlags = GetUserFlagBits(target);
	int iPosition = 0;

	g_iSelectedItem[client] = parent;

	// List all Items
	for (int i = 0; i < g_iItemCount; i++)
	{
		if (g_aItems[i][iParent] == parent && (!gc_bShowVIP.BoolValue && CheckFlagBits(target, g_aItems[i][iFlagBits], iFlags && CheckSteamAuth(target, g_aItems[i][szSteam])) || gc_bShowVIP.BoolValue))
		{
			int costs = GetLowestPrice(i);
			bool reduced = false;
			costs = Forward_OnGetEndPrice(client, i, costs, reduced);

			// This is a package
			if (g_aItems[i][iHandler] == g_iPackageHandler)
			{
				if (!PackageHasClientItem(target, i, g_bInvMode[client]))
					continue;

				int iStyle = ITEMDRAW_DEFAULT;
				if (gc_bShowVIP.BoolValue && (!CheckFlagBits(target, g_aItems[i][iFlagBits], iFlags) || !CheckSteamAuth(target, g_aItems[i][szSteam])))
				{
					iStyle = ITEMDRAW_DISABLED;
				}

				char sBuffer[128];
				IntToString(i, sId, sizeof(sId));
				// Player already own the package or the package is free
				if (g_aItems[i][iPrice] == -1 || MyStore_HasClientItem(target, i))
				{
					Format(sBuffer, sizeof(sBuffer), "%s\n%s", g_aItems[i][szName], g_aItems[i][szDescription]);
					if (PackageHasClientItem(target, i, false))
					{
						if (menu.ItemCount == iPosition)
						{
							menu.AddItem(sId, sBuffer, iStyle);
						}
						else
						{
							menu.InsertItem(iPosition, sId, sBuffer, iStyle);
						}
					}
					else
					{
						menu.AddItem(sId, sBuffer, iStyle);
					}
				}
				// Player can buy the package as normal trade in
				else if (!g_bInvMode[client] && g_aItems[i][iPlans] == 0 && g_aItems[i][bBuyable])
				{
					Format(sBuffer, sizeof(sBuffer), "%t\n%s", "Item Available", g_aItems[i][szName], g_aItems[i][iPrice], g_aItems[i][szDescription]);
					if (menu.ItemCount == iPosition)
					{
						menu.AddItem(sId, sBuffer, iStyle);
					}
					else
					{
						menu.InsertItem(iPosition, sId, sBuffer, iStyle);
					}
				}
				// Player can buy the package in a plan
				else if (!g_bInvMode[client])
				{
					Format(sBuffer, sizeof(sBuffer), "%t\n%s", "Item Plan Available", g_aItems[i][szName], g_aItems[i][szDescription]);
					if (menu.ItemCount == iPosition)
					{
						menu.AddItem(sId, sBuffer, (costs <= g_iCredits[target] ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED));
					}
					else
					{
						menu.InsertItem(iPosition, sId, sBuffer, (costs <= g_iCredits[target] ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED));
					}
				}
				iPosition++; // old
			}
			// This is a normal item
			else
			{
				char sBuffer[128];
				IntToString(i, sId, sizeof(sId));
				// Player already own the item
				if (MyStore_HasClientItem(target, i))
				{
					// Player has item equipt
					if (IsEquipped(target, i))
					{
						Format(sBuffer, sizeof(sBuffer), "%t\n%s", "Item Equipped", g_aItems[i][szName], g_aItems[i][szDescription]);
						if (menu.ItemCount == iPosition)
						{
							menu.AddItem(sId, sBuffer, ITEMDRAW_DEFAULT);
						}
						else
						{
							menu.InsertItem(iPosition, sId, sBuffer, ITEMDRAW_DEFAULT);
						}
					}
					// Item is not equipt
					else
					{
						Format(sBuffer, sizeof(sBuffer), "%t\n%s", "Item Bought", g_aItems[i][szName], g_aItems[i][szDescription]);
						if (menu.ItemCount == iPosition)
						{
							menu.AddItem(sId, sBuffer, ITEMDRAW_DEFAULT);
						}
						else
						{
							menu.InsertItem(iPosition, sId, sBuffer, ITEMDRAW_DEFAULT);
						}
					}
				}
				// Player don't own the item
				else if (!g_bInvMode[client] && g_aItems[i][bBuyable])
				{
					int iStyle = ITEMDRAW_DEFAULT;
					if ((g_aItems[i][iPlans] == 0 && g_iCredits[target] < costs && !g_aItems[i][bPreview]) || (gc_bShowVIP.BoolValue && !CheckFlagBits(target, g_aItems[i][iFlagBits], iFlags) && !CheckSteamAuth(target, g_aItems[i][szSteam])))
					{
						iStyle = ITEMDRAW_DISABLED;
					}

					// Player can buy the item as normal trade in
					if (g_aItems[i][iPlans] == 0)
					{
						Format(sBuffer, sizeof(sBuffer), "%t %t\n%s", "Item Available", g_aItems[i][szName], costs, reduced ? "discount" : "nodiscount", g_aItems[i][szDescription]);
						menu.AddItem(sId, sBuffer, iStyle);
					}
					// Player can buy the item in a plan
					else
					{
						Format(sBuffer, sizeof(sBuffer), "%t %t\n%s", "Item Plan Available", g_aItems[i][szName], reduced ? "discount" : "nodiscount", g_aItems[i][szDescription]);
						menu.AddItem(sId, sBuffer, iStyle);
					}
				}

			}

		//	iPosition++;  //new
		}
	}

	// Package
	if (parent != -1)
	{
		for (int i = 0; i < g_iItemHandlers; i++)
		{
			if (g_hItemPlugin[i] == null)
				continue;

			Call_StartFunction(g_hItemPlugin[i], g_fnItemMenu[i]);
			Call_PushCellRef(menu);
			Call_PushCell(client);
			Call_PushCell(parent);
			Call_Finish();
		}
	}

	if (last == -1)
	{
		menu.Display(client, MENU_TIME_FOREVER);
	}
	else
	{
		DisplayMenuAtItem(menu, client, (last / menu.Pagination) * menu.Pagination, 0);
	}
}

public int MenuHandler_Store(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_End)
	{
		menu.Cancel();
	}
	else if (action == MenuAction_Select)
	{
		int target = g_iMenuClient[client];
		// Confirmation was given
		if (menu == null)
		{
			if (param2 == 0)
			{
				g_iMenuBack[client] = 1;
				int costs = 0;

				if (g_iSelectedPlan[client] == -1)
				{
					costs = Forward_OnGetEndPrice(client, g_iSelectedItem[client], g_aItems[g_iSelectedItem[client]][iPrice]);
				}
				else
				{
					costs = Forward_OnGetEndPrice(client, g_iSelectedItem[client], g_iPlanPrice[g_iSelectedItem[client]][g_iSelectedPlan[client]]);
				}

				if (g_iCredits[target] >= costs && !MyStore_HasClientItem(target, g_iSelectedItem[client]))
				{
					BuyItem(target, g_iSelectedItem[client], g_iSelectedPlan[client]);
				}

				DisplayItemMenu(client, g_iSelectedItem[client]);
			}
		}
		else
		{
			char sId[64];
			menu.GetItem(param2, sId, sizeof(sId));

			g_iLastSelection[client] = param2;

			// This is menu handler stuff
			if (!(48 <= sId[0] <= 57))
			{
				bool ret;
				for (int i = 0; i < g_iItemHandlers; i++)
				{
					Call_StartFunction(g_hItemPlugin[i], g_fnItemHandler[i]);
					Call_PushCell(target);
					Call_PushString(sId);
					Call_PushCell(g_iSelectedItem[client]);
					Call_Finish(ret);

					if (ret)
						break;
				}
			}
			// We are selcting an item
			else
			{
				int iIndex = StringToInt(sId);
				g_iMenuBack[client] = g_aItems[iIndex][iParent];
				g_iSelectedItem[client] = iIndex;
				g_iSelectedPlan[client] = -1;

				if (g_aItems[iIndex][bPreview] && !MyStore_HasClientItem(target, iIndex) && g_aItems[iIndex][iPrice] != -1 && g_aItems[iIndex][iPlans] == 0)
				{
					DisplayPreviewMenu(client, iIndex);
					return;
				}

				int costs = GetLowestPrice(iIndex);
				costs = Forward_OnGetEndPrice(client, iIndex, costs);

				if ((g_iCredits[target] >= costs || g_aItems[iIndex][iPlans] > 0) && !MyStore_HasClientItem(target, iIndex) && g_aItems[iIndex][iPrice] != -1)
				{
					if (g_aItems[iIndex][iPlans] > 0)
					{
						DisplayPlanMenu(client, iIndex);
						return;
					}
					else if (gc_bConfirm.BoolValue)
					{
						char sTitle[128];
						Format(sTitle, sizeof(sTitle), "%t", "Confirm_Buy", g_aItems[iIndex][szName], g_aTypeHandlers[g_aItems[iIndex][iHandler]][szType]);
						MyStore_DisplayConfirmMenu(client, sTitle, MenuHandler_Store, 0);
						return;
					}
					else
					{
						BuyItem(target, iIndex);
						DisplayItemMenu(client, iIndex);
					}
				}

				if (g_aItems[iIndex][iHandler] != g_iPackageHandler)
				{
					if (MyStore_HasClientItem(target, iIndex))
					{
						DisplayItemMenu(client, iIndex);
					}
					else
					{
						DisplayStoreMenu(client, g_iMenuBack[client]);
					}
				}
				else
				{
					if (MyStore_HasClientItem(target, iIndex) || g_aItems[iIndex][iPrice] == -1)
					{
						DisplayStoreMenu(client, iIndex);
					}
					else
					{
						DisplayStoreMenu(client, g_aItems[iIndex][iParent]);
					}
				}
			}
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack)
		{
			MyStore_DisplayPreviousMenu(client);
		}
	}
}

public void DisplayItemMenu(int client, int itemid)
{
	if (!gc_bEnable.BoolValue)
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Store Disabled");
		return;
	}

	if (g_aTypeHandlers[g_aItems[itemid][iHandler]][bRaw])
	{
		Call_StartFunction(g_aTypeHandlers[g_aItems[itemid][iHandler]][hPlugin], g_aTypeHandlers[g_aItems[itemid][iHandler]][fnUse]);
		Call_PushCell(client);
		Call_PushCell(itemid);
		Call_Finish();
		return;
	}

	if (g_aItems[itemid][iHandler] == g_iPackageHandler)
	{
		DisplayStoreMenu(client, itemid);
		return;
	}

	g_iMenuNum[client] = 1;
	g_iMenuBack[client] = g_aItems[itemid][iParent];
	int target = g_iMenuClient[client];

	Menu menu = new Menu(MenuHandler_Item);
	menu.ExitBackButton = true;

	bool bEquipped = IsEquipped(target, itemid);
	char sTitle[256];
	int iIndex = 0;
	if (bEquipped)
	{
		iIndex = Format(sTitle, sizeof(sTitle), "%t\n%s\n%t", "Item Equipped", g_aItems[itemid][szName], g_aItems[itemid][szDescription], "Title Credits", g_sCreditsName, g_iCredits[target]);
	}
	else
	{
		iIndex = Format(sTitle, sizeof(sTitle), "%s\n%s\n%t", g_aItems[itemid][szName], g_aItems[itemid][szDescription], "Title Credits", g_sCreditsName, g_iCredits[target]);
	}

	int iExpiration = GetExpiration(target, itemid);
	if (iExpiration != 0)
	{
		iExpiration = iExpiration - GetTime();
		int iDays = iExpiration / (24 * 60 * 60);
		int iHours = (iExpiration - iDays * 24 * 60 * 60)/(60 * 60);
		Format(sTitle[iIndex - 1], sizeof(sTitle) - iIndex - 1, "\n%t", "Title Expiration", iDays, iHours);
	}

	menu.SetTitle(sTitle);

	if (g_aTypeHandlers[g_aItems[itemid][iHandler]][bEquipable])
	{
		if (!bEquipped)
		{
			Format(sTitle, sizeof(sTitle), "%t", "Item Equip");
			menu.AddItem("0", sTitle, ITEMDRAW_DEFAULT);
		}
		else
		{
			Format(sTitle, sizeof(sTitle), "%t", "Item Unequip");
			menu.AddItem("3", sTitle, ITEMDRAW_DEFAULT);
		}
	}
	else
	{
		Format(sTitle, sizeof(sTitle), "%t", "Item Use");
		menu.AddItem("0", sTitle, ITEMDRAW_DEFAULT);
	}

	if (g_aItems[itemid][bPreview])
	{
		Format(sTitle, sizeof(sTitle), "%t", "Preview Item");
		menu.AddItem("4", sTitle, ITEMDRAW_DEFAULT);
	}

	for (int i = 0; i < g_iItemHandlers; i++)
	{
		if (g_hItemPlugin[i] == null)
			continue;

		Call_StartFunction(g_hItemPlugin[i], g_fnItemMenu[i]);
		Call_PushCellRef(menu);
		Call_PushCell(client);
		Call_PushCell(itemid);
		Call_Finish();
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

public void DisplayPreviewMenu(int client, int itemid)
{
	if (!gc_bEnable.BoolValue)
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Store Disabled");
		return;
	}

	g_iMenuNum[client] = 1;
	int target = g_iMenuClient[client];

	Menu menu = new Menu(MenuHandler_Preview);
	menu.ExitBackButton = true;

	menu.SetTitle("%s\n%s\n%t", g_aItems[itemid][szName], g_aItems[itemid][szDescription], "Title Credits", g_sCreditsName, g_iCredits[target]);

	char sBuffer[128];
	bool reduced = false;
	int price = Forward_OnGetEndPrice(client, itemid, g_aItems[itemid][iPrice], reduced);

	if (MyStore_HasClientItem(client, itemid))
	{
		if (g_aTypeHandlers[g_aItems[itemid][iHandler]][bEquipable])
		{
			if (!IsEquipped(client, itemid))
			{
				Format(sBuffer, sizeof(sBuffer), "%t", "Item Equip");
				menu.AddItem("item_use", sBuffer, ITEMDRAW_DEFAULT);
			}
			else
			{
				Format(sBuffer, sizeof(sBuffer), "%t", "Item Unequip");
				menu.AddItem("item_unequipped", sBuffer, ITEMDRAW_DEFAULT);
			}
		}
		else
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "Item Use");
			menu.AddItem("item_use", sBuffer, ITEMDRAW_DEFAULT);
		}
	}
	// Player don't own the item
	else if (!g_bInvMode[client] && g_aItems[itemid][bBuyable])
	{
		int iStyle = ITEMDRAW_DEFAULT;
		if ((g_aItems[itemid][iPlans] == 0 && g_iCredits[target] < price) || (gc_bShowVIP.BoolValue && !CheckFlagBits(target, g_aItems[itemid][iFlagBits]) && !CheckSteamAuth(target, g_aItems[itemid][szSteam])))
		{
			iStyle = ITEMDRAW_DISABLED;
		}

		// Player can buy the item as normal trade in
		if (g_aItems[itemid][iPlans] == 0)
		{
			Format(sBuffer, sizeof(sBuffer), "%t %t", "Buy Item", price, reduced ? "discount" : "nodiscount");
			menu.AddItem("buy_item", sBuffer, g_iCredits[target] >= price ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
		// Player can buy the item in a plan
		else
		{
			Format(sBuffer, sizeof(sBuffer), "%t %t", "Choose Plan", g_aItems[itemid][szName], reduced ? "discount" : "nodiscount");
			menu.AddItem("item_plan", sBuffer, iStyle);
		}
	}

	
	Format(sBuffer, sizeof(sBuffer), "%t", "Preview Item");
	menu.AddItem("preview_item", sBuffer, ITEMDRAW_DEFAULT);

	for (int i = 0; i < g_iItemHandlers; i++)
	{
		if (g_hItemPlugin[i] == null)
			continue;

		Call_StartFunction(g_hItemPlugin[i], g_fnItemMenu[i]);
		Call_PushCellRef(menu);
		Call_PushCell(client);
		Call_PushCell(itemid);
		Call_Finish();
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Preview(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_End)
	{
		menu.Cancel();
	}
	else if (action == MenuAction_Select)
	{
		char sId[24];
		menu.GetItem(param2, sId, sizeof(sId));
		int itemid = g_iSelectedItem[client];

		if (strcmp(sId, "buy_item") == 0)
		{
			if (gc_bConfirm.BoolValue)
			{
				char sTitle[128];
				Format(sTitle, sizeof(sTitle), "%t", "Confirm_Buy", g_aItems[itemid][szName], g_aTypeHandlers[g_aItems[itemid][iHandler]][szType]);
				MyStore_DisplayConfirmMenu(client, sTitle, MenuHandler_Store, 0);
				return;
			}
			else
			{
				BuyItem(client, itemid);
				DisplayPreviewMenu(client, itemid);
			}

			if (g_aTypeHandlers[g_aItems[itemid][iHandler]][bRaw])
			{
				Call_StartFunction(g_aTypeHandlers[g_aItems[itemid][iHandler]][hPlugin], g_aTypeHandlers[g_aItems[itemid][iHandler]][fnUse]);
				Call_PushCell(client);
				Call_PushCell(itemid);
				Call_Finish();
				return;
			}
		}
		else if (strcmp(sId, "item_plan") == 0)
		{
			DisplayPlanMenu(client, itemid);
		}
		else if (strcmp(sId, "item_use") == 0)
		{
			bool bRet = UseItem(client, g_iSelectedItem[client]);
			if (GetClientMenu(client) == MenuSource_None && bRet)
			{
				if (g_aTypeHandlers[g_aItems[itemid][iHandler]][bEquipable])
				{
					if (g_aItems[g_iSelectedItem[client]][bPreview])
					{
						DisplayPreviewMenu(client, g_iSelectedItem[client]);
					}
					else
					{
						DisplayItemMenu(client, g_iSelectedItem[client]);
					}
				}
			}
		}
		else if (strcmp(sId, "item_unequipped") == 0)
		{
			UnequipItem(client, itemid);
			if (g_aItems[g_iSelectedItem[client]][bPreview])
			{
				DisplayPreviewMenu(client, g_iSelectedItem[client]);
			}
			else
			{
				DisplayItemMenu(client, g_iSelectedItem[client]);
			}
		}
		else if (strcmp(sId, "preview_item") == 0)
		{
			if (g_iSpam[client] > GetTime())
			{
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Spam Cooldown", g_iSpam[client] - GetTime());
				DisplayPreviewMenu(client, itemid);
				return;
			}

			if (!IsPlayerAlive(client))
			{
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Must be Alive");
				DisplayPreviewMenu(client, itemid);
				return;
			}

			Call_StartForward(gf_hPreviewItem);
			Call_PushCell(client);
			Call_PushString(g_aTypeHandlers[g_aItems[itemid][iHandler]][szType]);
			Call_PushCell(g_aItems[itemid][iDataIndex]);
			Call_Finish();
			g_iSpam[client] = GetTime() + 10;

			DisplayPreviewMenu(client, itemid);
		}
		else if (!(48 <= sId[0] <= 57))
		{
			bool ret;
			for (int i = 0; i < g_iItemHandlers; i++)
			{
				Call_StartFunction(g_hItemPlugin[i], g_fnItemHandler[i]);
				Call_PushCell(client);
				Call_PushString(sId);
				Call_PushCell(g_iSelectedItem[client]);
				Call_Finish(ret);

				if (ret)
					break;
			}
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack)
		{
			MyStore_DisplayPreviousMenu(client);
		}
	}
}

public void DisplayPlanMenu(int client, int itemid)
{
	if (!gc_bEnable.BoolValue)
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Store Disabled");
		return;
	}

	g_iMenuNum[client] = 1;
	int target = g_iMenuClient[client];

	Menu menu = new Menu(MenuHandler_Plan);
	menu.ExitBackButton = true;

	menu.SetTitle("%s\n%s\n%t", g_aItems[itemid][szName], g_aItems[itemid][szDescription], "Title Credits", g_sCreditsName, g_iCredits[target]);

	char sBuffer[64];
	if (g_aItems[itemid][bPreview])
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Preview Item");
		menu.AddItem("preview", sBuffer, ITEMDRAW_DEFAULT);
	}

	for (int i = 0; i < g_aItems[itemid][iPlans]; i++)
	{
		bool reduced = false;
		int price = Forward_OnGetEndPrice(client, itemid, g_iPlanPrice[itemid][i], reduced);
		Format(sBuffer, sizeof(sBuffer), "%t %t", "Item Available", g_sPlanName[itemid][i], price, reduced ? "discount" : "nodiscount");
		menu.AddItem("", sBuffer, g_iCredits[target] >= price ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Plan(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_End)
	{
		menu.Cancel();
	}
	else if (action == MenuAction_Select)
	{
		int target = g_iMenuClient[client];
		g_iMenuNum[client] = 5;

		char sId[24];
		menu.GetItem(param2, sId, sizeof(sId));
		int itemid = g_iSelectedItem[client];

		if (strcmp(sId, "preview") == 0)
		{
			if (g_iSpam[client] < GetTime())
			{
				Call_StartForward(gf_hPreviewItem);
				Call_PushCell(client);
				Call_PushString(g_aTypeHandlers[g_aItems[itemid][iHandler]][szType]);
				Call_PushCell(g_aItems[itemid][iDataIndex]);
				Call_Finish();
				g_iSpam[client] = GetTime() + 10;
			}
			else
			{
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Spam Cooldown", g_iSpam[client] - GetTime());
			}

			DisplayPlanMenu(client, itemid);
			return;
		}

		g_iSelectedPlan[client] = param2;

		if (g_aItems[g_iSelectedItem[client]][bPreview])
		{
			g_iSelectedPlan[client]--;
		}

		if (gc_bConfirm.BoolValue)
		{
			char sTitle[128];
			Format(sTitle, sizeof(sTitle), "%t", "Confirm_Buy", g_aItems[g_iSelectedItem[client]][szName], g_aTypeHandlers[g_aItems[g_iSelectedItem[client]][iHandler]][szType]);
			MyStore_DisplayConfirmMenu(client, sTitle, MenuHandler_Store, 0);
		}
		else
		{
			BuyItem(target, g_iSelectedItem[client], g_iSelectedPlan[client]);
			DisplayItemMenu(client, g_iSelectedItem[client]);
		}
		
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack)
		{
			MyStore_DisplayPreviousMenu(client);
		}
	}
}

public int MenuHandler_Item(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_End)
	{
		menu.Cancel();
	}
	else if (action == MenuAction_Select)
	{
		int target = g_iMenuClient[client];

		char sId[64];
		menu.GetItem(param2, sId, sizeof(sId));

		int iIndex = StringToInt(sId);

		// Menu handlers
		if (!(48 <= sId[0] <= 57))
		{
			bool ret;
			for (int i = 0; i < g_iItemHandlers; i++)
			{
				if (g_hItemPlugin[i] == null)
					continue;

				Call_StartFunction(g_hItemPlugin[i], g_fnItemHandler[i]);
				Call_PushCell(client);
				Call_PushString(sId);
				Call_PushCell(g_iSelectedItem[client]);
				Call_Finish(ret);

				if (ret)
					return;
			}
		}

		// Player wants to equip this item
		switch(iIndex)
		{
			case 0:
			{
				bool bRet = UseItem(target, g_iSelectedItem[client]);
				if (GetClientMenu(client) == MenuSource_None && bRet)
				{
					if (g_aTypeHandlers[g_aItems[g_iSelectedItem[client]][iHandler]][bEquipable])
					{
						if (g_aItems[g_iSelectedItem[client]][bPreview])
						{
							DisplayPreviewMenu(client, g_iSelectedItem[client]);
						}
						else
						{
							DisplayItemMenu(client, g_iSelectedItem[client]);
						}
					}
				}
			}
		// Player wants to unequip this item
			case 3:
			{
				UnequipItem(target, g_iSelectedItem[client]);
				if (g_aItems[g_iSelectedItem[client]][bPreview])
				{
					DisplayPreviewMenu(client, g_iSelectedItem[client]);
				}
				else
				{
					DisplayItemMenu(client, g_iSelectedItem[client]);
				}
			}
		// Player wants to preview
			case 4:
			{
				if (g_iSpam[client] < GetTime())
				{
					Call_StartForward(gf_hPreviewItem);
					Call_PushCell(client);
					Call_PushString(g_aTypeHandlers[g_aItems[g_iSelectedItem[client]][iHandler]][szType]);
					Call_PushCell(g_aItems[g_iSelectedItem[client]][iDataIndex]);
					Call_Finish();
					g_iSpam[client] = GetTime() + 10;
				}
				else
				{
					CPrintToChat(client, "%s%t", g_sChatPrefix, "Spam Cooldown", g_iSpam[client] - GetTime());
				}

				DisplayItemMenu(client, g_iSelectedItem[client]);
			}
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack)
		{
			MyStore_DisplayPreviousMenu(client);
		}
	}
}

public int MenuHandler_Confirm(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_End)
	{
		menu.Cancel();
	}
	else if (action == MenuAction_Select)
	{
		if (param2 == 0)
		{
			char sCallback[32];
			char sData[11];
			GetMenuItem(menu, 0, sCallback, sizeof(sCallback));
			GetMenuItem(menu, 1, sData, sizeof(sData));

			DataPack pack = view_as<DataPack>(StringToInt(sCallback));
			Handle m_hPlugin = view_as<Handle>(pack.ReadCell());
			Function fnMenuCallback = pack.ReadCell();
			delete pack;

			if (fnMenuCallback != INVALID_FUNCTION)
			{
				Call_StartFunction(m_hPlugin, fnMenuCallback);
				Call_PushCell(INVALID_HANDLE);
				Call_PushCell(MenuAction_Select);
				Call_PushCell(client);
				Call_PushCell(StringToInt(sData));
				Call_Finish();
			}
			else
			{
				MyStore_DisplayPreviousMenu(client);
			}
		}
		else
		{
			MyStore_DisplayPreviousMenu(client);
		}
	}
}

/******************************************************************************
                   Timer
******************************************************************************/

public Action Timer_LoadConfig(Handle timer)
{
	ReloadConfig();
}

public Action Timer_DatabaseTimeout(Handle timer, int userid)
{
	// Database is connected successfully
	if (g_hDatabase != null)
		return Plugin_Stop;

	if (g_iDatabaseRetries < gc_iDBRetries.IntValue)
	{
		Database.Connect(SQLCallback_Connect, "mystore");
		CreateTimer(gc_iDBTimeout.FloatValue, Timer_DatabaseTimeout);
		g_iDatabaseRetries++;
	}
	else
	{
		SetFailState("Database connection failed to initialize after %i retrie(s)", gc_iDBRetries.IntValue);
	}

	CreateTimer(0.1, Timer_LoadConfig);

	return Plugin_Stop;
}

/******************************************************************************
                   SQL
******************************************************************************/

void SQL_LoadClientInventory(int client)
{
	if (g_hDatabase == null)
	{
		MyLogMessage(client, LOG_ERROR, "SQL_LoadClientInventory: Database connection is lost or not yet initialized");
		return;
	}

	char sQuery[256];
	char sAuthId[32];

	GetLegacyAuthString(client, sAuthId, sizeof(sAuthId));
	if (sAuthId[0] == 0)
		return;

	Format(sQuery, sizeof(sQuery), "SELECT * FROM mystore_players WHERE `authid` = \"%s\"", sAuthId[8]);

	g_hDatabase.Query(SQLCallback_LoadClientInventory_Credits, sQuery, GetClientUserId(client));
}

void SQL_SaveClientInventory(int client)
{
	if (g_hDatabase == null)
	{
		MyLogMessage(client, LOG_ERROR, "SQL_SaveClientInventory: Database connection is lost or not yet initialized");
		return;
	}

	// Player disconnected before his inventory was even fetched
	if (g_iCredits[client] == -1 && g_iItems[client] == -1)
		return;

	char sQuery[256];
	char sType[16];
	char sUniqueId[PLATFORM_MAX_PATH];

	for (int i = 0; i < g_iItems[client]; i++) //transaction todo
	{
		strcopy(sType, sizeof(sType), g_aTypeHandlers[g_aItems[g_iPlayerItems[client][i][UNIQUE_ID]][iHandler]][szType]);
		strcopy(sUniqueId, sizeof(sUniqueId), g_aItems[g_iPlayerItems[client][i][UNIQUE_ID]][szUniqueId]);

		if (g_iPlayerItems[client][i][SYNCED] == 0 && g_iPlayerItems[client][i][DELETED] == 0)
		{
			g_iPlayerItems[client][i][SYNCED] = 1;
			Format(sQuery, sizeof(sQuery), "INSERT INTO mystore_items (`player_id`, `type`, `unique_id`, `date_of_purchase`, `date_of_expiration`, `price_of_purchase`) VALUES (%i, \"%s\", \"%s\", %i, %i, %i)", g_iPlayerID[client], sType, sUniqueId, g_iPlayerItems[client][i][DATE_PURCHASE], g_iPlayerItems[client][i][DATE_EXPIRATION], g_iPlayerItems[client][i][PRICE_PURCHASE]);
			g_hDatabase.Query(SQLCallback_Void_Error, sQuery);
		}
		else if (g_iPlayerItems[client][i][SYNCED] == 1 && g_iPlayerItems[client][i][DELETED] == 1)
		{
			Format(sQuery, sizeof(sQuery), "DELETE FROM mystore_items WHERE `player_id` = %i AND `type` = \"%s\" AND `unique_id` = \"%s\"", g_iPlayerID[client], sType, sUniqueId);

			g_hDatabase.Query(SQLCallback_Void_Error, sQuery);
		}
	}
}

void SQL_SaveClientEquipment(int client) //tnx
{
	char sQuery[256];
	int iIndex;

	float time = GetEngineTime();
	Transaction tnx = new Transaction();

	for (int i = 0; i < STORE_MAX_TYPES; i++)
	{
		for (int a = 0; a < STORE_MAX_SLOTS; a++)
		{
			iIndex = i * STORE_MAX_SLOTS + a;
			if (g_iEquipmentSynced[client][iIndex] == g_iEquipment[client][iIndex])
				continue;

			if (g_iEquipmentSynced[client][iIndex] != -2)
			{
				if (g_iEquipment[client][iIndex] == -1)
				{
					Format(sQuery, sizeof(sQuery), "DELETE FROM mystore_equipment WHERE `player_id` = %i AND `type` = \"%s\" AND `slot` = %i", g_iPlayerID[client], g_aTypeHandlers[i][szType], a);
				}
				else
				{
					Format(sQuery, sizeof(sQuery), "UPDATE mystore_equipment SET `unique_id` = \"%s\" WHERE `player_id` = %i AND `type` = \"%s\" AND `slot` = %i", g_aItems[g_iEquipment[client][iIndex]][szUniqueId], g_iPlayerID[client], g_aTypeHandlers[i][szType], a);
				}
			}
			else
			{
				Format(sQuery, sizeof(sQuery), "INSERT INTO mystore_equipment (`player_id`, `type`, `unique_id`, `slot`) VALUES(%i, \"%s\", \"%s\", %i)", g_iPlayerID[client], g_aTypeHandlers[i][szType], g_aItems[g_iEquipment[client][iIndex]][szUniqueId], a);
			}

			tnx.AddQuery(sQuery);
			g_iEquipmentSynced[client][iIndex] = g_iEquipment[client][iIndex];
		}
	}

	g_hDatabase.Execute(tnx, SQLTXNCallback_Success, SQLTXNCallback_Error, time);
}

void SQL_SaveClientData(int client)
{
	if (g_hDatabase == null)
	{
		MyLogMessage(client, LOG_ERROR, "SQL_SaveClientData: Database connection is lost or not yet initialized ");
		return;
	}

	if ((g_iCredits[client] == -1 && g_iItems[client] == -1) || !g_bLoaded[client])
		return;

	char sName[32];
	GetClientName(client, sName, 32);
	g_hDatabase.Escape(sName, sName, 32);

	char sQuery[256];
	Format(sQuery, sizeof(sQuery), "UPDATE mystore_players SET `credits` = %i, `date_of_last_join` = %i, `name` = '%s' WHERE `id` = %i", g_iCredits[client], g_bLastJoin[client], sName, g_iPlayerID[client]);

	g_hDatabase.Query(SQLCallback_Void_Error, sQuery);
}

public void SQLCallback_Connect(Database db, const char[] error, any data)
{
	if (db == null)
	{
		SetFailState("Failed to connect to SQL database. Error: %s", error);
	}
	else
	{
		// If it's already connected we are good to go
		if (g_hDatabase != null)
			return;

		g_hDatabase = db;

		char sBuffer[2];
		DBDriver iDriver = db.Driver;
		iDriver.GetIdentifier(sBuffer, sizeof(sBuffer));

		float time = GetEngineTime();
		Transaction tnx = new Transaction();

		if (sBuffer[0] == 'm')
		{
			g_bMySQL = true;

			tnx.AddQuery("CREATE TABLE IF NOT EXISTS `mystore_players` (\
						 `id` int(11) NOT NULL AUTO_INCREMENT,\
						 `authid` varchar(32) NOT NULL,\
						 `name` varchar(64) NOT NULL,\
						 `credits` int(11) NOT NULL,\
						 `date_of_join` int(11) NOT NULL,\
						 `date_of_last_join` int(11) NOT NULL,\
						 PRIMARY KEY (`id`),\
						 UNIQUE KEY `id` (`id`),\
						 UNIQUE KEY `authid` (`authid`)\
						)");

			tnx.AddQuery("CREATE TABLE IF NOT EXISTS `mystore_items` (\
						 `player_id` int(11) NOT NULL,\
						 `type` varchar(16) NOT NULL,\
						 `unique_id` varchar(256) NOT NULL,\
						 `date_of_purchase` int(11) NOT NULL,\
						 `date_of_expiration` int(11) NOT NULL,\
						 `price_of_purchase` int(11) NOT NULL\
						)");

			tnx.AddQuery("CREATE TABLE IF NOT EXISTS `mystore_equipment` (\
						 `player_id` int(11) NOT NULL,\
						 `type` varchar(16) NOT NULL,\
						 `unique_id` varchar(256) NOT NULL,\
						 `slot` int(11) NOT NULL\
						)");

			tnx.AddQuery("CREATE TABLE IF NOT EXISTS `mystore_logs` (\
						 `date` int(11) NOT NULL,\
						 `level` varchar(8) NOT NULL,\
						 `player_id` int(11) NOT NULL,\
						 `reason` varchar(256) NOT NULL\
						)");
		}
		else
		{
			tnx.AddQuery("CREATE TABLE IF NOT EXISTS `mystore_players` (\
						 `id` INTEGER PRIMARY KEY AUTOINCREMENT,\
						 `authid` varchar(32) NOT NULL,\
						 `name` varchar(64) NOT NULL,\
						 `credits` int(11) NOT NULL,\
						 `date_of_join` int(11) NOT NULL,\
						 `date_of_last_join` int(11) NOT NULL\
						)");

			tnx.AddQuery("CREATE TABLE IF NOT EXISTS `mystore_items` (\
						 `player_id` int(11) NOT NULL,\
						 `type` varchar(16) NOT NULL,\
						 `unique_id` varchar(256) NOT NULL,\
						 `date_of_purchase` int(11) NOT NULL,\
						 `date_of_expiration` int(11) NOT NULL,\
						 `price_of_purchase` int(11) NOT NULL\
						)");

			tnx.AddQuery("CREATE TABLE IF NOT EXISTS `mystore_equipment` (\
						 `player_id` int(11) NOT NULL,\
						 `type` varchar(16) NOT NULL,\
						 `unique_id` varchar(256) NOT NULL,\
						 `slot` int(11) NOT NULL\
						)");
		}

		char sQuery[256];
		Format(sQuery, sizeof(sQuery), "DELETE FROM mystore_items WHERE `date_of_expiration` <> 0 AND `date_of_expiration` < %i", GetTime());
		tnx.AddQuery(sQuery);

		g_hDatabase.Execute(tnx, SQLTXNCallback_Success, SQLTXNCallback_Error, time);

		CreateTimer(0.1, Timer_LoadConfig);
	}
}

public void SQLCallback_LoadClientInventory_Credits(Database db, DBResultSet results, const char[] error, int userid)
{
	if (results == null)
	{
		int client = GetClientOfUserId(userid);
		MyLogMessage(client, LOG_ERROR, "SQLCallback_LoadClientInventory_Credits: Error: %s", error);
	}
	else
	{
		int client = GetClientOfUserId(userid);
		if (!client)
			return;

		char sQuery[256];
		char sSteamID[32];
		char sName[32];
		int itime = GetTime();

		g_iItems[client] = -1;

		GetLegacyAuthString(client, sSteamID, sizeof(sSteamID), false);

		GetClientName(client, sName, 32);
		g_hDatabase.Escape(sName, sName, 32);

		if (results.FetchRow())
		{
			g_iPlayerID[client] = results.FetchInt(0);
			g_iCredits[client] = results.FetchInt(3);
			g_bLastJoin[client] = itime;

			Format(sQuery, sizeof(sQuery), "SELECT * FROM mystore_items WHERE `player_id` = %i", g_iPlayerID[client]);
			g_hDatabase.Query(SQLCallback_LoadClientInventory_Items, sQuery, userid);

			MyLogMessage(client, LOG_EVENT, "Joined game with %i credits", g_iCredits[client]);

			SQL_SaveClientData(client);
		}
		else
		{
			Format(sQuery, sizeof(sQuery), "INSERT INTO mystore_players (`authid`, `name`, `credits`, `date_of_join`, `date_of_last_join`) VALUES(\"%s\", '%s', %i, %i, %i)",
						sSteamID[8], sName, gc_iCreditsStart.IntValue, itime, itime);
			g_hDatabase.Query(SQLCallback_InsertClient, sQuery, userid);

			g_iCredits[client] = gc_iCreditsStart.IntValue;
			g_bLastJoin[client] = itime;
			g_bLoaded[client] = true;
			g_iItems[client] = 0;

			if (gc_iCreditsStart.IntValue > 0)
			{
				MyLogMessage(client, LOG_EVENT, "Recieved %i start credits", gc_iCreditsStart.IntValue);
			}
		}
	}
}

public void SQLCallback_LoadClientInventory_Items(Database db, DBResultSet results, const char[] error, int userid)
{
	if (results == null)
	{
		int client = GetClientOfUserId(userid);
		MyLogMessage(client, LOG_ERROR, "SQLCallback_LoadClientInventory_Items: Error: %s", error);
	}
	else
	{
		int client = GetClientOfUserId(userid);
		if (!client)
			return;

		char sQuery[256];
		Format(sQuery, sizeof(sQuery), "SELECT * FROM mystore_equipment WHERE `player_id` = %i", g_iPlayerID[client]);
		g_hDatabase.Query(SQLCallback_LoadClientInventory_Equipment, sQuery, userid);

		if (!results.RowCount)
		{
			g_bLoaded[client] = true;
			g_iItems[client] = 0;
			return;
		}

		char sUniqueId[PLATFORM_MAX_PATH];
		char sType[16];
		int iExpiration;
		int iUniqueID;
		int itime = GetTime();

		int i = 0;
		while (results.FetchRow())
		{
			iUniqueID = -1;
			iExpiration = results.FetchInt(4);
			if (iExpiration && iExpiration <= itime)
				continue;

			results.FetchString(1, sType, sizeof(sType));
			results.FetchString(2, sUniqueId, sizeof(sUniqueId));
			while ((iUniqueID = GetItemId(sType, sUniqueId, iUniqueID)) != -1)
			{
				g_iPlayerItems[client][i][UNIQUE_ID] = iUniqueID;
				g_iPlayerItems[client][i][SYNCED] = 1;
				g_iPlayerItems[client][i][DELETED] = 0;
				g_iPlayerItems[client][i][DATE_PURCHASE] = results.FetchInt(3);
				g_iPlayerItems[client][i][DATE_EXPIRATION] = iExpiration;
				g_iPlayerItems[client][i][PRICE_PURCHASE] = results.FetchInt(5);

				i++;
			}
		}

		g_iItems[client] = i;
	}
}

public void SQLCallback_LoadClientInventory_Equipment(Database db, DBResultSet results, const char[] error, int userid)
{
	if (results == null)
	{
		int client = GetClientOfUserId(userid);
		MyLogMessage(client, LOG_ERROR, "SQLCallback_LoadClientInventory_Equipment: Error: %s", error);
	}
	else
	{
		int client = GetClientOfUserId(userid);
		if (!client)
			return;

		char sUniqueId[PLATFORM_MAX_PATH];
		char sType[16];
		int iUniqueID;

		while (results.FetchRow())
		{
			results.FetchString(1, sType, sizeof(sType));
			results.FetchString(2, sUniqueId, sizeof(sUniqueId));
			iUniqueID = GetItemId(sType, sUniqueId);
			if (iUniqueID == -1)
				continue;

			if (!MyStore_HasClientItem(client, iUniqueID))
			{
				UnequipItem(client, iUniqueID);
			}
			else
			{
				UseItem(client, iUniqueID, true, results.FetchInt(3));
			}
		}

		g_bLoaded[client] = true;
	}
}

public void SQLCallback_InsertClient(Database db, DBResultSet results, const char[] error, int userid)
{
	if (results == null)
	{
		int client = GetClientOfUserId(userid);
		MyLogMessage(client, LOG_ERROR, "SQLCallback_InsertClient: Error: %s", error);
	}
	else
	{
		int client = GetClientOfUserId(userid);
		if (!client)
			return;

		g_iPlayerID[client] = results.InsertId;
	}
}

public void SQLCallback_ResetPlayer(Database db, DBResultSet results, const char[] error, int userid)
{
	if (results == null)
	{
		int client = GetClientOfUserId(userid);
		MyLogMessage(client, LOG_ERROR, "SQLCallback_ResetPlayer: Error: %s", error);
	}
	else
	{
		int client = GetClientOfUserId(userid);

		if (results.RowCount)
		{
			results.FetchRow();
			int id = results.FetchInt(0);
			char sAuthId[32];
			results.FetchString(1, sAuthId, sizeof(sAuthId));

			float time = GetEngineTime();
			Transaction tnx = new Transaction();

			char sQuery[512];
			Format(sQuery, sizeof(sQuery), "DELETE FROM mystore_players WHERE id = %i", id);
			tnx.AddQuery(sQuery);

			Format(sQuery, sizeof(sQuery), "DELETE FROM mystore_items WHERE player_id = %i", id);
			tnx.AddQuery(sQuery);

			Format(sQuery, sizeof(sQuery), "DELETE FROM mystore_equipment WHERE player_id = %i", id);
			tnx.AddQuery(sQuery);

			g_hDatabase.Execute(tnx, SQLTXNCallback_Success, SQLTXNCallback_Error, time);

			CPrintToChatAll("%s%t", g_sChatPrefix, "Player Resetted", sAuthId);
		}
		else
		{
			if (client)
			{
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Credit No Match");
			}
		}
	}
}

public void SQLCallback_Void_Error(Database db, DBResultSet results, const char[] error, any data)
{
	if (db == null)
	{
		MyLogMessage(0, LOG_ERROR, "SQLCallback_Void_Error: %s", error);
	}
}

public void SQLTXNCallback_Success(Database db, float time, int numQueries, Handle[] results, any[] queryData)
{
	float querytime = GetEngineTime() - time;
	PrintToServer("MyStore - Transaction Complete - Querys: %i in %0.2f seconds", numQueries, querytime);
}

public void SQLTXNCallback_Error(Database db, float time, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	float querytime = GetEngineTime() - time;
	MyLogMessage(0, LOG_ERROR, "SQLTXNCallback_Error: %s - Querys: %i - FailedIndex: %i after %0.2f seconds", error, numQueries, failIndex, querytime);
}

/******************************************************************************
                   Natives
******************************************************************************/

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("mystore");

	CreateNative("MyStore_RegisterHandler", Native_RegisterHandler);
	CreateNative("MyStore_RegisterItemHandler", Native_RegisterItemHandler);
	CreateNative("MyStore_SetDataIndex", Native_SetDataIndex);
	CreateNative("MyStore_GetDataIndex", Native_GetDataIndex);
	CreateNative("MyStore_GetEquippedItem", Native_GetEquippedItem);
	CreateNative("MyStore_IsClientLoaded", Native_IsClientLoaded);
	CreateNative("MyStore_DisplayItemMenu", Native_DisplayItemMenu);
	CreateNative("MyStore_DisplayPreviousMenu", Native_DisplayPreviousMenu);
	CreateNative("MyStore_SetClientPreviousMenu", Native_SetClientMenu);
	CreateNative("MyStore_GetClientCredits", Native_GetClientCredits);
	CreateNative("MyStore_SetClientCredits", Native_SetClientCredits);
	CreateNative("MyStore_IsClientVIP", Native_IsClientVIP);
	CreateNative("MyStore_IsClientAdmin", Native_IsClientAdmin);
	CreateNative("MyStore_HasClientAccess", Native_HasClientAccess);
	CreateNative("MyStore_IsItemInBoughtPackage", Native_IsItemInBoughtPackage);
	CreateNative("MyStore_DisplayConfirmMenu", Native_DisplayConfirmMenu);
	CreateNative("MyStore_ShouldConfirm", Native_ShouldConfirm);
	CreateNative("MyStore_IsInRecurringMenu", Native_IsInRecurringMenu);
	CreateNative("MyStore_SetClientRecurringMenu", Native_SetClientRecurringMenu);
	CreateNative("MyStore_GetItem", Native_GetItem);
	CreateNative("MyStore_GetHandler", Native_GetHandler);
	CreateNative("MyStore_GiveItem", Native_GiveItem);
	CreateNative("MyStore_RemoveItem", Native_RemoveItem);
	CreateNative("MyStore_EquipItem", Native_EquipItem);
	CreateNative("MyStore_UnequipItem", Native_UnequipItem);
	CreateNative("MyStore_GetClientItem", Native_GetClientItem);
	CreateNative("MyStore_GetItemIdbyUniqueId", Native_GetItemIdbyUniqueId);
	CreateNative("MyStore_GetClientTarget", Native_GetClientTarget);
	CreateNative("MyStore_SellClientItem", Native_SellClientItem);
	CreateNative("MyStore_TransferClientItem", Native_TransferClientItem);
	CreateNative("MyStore_HasClientItem", Native_HasClientItem);
	CreateNative("MyStore_IterateEquippedItems", Native_IterateEquippedItems);
	CreateNative("MyStore_SQLEscape", Native_SQLEscape);
	CreateNative("MyStore_SQLQuery", Native_SQLQuery);
	CreateNative("MyStore_SQLTransaction", Native_SQLTransaction);
	CreateNative("MyStore_LogMessage", Native_LogMessage);

	gf_hOnGetEndPrice = CreateGlobalForward("MyStore_OnGetEndPrice", ET_Event, Param_Cell, Param_Cell, Param_CellByRef, Param_CellByRef);
	gf_hOnConfigExecuted = CreateGlobalForward("MyStore_OnConfigExecuted", ET_Ignore, Param_Cell, Param_String, Param_String, Param_String);
	gf_hOnItemEquipt = CreateGlobalForward("MyStore_OnItemEquipt", ET_Ignore, Param_Cell, Param_Cell);
	gf_hPreviewItem = CreateGlobalForward("MyStore_OnPreviewItem", ET_Ignore, Param_Cell, Param_String, Param_Cell);
	gf_hOnBuyItem = CreateGlobalForward("MyStore_OnBuyItem", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_CellByRef);

	return APLRes_Success;
}

public int Native_RegisterHandler(Handle plugin, int numParams)
{
	if (g_iTypeHandlers == STORE_MAX_TYPES)
		return -1;

	char sType[32];
	GetNativeString(1, sType, sizeof(sType));
	int iHandle = GetTypeHandler(sType);
	int iIndex = g_iTypeHandlers;

	if (iHandle != -1)
	{
		iIndex = iHandle;
	}
	else
	{
		g_iTypeHandlers++;
	}

	g_aTypeHandlers[iIndex][hPlugin] = plugin;
	g_aTypeHandlers[iIndex][fnMapStart] = GetNativeCell(2);
	g_aTypeHandlers[iIndex][fnReset] = GetNativeCell(3);
	g_aTypeHandlers[iIndex][fnConfig] = GetNativeCell(4);
	g_aTypeHandlers[iIndex][fnUse] = GetNativeCell(5);
	g_aTypeHandlers[iIndex][fnRemove] = GetNativeCell(6);
	g_aTypeHandlers[iIndex][bEquipable] = GetNativeCell(7);
	g_aTypeHandlers[iIndex][bRaw] = GetNativeCell(8);
	strcopy(g_aTypeHandlers[iIndex][szType], 32, sType);

	return iIndex;
}

public int Native_SQLTransaction(Handle plugin, int numParams)
{
	if (g_hDatabase == null)
		return -1;

	Transaction tnx = GetNativeCell(1);
	DataPack pack = new DataPack();
	pack.WriteCell(plugin);
	pack.WriteFunction(GetNativeFunction(2));
	pack.WriteCell(GetNativeCell(3));

	g_hDatabase.Execute(tnx, Natives_SQLTXNCallback_Success, Natives_SQLTXNCallback_Error, pack);

	return 1;
}

public void Natives_SQLTXNCallback_Success(Database db, DataPack pack, int numQueries, Handle[] results, any[] queryData)
{
	PrintToServer("MyStore - Native Transaction Complete - Querys: %i", numQueries);

	pack.Reset();
	Handle plugin = pack.ReadCell();
	Function callback = pack.ReadFunction();
	any data = pack.ReadCell();
	delete pack;

	Call_StartFunction(plugin, callback);
	Call_PushCell(db);
	Call_PushCell(data);
	Call_PushCell(numQueries);
	Call_PushArray(results, numQueries);
	Call_PushArray(queryData, numQueries);
	Call_Finish();
}

public void Natives_SQLTXNCallback_Error(Database db, DataPack pack, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	pack.Reset();
	Handle plugin = pack.ReadCell();
	delete pack;

	char sBuffer[64];
	GetPluginFilename(plugin, sBuffer, sizeof(sBuffer));

	MyLogMessage(0, LOG_ERROR, "Natives_SQLTXNCallback_Error: %s - Plugin: %s Querys: %i - FailedIndex: %i", error, sBuffer, numQueries, failIndex);
}

public int Native_SQLEscape(Handle plugin, int numParams)
{
	if (g_hDatabase == null)
		return -1;

	char sBuffer[512];
	GetNativeString(1, sBuffer, sizeof(sBuffer));

	g_hDatabase.Escape(sBuffer, sBuffer, sizeof(sBuffer));

	SetNativeString(1, sBuffer, sizeof(sBuffer));

	return 1;
}

public int Native_SQLQuery(Handle plugin, int numParams)
{
	if (g_hDatabase == null)
		return -1;

	char sQuery[512];
	GetNativeString(1, sQuery, sizeof(sQuery));
	DataPack pack = new DataPack();
	pack.WriteCell(plugin);
	pack.WriteFunction(GetNativeFunction(2));
	pack.WriteCell(GetNativeCell(3));

	g_hDatabase.Query(Natives_SQLCallback, sQuery, pack);
	return 1;
}

public void Natives_SQLCallback(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();
	Handle plugin = pack.ReadCell();
	Function callback = pack.ReadFunction();
	any data = pack.ReadCell();
	delete pack;

	Call_StartFunction(plugin, callback);
	Call_PushCell(db);
	Call_PushCell(results);
	Call_PushString(error);
	Call_PushCell(data);
	Call_Finish();
}

public int Native_RegisterItemHandler(Handle plugin, int numParams)
{
	if (g_iItemHandlers == STORE_MAX_ITEM_HANDLERS)
		return -1;

	char sIdentifier[64];
	GetNativeString(1, sIdentifier, sizeof(sIdentifier));
	int iHandle = GetMenuHandler(sIdentifier);
	int iIndex = g_iItemHandlers;

	if (iHandle != -1)
	{
		iIndex = iHandle;
	}
	else
	{
		g_iItemHandlers++;
	}

	g_hItemPlugin[iIndex] = plugin;
	g_fnItemMenu[iIndex] = GetNativeCell(2);
	g_fnItemHandler[iIndex] = GetNativeCell(3);
	strcopy(g_sItemID[iIndex], 64, sIdentifier);

	return iIndex;
}

public int Native_SetDataIndex(Handle plugin, int numParams)
{
	g_aItems[GetNativeCell(1)][iDataIndex] = GetNativeCell(2);
}

public int Native_GetDataIndex(Handle plugin, int numParams)
{
	return g_aItems[GetNativeCell(1)][iDataIndex];
}

public int Native_GetEquippedItem(Handle plugin, int numParams)
{
	char sType[16];
	GetNativeString(2, sType, sizeof(sType));

	int iHandle = GetTypeHandler(sType);
	if (iHandle == -1)
		return -1;

	return g_iEquipment[GetNativeCell(1)][iHandle * STORE_MAX_SLOTS + GetNativeCell(3)];
}

public int Native_IsClientLoaded(Handle plugin, int numParams)
{
	return g_bLoaded[GetNativeCell(1)];
}

public int Native_DisplayPreviousMenu(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	switch (g_iMenuNum[client])
	{
		case MENU_STORE: DisplayStoreMenu(client, g_iMenuBack[client], g_iLastSelection[client]);
		case MENU_RESET: AdminMenu_ResetPlayer(g_hTopMenu, TopMenuAction_SelectOption, g_hTopMenuObject, client, "", 0);
		case MENU_PLAN: DisplayPlanMenu(client, g_iSelectedItem[client]);
		case MENU_ADMIN: RedisplayAdminMenu(g_hTopMenu, client);
		case MENU_ITEM, MENU_PREVIEW: g_aItems[g_iSelectedItem[client]][bPreview] ? DisplayPreviewMenu(client, g_iSelectedItem[client]) : DisplayItemMenu(client, g_iSelectedItem[client]);
		case MENU_PARENT: DisplayItemMenu(client, g_aItems[g_iSelectedItem[client]][iParent] == -1 ? 0 : g_aItems[g_iSelectedItem[client]][iParent]);
	}
}

public int Native_SetClientMenu(Handle plugin, int numParams)
{
	g_iMenuNum[GetNativeCell(1)] = GetNativeCell(2);
}

public int Native_DisplayItemMenu(Handle plugin, int numParams)
{
	DisplayStoreMenu(GetNativeCell(1), GetNativeCell(2));
}

public int Native_GetClientCredits(Handle plugin, int numParams)
{
	return g_iCredits[GetNativeCell(1)];
}

public int Native_SetClientCredits(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int iCredit = GetNativeCell(2);
	char reason[64];
	char sPlugin[32];
	GetNativeString(3, reason, sizeof(reason));
	GetPluginFilename(plugin, sPlugin, sizeof(sPlugin));
	MyLogMessage(client, LOG_CREDITS, "%s set the credits to %i Reason: '%s'", sPlugin, iCredit, reason);
	g_iCredits[client] = iCredit;

	SQL_SaveClientData(client);
	return 1;
}

public int Native_IsClientVIP(Handle plugin, int numParams)
{
	return IsClientVIP(GetNativeCell(1));
}

public int Native_IsClientAdmin(Handle plugin, int numParams)
{
	return IsClientAdmin(GetNativeCell(1));
}

public int Native_HasClientAccess(Handle plugin, int numParams)
{
	return HasClientAccess(GetNativeCell(1));
}

public int Native_IsItemInBoughtPackage(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int itemid = GetNativeCell(2);
	int uid = GetNativeCell(3);

	int parent;
	if (itemid > -1) //edited
	{
		parent = g_aItems[itemid][iParent];
	}
	else return false;

	while(parent != -1)
	{
		for (int i = 0; i < g_iItems[client]; i++)
		{
			if (((uid == -1 && g_iPlayerItems[client][i][UNIQUE_ID] == parent) || (uid != -1 && g_iPlayerItems[client][i][UNIQUE_ID] == uid)) && g_iPlayerItems[client][i][DELETED] == 0)
				return true;
		}

		parent = g_aItems[parent][iParent];
	}

	return false;
}

public int Native_DisplayConfirmMenu(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	char sBuffer[255];
	GetNativeString(2, sBuffer, sizeof(sBuffer));

	//Zephyrus magic with pinch of kxnlr
	DataPack pack = new DataPack();
	pack.WriteCell(plugin);
	pack.WriteCell(GetNativeCell(3));
	pack.Reset(); //oder hier??

	char sCallback[32];
	char sData[11];
	IntToString(view_as<int>(pack), sCallback, sizeof(sCallback));
	IntToString(GetNativeCell(4), sData, sizeof(sData));

	//delete pack;

	Menu menu = new Menu(MenuHandler_Confirm);
	menu.SetTitle(sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%t", "Confirm_Yes");
	menu.AddItem(sCallback, sBuffer, ITEMDRAW_DEFAULT);

	Format(sBuffer, sizeof(sBuffer), "%t", "Confirm_No");
	menu.AddItem(sData, sBuffer, ITEMDRAW_DEFAULT);
	//Zephyrus magic

	menu.ExitButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Native_ShouldConfirm(Handle plugin, int numParams)
{
	return gc_bConfirm.BoolValue;
}

public int Native_IsInRecurringMenu(Handle plugin, int numParams)
{
	return g_bIsInRecurringMenu[GetNativeCell(1)];
}

public int Native_SetClientRecurringMenu(Handle plugin, int numParams)
{
	g_bIsInRecurringMenu[GetNativeCell(1)] = view_as<bool>(GetNativeCell(2));
}

public int Native_GetItem(Handle plugin, int numParams)
{
	int itemID = GetNativeCell(1);
	if (itemID > g_iItemCount)
		return false;

	any aBuffer[sizeof(g_aItems[])];

	for (int i = 0; i < sizeof(g_aItems[]); i++)
	{
		aBuffer[i] = g_aItems[itemID][i];
	}

	SetNativeArray(2, aBuffer, sizeof(g_aItems[]));

	return true;
}

public int Native_GetHandler(Handle plugin, int numParams)
{
	int iIndex = GetNativeCell(1);
	if (iIndex > g_iTypeHandlers)
		return false;

	any aBuffer[sizeof(g_aTypeHandlers[])];

	for (int i = 0; i < sizeof(g_aTypeHandlers[]); i++)
	{
		aBuffer[i] =  g_aTypeHandlers[iIndex][i];
	}

	SetNativeArray(2, aBuffer, sizeof(g_aTypeHandlers[]));

	return true;
}

public int Native_GetItemIdbyUniqueId(Handle plugin, int numParams)
{
	char sUId[32];
	GetNativeString(1, sUId, sizeof(sUId));

	for (int i = 0; i < g_iItemCount; i++)
	{
		if (StrEqual(sUId, g_aItems[i][szUniqueId]))
			return i;
	}

	return -1;
}

public int Native_GetClientItem(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	int uid = GetClientItemId(client, GetNativeCell(2));
	if (uid < 0)
		return false;

	any aBuffer[sizeof(g_iPlayerItems[][])]; //[] nur einmal

	for (int i = 0; i < sizeof(g_iPlayerItems[][]); i++)
	{
		aBuffer[i] = g_iPlayerItems[client][uid][i];
	}

	SetNativeArray(3, aBuffer, sizeof(g_iPlayerItems[][]));

	return true;
}

public int Native_GiveItem(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int itemid = GetNativeCell(2);
	int purchase = GetNativeCell(3);
	int expiration = GetNativeCell(4);
	int price = GetNativeCell(5);

	int iDatePurchase = (purchase == 0 ? GetTime() : purchase);
	int iDateExpiration = expiration;

	int iIndex = g_iItems[client]++;
	g_iPlayerItems[client][iIndex][UNIQUE_ID] = itemid;
	g_iPlayerItems[client][iIndex][DATE_PURCHASE] = iDatePurchase;
	g_iPlayerItems[client][iIndex][DATE_EXPIRATION] = iDateExpiration;
	g_iPlayerItems[client][iIndex][PRICE_PURCHASE] = price;
	g_iPlayerItems[client][iIndex][SYNCED] = 0;
	g_iPlayerItems[client][iIndex][DELETED] = 0;

	SQL_SaveClientInventory(client);
}

public int Native_RemoveItem(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int itemid = GetNativeCell(2);
	if (itemid > 0 && g_aTypeHandlers[g_aItems[itemid][iHandler]][fnRemove] != INVALID_FUNCTION)
	{
		Call_StartFunction(g_aTypeHandlers[g_aItems[itemid][iHandler]][hPlugin], g_aTypeHandlers[g_aItems[itemid][iHandler]][fnRemove]);
		Call_PushCell(client);
		Call_PushCell(itemid);
		Call_Finish();
	}

	UnequipItem(client, itemid, false);

	int iIndex = GetClientItemId(client, itemid);
	if (iIndex != -1)
	{
		g_iPlayerItems[client][iIndex][DELETED] = 1;
	}

	SQL_SaveClientInventory(client);
}


public int Native_UnequipItem(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int itemid = GetNativeCell(2);
	if (itemid > 0 && g_aTypeHandlers[g_aItems[itemid][iHandler]][fnRemove] != INVALID_FUNCTION)
	{
		Call_StartFunction(g_aTypeHandlers[g_aItems[itemid][iHandler]][hPlugin], g_aTypeHandlers[g_aItems[itemid][iHandler]][fnRemove]);
		Call_PushCell(client);
		Call_PushCell(itemid);
		Call_Finish();
	}

	UnequipItem(client, itemid, false);
	
	SQL_SaveClientEquipment(client);
}

public int Native_EquipItem(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	UseItem(client, GetNativeCell(2));

	SQL_SaveClientEquipment(client);
}

public int Native_GetClientTarget(Handle plugin, int numParams)
{
	return g_iMenuClient[GetNativeCell(1)];
}

public int Native_TransferClientItem(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int receiver = GetNativeCell(2);
	int itemid = GetNativeCell(3);

	int item = GetClientItemId(client, itemid);
	if (item == -1)
		return false;

	int iIndex = g_iPlayerItems[client][item][UNIQUE_ID];
	int target = g_iMenuClient[client];
	g_iPlayerItems[client][item][DELETED] = 1;
	UnequipItem(client, iIndex);

	g_iPlayerItems[receiver][g_iItems[receiver]][UNIQUE_ID] = iIndex;
	g_iPlayerItems[receiver][g_iItems[receiver]][SYNCED] = 0;
	g_iPlayerItems[receiver][g_iItems[receiver]][DELETED] = 0;
	g_iPlayerItems[receiver][g_iItems[receiver]][DATE_PURCHASE] = g_iPlayerItems[target][item][DATE_PURCHASE];
	g_iPlayerItems[receiver][g_iItems[receiver]][DATE_EXPIRATION] = g_iPlayerItems[target][item][DATE_EXPIRATION];
	g_iPlayerItems[receiver][g_iItems[receiver]][PRICE_PURCHASE] = g_iPlayerItems[target][item][PRICE_PURCHASE];

	g_iItems[receiver]++;

	return true;
}

public int Native_SellClientItem(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int itemid = GetNativeCell(2);
	float ratio = GetNativeCell(3);

	int item = GetClientItemId(client, itemid);
	if (item == -1)
		return false;

	//User own item in a plan, so calculate the rest price for the remaining time
	int iCredit = 0;
	if (g_iPlayerItems[client][item][DATE_EXPIRATION] != 0)
	{
		int iLength = g_iPlayerItems[client][item][DATE_EXPIRATION] - g_iPlayerItems[client][item][DATE_PURCHASE];
		int iLeft = g_iPlayerItems[client][item][DATE_EXPIRATION] - GetTime();
		if (iLeft < 0)
		{
			iLeft = 0;
		}

		iCredit = RoundToCeil(iCredit * iLeft / iLength * 1.0);
	}
	else
	{
		iCredit = RoundToCeil(g_iPlayerItems[client][item][PRICE_PURCHASE] * ratio);
	}

	g_iPlayerItems[client][item][DELETED] = 1;
	UnequipItem(client, itemid);
	g_iCredits[client] += iCredit;

	MyStore_LogMessage(client, LOG_EVENT, "Sold a %s %s for %i credits", g_aItems[itemid][szName], g_aTypeHandlers[g_aItems[itemid][iHandler]][szType], iCredit);
	CPrintToChat(client, "%s%t", g_sChatPrefix, "Chat Sold Item", g_aItems[itemid][szName], g_aTypeHandlers[g_aItems[itemid][iHandler]][szType]);

	return true;
}

public int Native_HasClientItem(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int itemid = GetNativeCell(2);

	// Can he even have it?
	if (!CheckFlagBits(client, g_aItems[itemid][iFlagBits]) || !CheckSteamAuth(client, g_aItems[itemid][szSteam]))
		return false;

	// Is the item free (available for everyone)?
	if (Forward_OnGetEndPrice(client, itemid, g_aItems[itemid][iPrice]) <= 0 && g_aItems[itemid][iPlans] == 0)
		return true;

	// Is the client a VIP therefore has access to all the items already?
	if (IsClientVIP(client) && !g_aItems[itemid][bIgnoreVIP])
		return true;

	// Check if the client actually has the item
	for (int i = 0; i < g_iItems[client]; i++)
	{
		if (g_iPlayerItems[client][i][UNIQUE_ID] == itemid && g_iPlayerItems[client][i][DELETED] == 0)
		{
			if (g_iPlayerItems[client][i][DATE_EXPIRATION] == 0 || (g_iPlayerItems[client][i][DATE_EXPIRATION] && GetTime() < g_iPlayerItems[client][i][DATE_EXPIRATION]))
				return true;

			return false;
		}
	}

	// Check if the item is part of a group the client already has
	if (MyStore_IsItemInBoughtPackage(client, itemid))
		return true;

	return false;
}

public int Native_IterateEquippedItems(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int start = GetNativeCellRef(2);
	bool attributes = GetNativeCell(3);

	for (int i = start + 1; i < STORE_MAX_TYPES * STORE_MAX_SLOTS; i++)
	{
		if (g_iEquipment[client][i] >= 0 && (attributes == false || (attributes && g_aItems[g_iEquipment[client][i]][hAttributes] != null)))
		{
			SetNativeCellRef(2, i);
			return g_iEquipment[client][i];
		}
	}

	return -1;
}

public int Native_LogMessage(Handle plugin, int numParams)
{
	char sBuffer[256];
	char sPlugin[32];
	int client = GetNativeCell(1);
	int level = GetNativeCell(2);
	GetNativeString(3, sBuffer, sizeof(sBuffer));
	FormatNativeString(0, 3, 4, sizeof(sBuffer), _, sBuffer);

	GetPluginFilename(plugin, sPlugin, sizeof(sPlugin));
	Format(sBuffer, sizeof(sBuffer), "Plugin: %s - %s", sPlugin, sBuffer);

	MyLogMessage(client, level, sBuffer);
}
/******************************************************************************
                   Functions
******************************************************************************/

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

	if (result != SMCError_Okay)
	{
		SMC_GetErrorString(result, error, sizeof(error));
		MyLogMessage(0, LOG_ERROR, "ReadCoreCFG: Error: %s on line %i, col %i of %s", error, line, col, sFile);
	}
}

public SMCResult Callback_CoreConfig(Handle parser, char[] key, char[] value, bool key_quotes, bool value_quotes)
{
	if (StrEqual(key, "PublicChatTrigger", false))
	{
		g_iPublicChatTrigger = value[0];
	}
	else if (StrEqual(key, "SilentChatTrigger", false))
	{
		g_iSilentChatTrigger = value[0];
	}

	return SMCParse_Continue;
}

void ReloadConfig()
{
	g_iItemCount = 0;

	for (int i = 0; i < g_iTypeHandlers; i++)
	{
		if (g_aTypeHandlers[i][fnReset] != INVALID_FUNCTION)
		{
			Call_StartFunction(g_aTypeHandlers[i][hPlugin], g_aTypeHandlers[i][fnReset]);
			Call_Finish();
		}
	}

	char sFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFile, sizeof(sFile), "configs/MyStore/items.txt");
	KeyValues kv = new KeyValues("Store");
	kv.ImportFromFile(sFile);
	if (!kv.GotoFirstSubKey())
	{
		SetFailState("Failed to read configs/MyStore/items.txt");
	}

	GoThroughConfig(kv);

	kv.GoBack();

	if (gc_bGenerateUId.BoolValue)
	{
		KeyValuesToFile(kv, sFile); //save the new uids to file
	}

	delete kv;
}

void GoThroughConfig(KeyValues &kv, int parent = -1)
{
	char sFlags[64];
	char sType[64];

	do
	{
		// We reached the max amount of items so break and don't add any more items
		if (g_iItemCount == STORE_MAX_ITEMS)
		{
			MyLogMessage(0, LOG_ERROR, "Reached max amount of store items/modules. Maximum is %i.", STORE_MAX_ITEMS);
			break;
		}

		// This is a item category (subfolder) or package
		if (kv.GetNum("enabled", 1) && kv.GetNum("type", -1) == -1 && kv.GotoFirstSubKey())
		{
			kv.GoBack();
			kv.GetSectionName(g_aItems[g_iItemCount][szName], 64);
			kv.GetSectionName(g_aItems[g_iItemCount][szUniqueId], 64);
			ReplaceString(g_aItems[g_iItemCount][szName], 64, "\\n", "\n");
			kv.GetString("shortcut", g_aItems[g_iItemCount][szShortcut], 64, "\0");
			kv.GetString("description", g_aItems[g_iItemCount][szDescription], 64, "\0");
			kv.GetString("steam", g_aItems[g_iItemCount][szSteam], 256, "\0");
			kv.GetString("flag", sFlags, sizeof(sFlags));
			g_aItems[g_iItemCount][iFlagBits] = ReadFlagString(sFlags);
			g_aItems[g_iItemCount][iPrice] = kv.GetNum("price", -1);
			g_aItems[g_iItemCount][bBuyable] = kv.GetNum("buyable", 1) ? true : false;
			g_aItems[g_iItemCount][bIgnoreVIP] = kv.GetNum("ignore_vip", 0) ? true : false;
			g_aItems[g_iItemCount][iHandler] = g_iPackageHandler;
			g_aItems[g_iItemCount][iId] = g_iItemCount;

			kv.GotoFirstSubKey();

			g_aItems[g_iItemCount][iParent] = parent;

			GoThroughConfig(kv, g_iItemCount++);
			kv.GoBack();
		}
		// This is a real item
		else
		{
			if (!kv.GetNum("enabled", 1))
				continue;

			kv.GetSectionName(g_aItems[g_iItemCount][szName], ITEM_NAME_LENGTH);
			kv.GetString("type", sType, sizeof(sType));

			// Is there the suitable type for this item?
			int iHandle = GetTypeHandler(sType);
			if (iHandle == -1)
			{
				MyLogMessage(0, LOG_ERROR, "Can't find store module type '%s' for item '%s'.", sType, g_aItems[g_iItemCount][szName]);
				continue;
			}

			g_aItems[g_iItemCount][iParent] = parent;
			g_aItems[g_iItemCount][iPrice] = kv.GetNum("price");
			kv.GetString("description", g_aItems[g_iItemCount][szDescription], 64, "\0");
			g_aItems[g_iItemCount][bBuyable] = kv.GetNum("buyable", 1) ? true : false;
			g_aItems[g_iItemCount][bIgnoreVIP] = kv.GetNum("ignore_vip", 0) ? true : false;
			kv.GetString("shortcut", g_aItems[g_iItemCount][szShortcut], 64, "\0");
			g_aItems[g_iItemCount][bPreview] = kv.GetNum("preview", 0) ? true : false;
			g_aItems[g_iItemCount][iId] = g_iItemCount;

			kv.GetString("steam", g_aItems[g_iItemCount][szSteam], 256, "\0");
			kv.GetString("flag", sFlags, sizeof(sFlags));
			g_aItems[g_iItemCount][iFlagBits] = ReadFlagString(sFlags);

			g_aItems[g_iItemCount][iHandler] = iHandle;

			kv.GetString("unique_id", g_aItems[g_iItemCount][szUniqueId], 64, "\0");

			if (!g_aItems[g_iItemCount][szUniqueId][0] && gc_bGenerateUId.BoolValue)
			{
				Format(g_aItems[g_iItemCount][szUniqueId], 64, "uid_%s_%s_%i", sType, g_aItems[g_iItemCount][szName], parent);
				ReplaceString(g_aItems[g_iItemCount][szUniqueId], 64, " ", "_");
				ReplaceString(g_aItems[g_iItemCount][szUniqueId], 64, "-", "_");
				StringToLower(g_aItems[g_iItemCount][szUniqueId]);
				kv.SetString("unique_id", g_aItems[g_iItemCount][szUniqueId]);
			}

			// Has the item a plan?
			if (kv.JumpToKey("Plans"))
			{
				kv.GotoFirstSubKey();
				int index = 0;
				do
				{
					kv.GetSectionName(g_sPlanName[g_iItemCount][index], ITEM_NAME_LENGTH);
					g_iPlanPrice[g_iItemCount][index] = kv.GetNum("price");
					g_iPlanTime[g_iItemCount][index] = kv.GetNum("time");
					index++;
				}
				while kv.GotoNextKey();

				g_aItems[g_iItemCount][iPlans] = index;

				kv.GoBack();
				kv.GoBack();
			}

			// Has the item attributes?
			delete g_aItems[g_iItemCount][hAttributes];
			if (kv.JumpToKey("Attributes"))
			{
				g_aItems[g_iItemCount][hAttributes] = new StringMap();

				kv.GotoFirstSubKey(false);

				char sAttribute[64];
				char sValue[64];
				do
				{
					kv.GetSectionName(sAttribute, sizeof(sAttribute));
					kv.GetString(NULL_STRING, sValue, sizeof(sValue));
					g_aItems[g_iItemCount][hAttributes].SetString(sAttribute, sValue);
				}
				while kv.GotoNextKey(false);

				kv.GoBack();
				kv.GoBack();
			}

			// Call item plugins config function
			bool bSuccess = true;
			if (g_aTypeHandlers[iHandle][fnConfig] != INVALID_FUNCTION)
			{
				Call_StartFunction(g_aTypeHandlers[iHandle][hPlugin], g_aTypeHandlers[iHandle][fnConfig]);
				Call_PushCellRef(kv);
				Call_PushCell(g_iItemCount);
				Call_Finish(bSuccess);
			}

			// When plugin return true add the item finally, otherwise overwrite item with next item
			if (bSuccess)
			{
				g_iItemCount++;
			}
		}
	}
	while kv.GotoNextKey();
}


void BuyItem(int client, int itemid, int plan = -1)
{
	if (MyStore_HasClientItem(client, itemid))
		return;

	if (!gc_bEnable.BoolValue)
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Store Disabled");
		return;
	}

	int price = 0;
	int costs = 0;
	if (plan == -1)
	{
		price = g_aItems[itemid][iPrice];
		costs = Forward_OnGetEndPrice(client, itemid, g_aItems[itemid][iPrice]);
	}
	else
	{
		price = g_iPlanPrice[itemid][plan];
		costs = Forward_OnGetEndPrice(client, itemid, g_iPlanPrice[itemid][plan]);
	}

	Action aReturn = Plugin_Continue;
	Call_StartForward(gf_hOnBuyItem);
	Call_PushCell(client);
	Call_PushCell(itemid);
	Call_PushCell(price);
	Call_PushCellRef(costs);
	Call_Finish(aReturn);

	if (aReturn == Plugin_Handled)
		return;

	if (g_iCredits[client] < costs)
		return;

	int iIndex = g_iItems[client]++;
	g_iPlayerItems[client][iIndex][UNIQUE_ID] = itemid;
	g_iPlayerItems[client][iIndex][DATE_PURCHASE] = GetTime();
	g_iPlayerItems[client][iIndex][DATE_EXPIRATION] = (plan == -1 ? 0 : (g_iPlanTime[itemid][plan] ? GetTime() + g_iPlanTime[itemid][plan] : 0));
	g_iPlayerItems[client][iIndex][PRICE_PURCHASE] = costs;
	g_iPlayerItems[client][iIndex][SYNCED] = 0;
	g_iPlayerItems[client][iIndex][DELETED] = 0;

	g_iCredits[client] -= costs;

	MyLogMessage(client, LOG_EVENT, "Bought a '%s' - '%s' for %i credits", g_aTypeHandlers[g_aItems[itemid][iHandler]][szType], g_aItems[itemid][szName], costs);

	CPrintToChat(client, "%s%t", g_sChatPrefix, "Chat Bought Item", g_aItems[itemid][szName], g_aTypeHandlers[g_aItems[itemid][iHandler]][szType]);

	SQL_SaveClientInventory(client);
}

bool UseItem(int client, int itemid, bool synced = false, int slot = 0)
{
	if (!gc_bEnable.BoolValue)
		return false;

	int iSlot = slot;
	if (g_aTypeHandlers[g_aItems[itemid][iHandler]][fnUse] != INVALID_FUNCTION)
	{
		int iReturn = ITEM_EQUIP_SUCCESS;
		Call_StartFunction(g_aTypeHandlers[g_aItems[itemid][iHandler]][hPlugin], g_aTypeHandlers[g_aItems[itemid][iHandler]][fnUse]);
		Call_PushCell(client);
		Call_PushCell(itemid);
		Call_Finish(iReturn);

		if (iReturn != ITEM_EQUIP_SUCCESS)
		{
			iSlot = iReturn;
		}

		Call_StartForward(gf_hOnItemEquipt);
		Call_PushCell(client);
		Call_PushCell(itemid);
		Call_Finish();
	}

	if (g_aTypeHandlers[g_aItems[itemid][iHandler]][bEquipable])
	{
		g_iEquipment[client][g_aItems[itemid][iHandler] * STORE_MAX_SLOTS + iSlot] = itemid;
		if (synced)
		{
			g_iEquipmentSynced[client][g_aItems[itemid][iHandler] * STORE_MAX_SLOTS + iSlot] = itemid;
		}
	}
	else if (iSlot == ITEM_EQUIP_REMOVE)
	{
		MyStore_RemoveItem(client, itemid);
		return true;
	}

	return true;
}

void UnequipItem(int client, int itemid, bool noDouble = true)
{
	if (itemid == -1)
		return;

	int iSlot = 0;
	if (noDouble && itemid > 0 && g_aTypeHandlers[g_aItems[itemid][iHandler]][fnRemove] != INVALID_FUNCTION)
	{
		Call_StartFunction(g_aTypeHandlers[g_aItems[itemid][iHandler]][hPlugin], g_aTypeHandlers[g_aItems[itemid][iHandler]][fnRemove]);
		Call_PushCell(client);
		Call_PushCell(itemid);
		Call_Finish(iSlot);
	}

	int iIndex;
	if (g_aItems[itemid][iHandler] != g_iPackageHandler)
	{
		iIndex = g_aItems[itemid][iHandler] * STORE_MAX_SLOTS + iSlot;
		if (g_iEquipmentSynced[client][iIndex] == -2)
		{
			g_iEquipment[client][iIndex] = -2;
		}
		else
		{
			g_iEquipment[client][iIndex] = -1;
		}
	}
	else
	{
		for (int i = 0; i < STORE_MAX_TYPES; i++)
		{
			for (int a = 0; i < STORE_MAX_SLOTS; i++)
			{
				if (g_iEquipment[client][i + a] < 0)
					continue;

				iIndex = i * STORE_MAX_SLOTS + a;
				if (MyStore_IsItemInBoughtPackage(client, g_iEquipment[client][iIndex], itemid))
				{
					if (g_iEquipmentSynced[client][iIndex] == -2)
					{
						g_iEquipment[client][iIndex] = -2;
					}
					else
					{
						g_iEquipment[client][iIndex] = -1;
					}
				}
			}
		}
	}
}

bool PackageHasClientItem(int client, int packageid, bool invmode = false)
{
	int iFlags = GetUserFlagBits(client);
	if (!gc_bShowVIP.BoolValue && !CheckFlagBits(client, g_aItems[packageid][iFlagBits], iFlags) && !CheckSteamAuth(client, g_aItems[packageid][szSteam]))
		return false;

	for (int i = 0; i < g_iItemCount; i++)
	{
		if (g_aItems[i][iParent] == packageid && (gc_bShowVIP.BoolValue || CheckFlagBits(client, g_aItems[i][iFlagBits], iFlags) || CheckSteamAuth(client, g_aItems[i][szSteam])) && (invmode && MyStore_HasClientItem(client, i) || !invmode))
		{
			if ((g_aItems[i][iHandler] == g_iPackageHandler && PackageHasClientItem(client, i, invmode)) || g_aItems[i][iHandler] != g_iPackageHandler)
				return true;
		}
	}

	return false;
}

void MyLogMessage(int client = 0, int level, char[] message, any ...)
{
	if (gc_iLogging.IntValue < 1)
		return;

	if (gc_iLoggingLevel.IntValue <= level)
		return;

	char sLevel[8];
	char sReason[256];
	VFormat(sReason, sizeof(sReason), message, 4);

	switch(level)
	{
		case LOG_ADMIN: strcopy(sLevel, sizeof(sLevel), "[Admin]");
		case LOG_EVENT: strcopy(sLevel, sizeof(sLevel), "[Event]");
		case LOG_CREDITS: strcopy(sLevel, sizeof(sLevel), "[Credits]");
		case LOG_ERROR:
		{
			strcopy(sLevel, sizeof(sLevel), "[ERROR]");
			LogError("%s - %L - %s", sLevel, client, sReason);
		}
	}

	switch(gc_iLogging.IntValue)
	{
		case 2:
		{
			char sQuery[256];
			g_hDatabase.Escape(sQuery, sQuery, sizeof(sQuery));
			Format(sQuery, sizeof(sQuery), "INSERT INTO mystore_logs (level, player_id, reason, date) VALUES(\"%s\", %i, \"%s\", %i)", sLevel, g_iPlayerID[client], sReason, GetTime());
			g_hDatabase.Query(SQLCallback_Void_Error, sQuery);
		}
		default:
		{
			LogToOpenFileEx(g_hLogFile, "%s - %L - %s", sLevel, client, sReason); //WriteFileLine(g_hLogFile, "%s - %L - %s", sLevel, client, sReason); //todo dont work
		}
	}
}

void Forward_OnConfigsExecuted()
{
	Call_StartForward(gf_hOnConfigExecuted);
	Call_PushCell(gc_bEnable);
	Call_PushString(g_sName);
	Call_PushString(g_sChatPrefix);
	Call_PushString(g_sCreditsName);
	Call_Finish();
}

int GetItemId(char[] type, char[] uid, int start = -1)
{
	for (int i = start + 1; i <  g_iItemCount; i++)
	{
		if (strcmp(g_aTypeHandlers[g_aItems[i][iHandler]][szType], type) == 0 && strcmp(g_aItems[i][szUniqueId], uid) == 0 && g_aItems[i][iPrice] >= 0)
			return i;
	}

	return -1;
}

int GetTypeHandler(char[] type)
{
	for (int i = 0; i < g_iTypeHandlers; i++)
	{
		if (strcmp(g_aTypeHandlers[i][szType], type) == 0)
			return i;
	}

	return -1;
}

int GetMenuHandler(char[] id)
{
	for (int i = 0; i < g_iItemHandlers; i++)
	{
		if (strcmp(g_sItemID[i], id) == 0)
			return i;
	}

	return -1;
}

bool IsEquipped(int client, int itemid)
{
	for (int i = 0; i < STORE_MAX_SLOTS; i++)
	{
		if (g_iEquipment[client][g_aItems[itemid][iHandler] * STORE_MAX_SLOTS + i] == itemid)
			return true;
	}

	return false;
}

int GetExpiration(int client, int itemid)
{
	int uid = GetClientItemId(client, itemid);
	if (uid < 0)
		return 0;

	return g_iPlayerItems[client][uid][DATE_EXPIRATION];
}

int GetLowestPrice(int itemid)
{
	if (g_aItems[itemid][iPlans] == 0)
		return g_aItems[itemid][iPrice];

	int iLowest = g_iPlanPrice[itemid][0];
	for (int i = 1; i < g_aItems[itemid][iPlans]; i++)
	{
		if (iLowest > g_iPlanPrice[itemid][i])
		{
			iLowest = g_iPlanPrice[itemid][i];
		}
	}

	return iLowest;
}

int Forward_OnGetEndPrice(int client, int itemid, int price, bool &reduced = false)
{
	Action aReturn;

	Call_StartForward(gf_hOnGetEndPrice);
	Call_PushCell(client);
	Call_PushCell(itemid);
	Call_PushCellRef(price);
	Call_Finish(aReturn);

	if (aReturn == Plugin_Changed)
	{
		reduced = true;
	}

	return price;
}

int GetClientItemId(int client, int itemid)
{
	for (int i = 0; i < g_iItems[client]; i++)
	{
		if (g_iPlayerItems[client][i][UNIQUE_ID] == itemid && g_iPlayerItems[client][i][DELETED] == 0)
			return i;
	}

	return -1;
}

int GetClientBySteamID(char[] steamid)
{
	char authid[32];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;

		if (!IsClientAuthorized(i))
			continue;

		if (!GetClientAuthId(i, AuthId_Steam2, authid, sizeof(authid)))
			continue;

		if (strcmp(authid[8], steamid[8]) == 0 || strcmp(authid, steamid) == 0)
			return i;
	}

	return 0;
}

bool GetLegacyAuthString(int client, char[] out, int maxlen, bool validate=true)
{
	char sSteamID[32];
	bool success = GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID), validate);

	if (sSteamID[0] == '[')
	{
		int iAccountID = StringToInt(sSteamID[5]);
		int iMod = iAccountID % 2;
		Format(out, maxlen, "STEAM_0:%i:%i", iMod, (iAccountID - iMod) / 2);
	}
	else
	{
		strcopy(out, maxlen, sSteamID);
	}

	return success;
}

bool IsClientVIP(int client)
{
	if (g_iVIPFlags == 0)
		return false;

	return CheckFlagBits(client, g_iVIPFlags);
}

bool IsClientAdmin(int client)
{
	if (g_iAdminFlags == 0)
		return false;

	return CheckFlagBits(client, g_iAdminFlags);
}

bool HasClientAccess(int client)
{
	return CheckFlagBits(client, g_iMinFlags);
}

bool CheckFlagBits(int client, int flagsNeed, int flags = -1)
{
	if (flags == -1)
	{
		flags = GetUserFlagBits(client);
	}

	if (flagsNeed == 0 || flags & flagsNeed || flags & ADMFLAG_ROOT)
		return true;

	return false;
}

bool CheckSteamAuth(int client, char[] steam)
{
	if (!steam[0])
		return true;

	char sSteam[32];
	if (!GetClientAuthId(client, AuthId_Steam2, sSteam, 32))
		return false;

	if (StrContains(steam, sSteam) == -1)
		return false;

	return true;
}

bool DirExistsEx(const char[] szPath)
{
	if (DirExists(szPath))
		return true;

	CreateDirectory(szPath, 511);

	if (!DirExists(szPath))
	{
		MyLogMessage(0, LOG_ERROR, "DirExistsEx: Error: Couldn't create folder! (%s)", szPath);
		return false;
	}

	return true;
}

void StringToLower(char[] sz)
{
	int len = strlen(sz);

	for (int i = 0; i < len; i++)
	if (IsCharUpper(sz[i]))
	{
		sz[i] = CharToLower(sz[i]);
	}
}
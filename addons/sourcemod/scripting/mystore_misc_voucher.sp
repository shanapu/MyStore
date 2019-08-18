/*
 * MyStore - Voucher module
 * by: shanapu
 * https://github.com/shanapu/
 * 
 * Copyright (C) 2018-2019 Thomas Schmidt (shanapu)
 * Credits:
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


#include <sourcemod>
#include <sdktools>

#include <mystore> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/mystore.inc

#include <autoexecconfig> //https://raw.githubusercontent.com/Impact123/AutoExecConfig/development/autoexecconfig.inc
#include <colors> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/colors.inc

#pragma semicolon 1
#pragma newdecls required


#define REDEEM 1
#define CHECK 2
#define NUM 3
#define MIN 4
#define MAX 5
#define PURCHASE 6

ConVar gc_iMySQLCooldown;
ConVar gc_iExpireTime;
ConVar gc_bEnable;
ConVar gc_bItemVoucherEnabled;
ConVar gc_bCreditVoucherEnabled;
ConVar gc_bCheckAdmin;
int g_iChatType[MAXPLAYERS + 1] = {-1, ...};

char g_sChatPrefix[32];
char g_sCreditsName[32];
char g_sName[64];

char g_sMenuItem[64];
char g_sMenuExit[64];

float g_fInputTime;

Handle g_hTimerInput[MAXPLAYERS+1] = null;
Handle gf_hPreviewItem;

int g_iTempAmount[MAXPLAYERS + 1] = {0, ...};
int g_iCreateNum[MAXPLAYERS + 1] = {0, ...};
int g_iCreateMin[MAXPLAYERS + 1] = {0, ...};
int g_iCreateMax[MAXPLAYERS + 1] = {0, ...};
int g_iLastQuery[MAXPLAYERS + 1] = {0, ...};
int g_iSelectedItem[MAXPLAYERS + 1];

/*
 * Build date: <DATE>
 * Build number: <BUILD>
 * Commit: https://github.com/shanapu/MyStore/commit/<COMMIT>
 */

public Plugin myinfo = 
{
	name = "MyStore - Voucher module",
	author = "shanapu", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "",
	version = "0.1.<BUILD>", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = "github.com/shanapu/MyStore"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	gf_hPreviewItem = CreateGlobalForward("MyStore_OnPreviewItem", ET_Ignore, Param_Cell, Param_String, Param_Cell);

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");
	LoadTranslations("common.phrases");

	RegConsoleCmd("sm_voucher", Command_Voucher, "Open the Voucher main menu");
	RegAdminCmd("sm_createvoucher", Command_CreateVoucherCode, ADMFLAG_ROOT);

	AutoExecConfig_SetFile("vouchers", "sourcemod/mystore");
	AutoExecConfig_SetCreateFile(true);

	gc_bCreditVoucherEnabled = AutoExecConfig_CreateConVar("myc_voucher_credits", "1", "0 - disabled, 1 - enable credits to voucher", _, true, 0.0, true, 1.0);
	gc_bItemVoucherEnabled = AutoExecConfig_CreateConVar("myc_voucher_item", "1", "0 - disabled, 1 - enable item to voucher", _, true, 0.0, true, 1.0);
	gc_bCheckAdmin = AutoExecConfig_CreateConVar("myc_voucher_check", "1", "0 - admins only, 1 - all player can check vouchers", _, true, 0.0, true, 1.0);
	gc_iMySQLCooldown = AutoExecConfig_CreateConVar("myc_mysql_cooldown", "20", "Seconds cooldown between client start database querys (redeem, check & purchase vouchers)", _, true, 5.0);
	gc_iExpireTime = AutoExecConfig_CreateConVar("myc_voucher_expire", "336", "0 - disabled, hours until a voucher expire after creation. 168 = one week", _, true, 1.0);

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	AddCommandListener(Command_Say, "say"); 
	AddCommandListener(Command_Say, "say_team");

}

public void OnAllPluginsLoaded()
{
	if (gc_bItemVoucherEnabled.BoolValue)
	{
		if (MyStore_RegisterItemHandler("Voucher", Store_OnMenu, Store_OnHandler) == -1)
		{
			MyStore_LogMessage(_, LOG_ERROR, "Can't Register module to core - Reached max item handlers(%i).", STORE_MAX_ITEM_HANDLERS);
		}
	}
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;

	strcopy(g_sName, sizeof(g_sName), name);
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
	strcopy(g_sCreditsName, sizeof(g_sCreditsName), credits);

	g_fInputTime = 12.0; //todo? = time.FloatValue;

	ReadCoreCFG();

	MyStore_SQLQuery("CREATE TABLE if NOT EXISTS mystore_voucher (\
					  voucher varchar(64) NOT NULL PRIMARY KEY default '',\
					  name_of_create varchar(64) NOT NULL default '',\
					  steam_of_create varchar(64) NOT NULL default '',\
					  credits INT NOT NULL default 0,\
					  item varchar(64) NOT NULL default '',\
					  date_of_create INT NOT NULL default 0,\
					  date_of_redeem INT NOT NULL default 0,\
					  name_of_redeem varchar(64) NOT NULL default '',\
					  steam_of_redeem TEXT NOT NULL,\
					  unlimited TINYINT NOT NULL default 0,\
					  date_of_expiration INT NOT NULL default 0);",
					  SQLCallback_Void, 0);
}

public Action Command_Voucher(int client, int args)
{
	if (client == 0)
	{
		CReplyToCommand(client, "%s%t", g_sChatPrefix, "Command is in-game only");

		return Plugin_Handled;
	}

	if (!gc_bEnable.BoolValue)
	{
		CReplyToCommand(client, "%s%t", g_sChatPrefix, "Store Disabled");

		return Plugin_Handled;
	}

	Menu_Voucher(client);

	return Plugin_Handled;
}

public Action Command_CreateVoucherCode(int client, int args)
{
	if (client == 0)
	{
		CReplyToCommand(client, "%s%t", g_sChatPrefix, "Command is in-game only");

		return Plugin_Handled;
	}

	if (args < 2)
	{
		CReplyToCommand(client, "%s%t", g_sChatPrefix, "Usage: sm_createvoucher <quantity> <min_amount>-<max_amount> [0/1] [VoucherCode17char]");

		return Plugin_Handled;
	}

	char sBuffer[64], sParts[16][2];

	GetCmdArg(1, sBuffer, sizeof(sBuffer));
	int iNum = StringToInt(sBuffer);

	GetCmdArg(2, sBuffer, sizeof(sBuffer));
	int iCount = ExplodeString(sBuffer, "-", sParts, sizeof(sParts), sizeof(sParts), false);
	int iNum1 = StringToInt(sParts[0]);
	int iNum2 =StringToInt(sParts[1]);
	bool bUnlimited = false;

	if (args == 3)
	{
		GetCmdArg(3, sBuffer, sizeof(sBuffer));
		bUnlimited = view_as<bool>(StringToInt(sBuffer));
	}

	if (args == 4)
	{
		if (strlen(sBuffer) != 17)
		{
			CReplyToCommand(client, "%s %s", g_sChatPrefix, "For now voucher code should be excatly 17 chars");

			return Plugin_Handled;
		}

		GetCmdArg(3, sBuffer, sizeof(sBuffer));
	}

	if (iCount == 1)
	{
		CReplyToCommand(client, "%s You are generating %i %slimited voucher%s with value %i %s", g_sChatPrefix, iNum, bUnlimited == true ? "un" : "", iNum == 1 ? "" : "s", iNum1, g_sCreditsName);
	}
	else
	{
		CReplyToCommand(client, "%s You are generating %i %slimited voucher%s with values %i-%i %s", g_sChatPrefix, iNum, bUnlimited == true ? "un" : "", iNum == 1 ? "" : "s", iNum1, iNum2, g_sCreditsName);
	}

	for (int i = 0; i < iNum; i++)
	{
		if (args < 4)
		{
			GenerateVoucherCode(sBuffer, sizeof(sBuffer));
		}

		SQL_WriteVoucher(client, sBuffer, GetRandomInt(iNum1, iNum2), bUnlimited);
	}

	return Plugin_Handled;
}

bool GenerateVoucherCode(char[] sBuffer, int maxlen)
{
	char sListOfChar[26][1] = {"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"};

	if (sBuffer[0])
	{
		sBuffer[0] = '\0';
	}

	for (int i = 0; i < 17; i++)
	{
		if (i == 5 || i == 11)
		{
			StrCat(sBuffer, maxlen, "-");
		}
		else
		{
			StrCat(sBuffer, maxlen, sListOfChar[GetRandomInt(0, sizeof(sListOfChar) - 1)]);
		}
	}

	return true;
}

public Action Command_Say(int client, const char[] command, int args)
{
	if (g_iChatType[client] == -1)
		return Plugin_Continue;

	char sMessage[64];
	GetCmdArgString(sMessage, sizeof(sMessage));
	StripQuotes(sMessage);

	delete g_hTimerInput[client];

	switch(g_iChatType[client])
	{
		case PURCHASE:
		{
			int amount = StringToInt(sMessage);

			if (amount < 1)
			{
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Value less than 1");
				Menu_Voucher(client);
				return Plugin_Continue;
			}

			if (amount > MyStore_GetClientCredits(client))
			{
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Not enough Tokens", g_sCreditsName);
				Menu_Voucher(client);
				return Plugin_Continue;
			}

			g_iTempAmount[client] = amount;
			g_iChatType[client] = -1;

			char sBuffer[32];
			GenerateVoucherCode(sBuffer, sizeof(sBuffer));
			SQL_WriteVoucher(client, sBuffer, g_iTempAmount[client], false);
			g_iLastQuery[client] = GetTime();
		}
		case NUM:
		{
			int amount = StringToInt(sMessage);

			if (amount < 1)
			{
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Value less than 1");
				Menu_Voucher(client);
				return Plugin_Continue;
			}

			g_iCreateNum[client] = amount;
			g_iChatType[client] = MIN;

			Panel_Multi(client, 5);
			g_hTimerInput[client] = CreateTimer(g_fInputTime, Timer_Input2Late, GetClientUserId(client));
		}
		case MIN:
		{
			int amount = StringToInt(sMessage);

			if (amount < 1)
			{
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Value less than 1");
				Menu_Voucher(client);
				return Plugin_Continue;
			}

			g_iCreateMin[client] = amount;
			g_iChatType[client] = MAX;

			Panel_Multi(client, 6);
			g_hTimerInput[client] = CreateTimer(g_fInputTime, Timer_Input2Late, GetClientUserId(client));
		}
		case MAX:
		{
			int amount = StringToInt(sMessage);

			if (amount < 1)
			{
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Value less than 1");
				Menu_Voucher(client);
				return Plugin_Continue;
			}

			if (amount < g_iCreateMin[client])
			{
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Smaller than min value", g_iCreateMin[client]);
				Menu_Voucher(client);
				return Plugin_Continue;
			}

			g_iCreateMax[client] = amount;
			g_iChatType[client] = -1;

			Menu_CreateVoucherLimit(client);
		}
		case REDEEM:
		{
			if (strlen(sMessage) != 17)
			{
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Wrong voucher code format");
				Menu_Voucher(client);
				return Plugin_Continue;
			}

			g_iChatType[client] = -1;

			SQL_FetchVoucher(client, sMessage);
		}
		case CHECK:
		{
			if (strlen(sMessage) != 17)
			{
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Wrong voucher code format");
				Menu_Voucher(client);
				return Plugin_Continue;
			}

			g_iChatType[client] = -1;

			SQL_CheckVoucher(client, sMessage);
		}
	}

	return Plugin_Handled;
}

void Menu_Voucher(int client)
{
	char sBuffer[96];
	int iCredits = MyStore_GetClientCredits(client); // Get credits
	Menu menu = CreateMenu(Handler_Voucher);
	g_iChatType[client] = -1;

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "Title Store", g_sName, "Title Credits", g_sCreditsName, iCredits);
	menu.SetTitle(sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%t", "Redeem Voucher");
	menu.AddItem("1", sBuffer);

	if (MyStore_IsClientAdmin(client) || gc_bCheckAdmin.BoolValue)
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Check Voucher");
		menu.AddItem("2", sBuffer);
	}

	if (gc_bCreditVoucherEnabled.BoolValue)
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Purchase Voucher");
		menu.AddItem("6", sBuffer);
	}

	if (MyStore_IsClientAdmin(client))
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Create Voucher");
		menu.AddItem("4", sBuffer);
	}

	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_Voucher(Menu menu, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		char sBuffer[64];
		menu.GetItem(itemNum, sBuffer, sizeof(sBuffer));
		int num = StringToInt(sBuffer);

		switch(num)
		{
			case REDEEM: // Redeem
			{
				if (g_iLastQuery[client] + gc_iMySQLCooldown.IntValue < GetTime())
				{
					g_iChatType[client] = REDEEM;

					Panel_Multi(client, 4);
				}
				else
				{
					Menu_Voucher(client);

					CPrintToChat(client, "%s%t", g_sChatPrefix, "SQL Cooldown");
				}
			}
			case CHECK: //Check
			{
				if (g_iLastQuery[client] + gc_iMySQLCooldown.IntValue < GetTime())
				{
					g_iChatType[client] = CHECK;

					Panel_Multi(client, 4);
				}
				else
				{
					Menu_Voucher(client);

					CPrintToChat(client, "%s%t", g_sChatPrefix, "SQL Cooldown");
				}
			}
			case PURCHASE: // Purchase
			{
				if (g_iLastQuery[client] + gc_iMySQLCooldown.IntValue < GetTime())
				{
					g_iChatType[client] = PURCHASE;

					Panel_Multi(client, 3);
				}
				else
				{
					Menu_Voucher(client);

					CPrintToChat(client, "%s%t", g_sChatPrefix, "SQL Cooldown");
				}
			}
			case 4: //Generate
			{
				g_iChatType[client] = NUM;

				Panel_Multi(client, 2);
			}
		}

		delete g_hTimerInput[client];
		g_hTimerInput[client] = CreateTimer(g_fInputTime, Timer_Input2Late, GetClientUserId(client));
	}
	else if (action == MenuAction_Cancel)
	{
		if (itemNum == MenuCancel_ExitBack)
		{
			MyStore_DisplayPreviousMenu(client);
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

void Menu_CreateVoucherLimit(int client)
{
	char sBuffer[128];
	int iCredits = MyStore_GetClientCredits(client); // Get credits
	Menu menu = CreateMenu(Handler_Createunlimited);

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "Title Store", g_sName, "Title Credits", g_sCreditsName, iCredits);
	menu.SetTitle(sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%s", "Limited");
	menu.AddItem("limited", sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%s", "Unlimited");
	menu.AddItem("unlimited", sBuffer);

	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_Createunlimited(Menu menu, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		char sBuffer[32];
		bool bUnlimited = false;
		menu.GetItem(itemNum, sBuffer, sizeof(sBuffer));

		if (strcmp(sBuffer, "unlimited") == 0)
		{
			bUnlimited = true;
		}

		for (int i = 0; i < g_iCreateNum[client]; i++)
		{
			GenerateVoucherCode(sBuffer, sizeof(sBuffer));

			SQL_WriteVoucher(client, sBuffer, GetRandomInt(g_iCreateMin[client], g_iCreateMax[client]), bUnlimited);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (itemNum == MenuCancel_ExitBack)
		{
			Menu_Voucher(client);
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

/******************************************************************************
                   Panel
******************************************************************************/

void Panel_Multi(int client, int num)
{
	char sBuffer[255];
	int iCredits = MyStore_GetClientCredits(client);
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "Title Store", g_sName, "Title Credits", g_sCreditsName, iCredits);
	panel.SetTitle(sBuffer);
	panel.DrawText(" ");

	switch(num)
	{
		case 1:
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "To late chat input");
			panel.DrawText(sBuffer);
			Format(sBuffer, sizeof(sBuffer), "%t", "Start again from begin");
			panel.DrawText(sBuffer);
			panel.DrawText(" ");

			Format(sBuffer, sizeof(sBuffer), "%t", "Close");
			panel.DrawItem(sBuffer);
			panel.Send(client, Handler_NullCancel, 14);
		}
		case 2:
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "Enter number of vouchers");
			panel.DrawText(sBuffer);
			panel.DrawText(sBuffer);
			panel.DrawText(" ");

			Format(sBuffer, sizeof(sBuffer), "%t", "Cancel");
			panel.DrawItem(sBuffer);
			panel.Send(client, Handler_NullCancelInput, view_as<int>(g_fInputTime));

			delete g_hTimerInput[client];
			g_hTimerInput[client] = CreateTimer(g_fInputTime, Timer_Input2Late, GetClientUserId(client));
		}
		case 3:
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "Enter value of vouchers");
			panel.DrawText(sBuffer);
			panel.DrawText(sBuffer);
			panel.DrawText(" ");

			Format(sBuffer, sizeof(sBuffer), "%t", "Cancel");
			panel.DrawItem(sBuffer);
			panel.Send(client, Handler_NullCancelInput, view_as<int>(g_fInputTime));

			delete g_hTimerInput[client];
			g_hTimerInput[client] = CreateTimer(g_fInputTime, Timer_Input2Late, GetClientUserId(client));
		}
		case 4:
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "Enter voucher code");
			panel.DrawText(sBuffer);
			panel.DrawText(sBuffer);
			panel.DrawText(" ");

			Format(sBuffer, sizeof(sBuffer), "%t", "Close");
			panel.DrawItem(sBuffer);
			panel.Send(client, Handler_NullCancel, 14);

			delete g_hTimerInput[client];
			g_hTimerInput[client] = CreateTimer(g_fInputTime, Timer_Input2Late, GetClientUserId(client));
		}
		case 5:
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "Enter minimum value");
			panel.DrawText(sBuffer);
			panel.DrawText(sBuffer);
			panel.DrawText(" ");

			Format(sBuffer, sizeof(sBuffer), "%t", "Cancel");
			panel.DrawItem(sBuffer);

			panel.Send(client, Handler_NullCancelInput, view_as<int>(g_fInputTime)); // open info Panel

			delete g_hTimerInput[client];
			g_hTimerInput[client] = CreateTimer(g_fInputTime, Timer_Input2Late, GetClientUserId(client));
		}
		case 6:
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "Enter maximum value");
			panel.DrawText(sBuffer);
			panel.DrawText(sBuffer);
			panel.DrawText(" ");

			Format(sBuffer, sizeof(sBuffer), "%t", "Cancel");
			panel.DrawItem(sBuffer);

			panel.Send(client, Handler_NullCancelInput, view_as<int>(g_fInputTime)); // open info Panel

			delete g_hTimerInput[client];
			g_hTimerInput[client] = CreateTimer(g_fInputTime, Timer_Input2Late, GetClientUserId(client));
		}
	}

	delete panel;
}


void Panel_VoucherPurchaseSuccess(int client, int credits = 0, char[] voucher, char[] uniqueID = "")
{
	char sBuffer[255];
	int iCredits = MyStore_GetClientCredits(client); // Get credits
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "Title Store", g_sName, "Title Credits", g_sCreditsName, iCredits);
	panel.SetTitle(sBuffer);

	panel.DrawText(" ");
	Format(sBuffer, sizeof(sBuffer), "%t", "Succesfully purchased voucher");
	panel.DrawText(sBuffer);

	any item[Item_Data];
	any handler[Type_Handler];
	if (!credits)
	{
		int itemid = MyStore_GetItemIdbyUniqueId(uniqueID);
		MyStore_GetItem(itemid, item);
		MyStore_GetHandler(item[iHandler], handler);
		Format(sBuffer, sizeof(sBuffer), "%t", "Voucher item", item[szName], handler[szType]);
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Voucher Value", credits, g_sCreditsName);

	}

	panel.DrawText(sBuffer);
	panel.DrawText(" ");
	Format(sBuffer, sizeof(sBuffer), "###   %s   ###", voucher);
	panel.DrawText(sBuffer);
	panel.DrawText(" ");
	Format(sBuffer, sizeof(sBuffer), "%t", "Voucher in chat and console");
	panel.DrawText(sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer);

	panel.Send(client, Handler_NullCancelVoucher, MENU_TIME_FOREVER); // open info Panel
	delete panel;
}


void Panel_VoucherAccept(int client, int credits, char[] voucher, char[] uniqueID)
{
	char sBuffer[255];
	int iCredits = MyStore_GetClientCredits(client); // Get credits
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "Title Store", g_sName, "Title Credits", g_sCreditsName, iCredits);
	panel.SetTitle(sBuffer);

	panel.DrawText(" ");
	Format(sBuffer, sizeof(sBuffer), "%t", "Voucher accepted");
	panel.DrawText(sBuffer);

	if (!credits)
	{
		int itemid = MyStore_GetItemIdbyUniqueId(uniqueID);
		any item[Item_Data];
		any handler[Type_Handler];
		MyStore_GetItem(itemid, item);
		MyStore_GetHandler(item[iHandler], handler);
		Format(sBuffer, sizeof(sBuffer), "%t", "You get x item", item[szName], handler[szType]);
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "You get x Credits", credits, g_sCreditsName);
	}

	panel.DrawText(sBuffer);
	panel.DrawText(" ");
	Format(sBuffer, sizeof(sBuffer), "###   %s   ###", voucher);
	panel.DrawText(sBuffer);
	panel.DrawText(" ");

	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer);

	panel.Send(client, Handler_NullCancelVoucher, 14); // open info Panel

	delete panel;
}

// Menu Handler for Panels
public int Handler_NullCancelInput(Handle menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		delete g_hTimerInput[client];

		FakeClientCommand(client, "play sound/%s", g_sMenuItem);
		return;
	}

	return;
}

// Menu Handler for Panels
public int Handler_NullCancel(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			default: // cancel
			{
				return;
			}
		}
	}

	return;
}


// Menu Handler for Panels
public int Handler_NullCancelVoucher(Handle menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2) 
		{
			default: // cancel
			{
				Menu_Voucher(client);

				FakeClientCommand(client, "play sound/%s", g_sMenuItem);
				return;
			}
		}
	}

	return;
}

public Action Timer_Input2Late(Handle tmr, int userid)
{
	int client = GetClientOfUserId(userid);

	g_iChatType[client] = -1;

	Panel_Multi(client, 1);

	FakeClientCommand(client, "play sound/%s", g_sMenuExit);

	g_hTimerInput[client] = null;
	return Plugin_Stop;
}


public void SQLTXNCallback_Success(Database db, float time, int numQueries, Handle[] results, any[] queryData)
{
	float querytime = GetEngineTime() - time;
	PrintToServer("MyStore Vouchers - Transaction Complete - Querys: %i in %0.2f seconds", numQueries, querytime);
}

public void SQLTXNCallback_Error(Database db, float time, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	float querytime = GetEngineTime() - time;
	MyStore_LogMessage(0, LOG_ERROR, "SQLTXNCallback_Error: %s - Querys: %i - FailedIndex: %i after %0.2f seconds", error, numQueries, failIndex, querytime);
}

void SQL_WriteVoucher(int client, char[] voucher, int credits = 0, bool unlimited = false, char[] uniqueID = "")
{
	// steam id
	char steamid[24];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));

	// player name
	char name[64];
	GetClientName(client, name, sizeof(name));
	MyStore_SQLEscape(name);
	MyStore_SQLEscape(voucher);

	int time = GetTime();

	char sQuery[1024];
	Format(sQuery, sizeof(sQuery), "INSERT IGNORE INTO mystore_voucher (voucher, name_of_create, steam_of_create, credits, item, date_of_create, unlimited, date_of_expiration) VALUES ('%s', '%s', '%s', '%i', '%s', '%i', '%i', '%i')", voucher, name, steamid, credits, uniqueID, time, view_as<int>(unlimited), gc_iExpireTime.IntValue == 0 ? 0 : GetTime() + gc_iExpireTime.IntValue*60*60);

	DataPack pack = new DataPack();
	pack.WriteCell(time);
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(credits);
	pack.WriteString(voucher);
	pack.WriteString(uniqueID);

	MyStore_SQLQuery(sQuery, SQLCallback_Write, pack);

}

public void SQLCallback_Write(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();
	int time = pack.ReadCell();

	if (!StrEqual("", error))
	{
		int client = GetClientOfUserId(pack.ReadCell());
		MyStore_LogMessage(client, LOG_ERROR, "SQLCallback_Write: Error: %s", error);
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Creating voucher failed", time);

		FakeClientCommand(client, "play sound/%s", g_sMenuExit);
		delete pack;
		return;
	}

	char sVoucher[64];
	int client = GetClientOfUserId(pack.ReadCell());
	int credits = pack.ReadCell();
	pack.ReadString(sVoucher, sizeof(sVoucher));
	char sUniqueID[64];
	pack.ReadString(sUniqueID, sizeof(sUniqueID));
	delete pack;

	int itemid = MyStore_GetItemIdbyUniqueId(sUniqueID);

	if (itemid == -1)
	{
		Menu_Voucher(client);
		FakeClientCommand(client, "play sound/%s", g_sMenuExit);
		return;
	}

	any item[Item_Data];
	MyStore_GetItem(itemid, item);

	any handler[Type_Handler];
	MyStore_GetHandler(item[iHandler], handler);
	MyStore_RemoveItem(client, itemid);
	Panel_VoucherPurchaseSuccess(client, credits, sVoucher, item[szUniqueId]);
	MyStore_LogMessage(client, LOG_EVENT, "Purchase Voucher: %s", sVoucher);
	if (!credits)
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Item Voucher in chat", item[szName], handler[szType], sVoucher);
	}
	else
	{
		MyStore_SetClientCredits(client, MyStore_GetClientCredits(client) - credits, sVoucher);
		CPrintToChat(client, "%t", "Voucher in chat", sVoucher, credits, g_sCreditsName);
	}

	for (int i = 0; i < 6; i++)
	{
		PrintToConsole(client, "%t", "Voucher in console", sVoucher);
	}
}

void SQL_FetchVoucher(int client, char[] voucher)
{
	MyStore_SQLEscape(voucher);
	StringToUpper(voucher);

	char sQuery[1024];
	Format(sQuery, sizeof(sQuery), 
		"SELECT credits, item, date_of_expiration, date_of_redeem, unlimited, steam_of_redeem FROM mystore_voucher WHERE voucher = '%s'", voucher);

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteString(voucher);

	MyStore_SQLQuery(sQuery, SQLCallback_Fetch, pack);

}

public void SQLCallback_Fetch(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	if (results == null)
	{
		pack.Reset();
		int client = GetClientOfUserId(pack.ReadCell());
		MyStore_LogMessage(client, LOG_ERROR, "SQLCallback_Fetch: Error: %s", error);
	}
	else
	{
		pack.Reset();
		int client = GetClientOfUserId(pack.ReadCell());
		if (!client)
			return;

		char voucher[18];
		pack.ReadString(voucher, sizeof(voucher));
		delete pack;

		if (results.FetchRow())
		{
			// steam id
			char steamid[24];
			if (!GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid)))
				return;

			char sBuffer[64];
			char sItem[64];
			char sRedeems[21845];
			int credits = results.FetchInt(0);
			results.FetchString(1, sItem, sizeof(sItem));
			int date_of_expiration = results.FetchInt(2);
			int date_of_redeem = results.FetchInt(3);
			bool unlimited = view_as<bool>(results.FetchInt(4));
			results.FetchString(5, sRedeems, sizeof(sRedeems));

			if (GetTime() > date_of_expiration && date_of_expiration != 0)
			{
				Menu_Voucher(client);

				FakeClientCommand(client, "play sound/%s", g_sMenuExit);

				FormatTime(sBuffer, sizeof(sBuffer), NULL_STRING, date_of_expiration);
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Voucher expired", sBuffer);
			}
			else if (date_of_redeem > 0 && !unlimited)
			{
				Menu_Voucher(client);

				FakeClientCommand(client, "play sound/%s", g_sMenuExit);

				FormatTime(sBuffer, sizeof(sBuffer), NULL_STRING, date_of_redeem);
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Voucher already redeemed", sBuffer );
			}
			else if (StrContains(sRedeems, steamid[8], true) != -1)
			{
				Menu_Voucher(client);

				FakeClientCommand(client, "play sound/%s", g_sMenuExit);

				CPrintToChat(client, "%s%t", g_sChatPrefix, "You already redeemed Voucher");
			}
			else
			{
				// player name
				char name[64];
				GetClientName(client, name, sizeof(name));
				MyStore_SQLEscape(name);

				char szBuffer[64];

				if (!credits)
				{
					int itemid = MyStore_GetItemIdbyUniqueId(sItem);

					if (itemid == -1)
					{
						Menu_Voucher(client);
						FakeClientCommand(client, "play sound/%s", g_sMenuExit);
						return;
					}

					any item[Item_Data];
					MyStore_GetItem(itemid, item);

					if (MyStore_HasClientItem(client, itemid))
					{
						Menu_Voucher(client);
						CPrintToChat(client, "%s%t", g_sChatPrefix, "You already own Voucher item");
						FakeClientCommand(client, "play sound/%s", g_sMenuExit);
						return;
					}
					else
					{
						MyStore_GiveItem(client, itemid, _, _, item[iPrice]);
						any handler[Type_Handler];

						if (item[bPreview])
						{
							MyStore_GetHandler(item[iHandler], handler);

							Call_StartForward(gf_hPreviewItem);
							Call_PushCell(client);
							Call_PushString(handler[szType]);
							Call_PushCell(item[iDataIndex]);
							Call_Finish();
						}

						CPrintToChat(client, "%s%t", g_sChatPrefix, "Voucher accepted");
						CPrintToChat(client, "%s%t", g_sChatPrefix, "You get x item", item[szName], handler[szType]);

					}
				}
				else
				{
					Format(szBuffer, sizeof(szBuffer), "Voucher: %s", voucher);
					MyStore_SetClientCredits(client, MyStore_GetClientCredits(client) + credits, szBuffer);
					CPrintToChat(client, "%s%t", g_sChatPrefix, "Voucher accepted");
					CPrintToChat(client, "%s%t", g_sChatPrefix, "You get x Credits", credits, g_sCreditsName);
				}

				if (unlimited && (strlen(sRedeems) > 0))
				{
					if (strlen(sRedeems) > 21845 - 22)  // ~1985 player steam ids minus ~2 steam ids
					{
						int iBreak = BreakString(sRedeems, ",", 1);
						strcopy(sRedeems, sizeof(sRedeems), sRedeems[iBreak]);  // remove first redeem :/  not best i know
					}
					Format(sRedeems, sizeof(sRedeems), "%s,%s", sRedeems, steamid[8]);
				}
				else
				{
					Format(sRedeems, sizeof(sRedeems), "%s", steamid[8]);
				}

				char sQuery[1024];
				Format(sQuery, sizeof(sQuery), "UPDATE mystore_voucher SET name_of_redeem = '%s', steam_of_redeem = '%s', date_of_redeem = '%i' WHERE voucher = '%s'", name, sRedeems, GetTime(), voucher);

				MyStore_SQLQuery(sQuery, SQLCallback_Void, 0);

				Panel_VoucherAccept(client, credits, voucher, sItem);

				MyStore_LogMessage(client, LOG_EVENT, "Voucher %s redeemed", voucher);

			}
		}
		else
		{
			Menu_Voucher(client);

			FakeClientCommand(client, "play sound/%s", g_sMenuExit);

			CPrintToChat(client, "%s%t", g_sChatPrefix, "Voucher invalid", voucher);
		}
	}
}

void SQL_CheckVoucher(int client, char[] voucher)
{
	MyStore_SQLEscape(voucher);
	StringToUpper(voucher);

	char sQuery[1024];
	Format(sQuery, sizeof(sQuery),
		"SELECT credits, item, date_of_expiration, date_of_redeem, unlimited, steam_of_redeem FROM mystore_voucher WHERE voucher = '%s'", voucher);

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteString(voucher);

	MyStore_SQLQuery(sQuery, SQLCallback_Check, pack);
}

public void SQLCallback_Check(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	if (results == null)
	{
		pack.Reset();
		int client = GetClientOfUserId(pack.ReadCell());
		MyStore_LogMessage(client, LOG_ERROR, "SQLCallback_Check: Error: %s", error);
	}
	else
	{
		pack.Reset();
		int client = GetClientOfUserId(pack.ReadCell());
		if (!client)
			return;

		char voucher[18];
		pack.ReadString(voucher, sizeof(voucher));
		delete pack;

		if (results.FetchRow())
		{
			// steam id
			char steamid[24];
			GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));

			char sBuffer[256];
			char sItem[64];
			char sRedeems[21845];
			int credits = results.FetchInt(0);
			results.FetchString(1, sItem, sizeof(sItem));
			int date_of_expiration = results.FetchInt(2);
			int date_of_redeem = results.FetchInt(3);
			bool unlimited = view_as<bool>(results.FetchInt(4));
			results.FetchString(5, sRedeems, sizeof(sRedeems));

			Panel panel = new Panel();

			int iCredits = MyStore_GetClientCredits(client); // Get credits

			Format(sBuffer, sizeof(sBuffer), "%t\n%t", "Title Store", g_sName, "Title Credits", g_sCreditsName, iCredits);
			panel.SetTitle(sBuffer);

			panel.DrawText(" ");
			Format(sBuffer, sizeof(sBuffer), "###   %s   ###", voucher);
			panel.DrawText(sBuffer);
			panel.DrawText(" ");
			bool expire = false;
			bool redeemedme = false;
			bool redeemenotunlimited = false;

			if (GetTime() > date_of_expiration && date_of_expiration != 0)
			{
				FakeClientCommand(client, "play sound/%s", g_sMenuExit);

				expire = true;

				FormatTime(sBuffer, sizeof(sBuffer), NULL_STRING, date_of_expiration);
				Format(sBuffer, sizeof(sBuffer), "%t", "Voucher expired", sBuffer);
			}
			else if (StrContains(sRedeems, steamid[8], true) != -1)
			{
				FakeClientCommand(client, "play sound/%s", g_sMenuExit);

				redeemedme = true;

				Format(sBuffer, sizeof(sBuffer), "%t", "You already redeemed Voucher");
			}
			else if (date_of_redeem > 0 && !unlimited)
			{
				FakeClientCommand(client, "play sound/%s", g_sMenuExit);

				redeemenotunlimited = true;

				FormatTime(sBuffer, sizeof(sBuffer), NULL_STRING, date_of_redeem);
				Format(sBuffer, sizeof(sBuffer), "%t", "Voucher already redeemed", sBuffer);
			}
			else
			{
				Format(sBuffer, sizeof(sBuffer), "%t", "Voucher valid");
			}
			panel.DrawText(sBuffer);

			panel.DrawText(" ");

			if (!credits)
			{
				int itemid = MyStore_GetItemIdbyUniqueId(sItem);

				if (itemid == -1)
				{
					Menu_Voucher(client);
					FakeClientCommand(client, "play sound/%s", g_sMenuExit);
					return;
				}

				any item[Item_Data];
				MyStore_GetItem(itemid, item);
				any handler[Type_Handler];
				MyStore_GetHandler(item[iHandler], handler);

				Format(sBuffer, sizeof(sBuffer), "%t %t", "Voucher item", item[szName], handler[szType], unlimited ? "and is unlimited" : "and is limited");
			}
			else
			{
				Format(sBuffer, sizeof(sBuffer), "%t %t", "Voucher Value", credits, g_sCreditsName, unlimited ? "and is unlimited" : "and is limited");
			}
			panel.DrawText(sBuffer);

			if (!expire || redeemedme || !redeemenotunlimited && date_of_expiration != 0)
			{
				FormatTime(sBuffer, sizeof(sBuffer), NULL_STRING, date_of_expiration);
				Format(sBuffer, sizeof(sBuffer), "%t", "Voucher expire", sBuffer);
				panel.DrawText(sBuffer);
			}

			Format(sBuffer, sizeof(sBuffer), "%t", "Back");
			panel.DrawItem(sBuffer);

			panel.Send(client, Handler_NullCancelVoucher, 14); // open info Panel
			delete panel;
		}
		else
		{
			Menu_Voucher(client);

			FakeClientCommand(client, "play sound/%s", g_sMenuExit);

			CPrintToChat(client, "%s%t", g_sChatPrefix, "Voucher invalid", voucher);
		}
	}
}

public void SQLCallback_Void(Database db, DBResultSet results, const char[] error, any data)
{
	if (!StrEqual("", error))
	{
		MyStore_LogMessage(0, LOG_ERROR, "SQLCallback_Void: Error: %s", error);
	}
}

void StringToUpper(char [] sz)
{
	int len = strlen(sz);

	for (int i = 0; i < len; i++)
	{
		if (IsCharLower(sz[i]))
		{
			sz[i] = CharToUpper(sz[i]);
		}
	}
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

	if (result != SMCError_Okay)
	{
		SMC_GetErrorString(result, error, sizeof(error));
		MyStore_LogMessage(0, LOG_ERROR, "ReadCoreCFG: Error: %s on line %i, col %i of %s", error, line, col, sFile);
	}
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

public void Store_OnMenu(Menu &menu, int client, int itemid)
{
	if (!MyStore_HasClientItem(client, itemid) || MyStore_IsItemInBoughtPackage(client, itemid))
		return;

	if (MyStore_IsClientVIP(client))
		return;

	int clientItem[CLIENT_ITEM_SIZE];
	MyStore_GetClientItem(client, itemid, clientItem);

	if (clientItem[PRICE_PURCHASE] <= 0)
		return;

	any item[Item_Data];
	MyStore_GetItem(itemid, item);

	any handler[Type_Handler];
	MyStore_GetHandler(item[iHandler], handler);

	char sBuffer[128];
	if (StrEqual(handler[szType], "package"))
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Package Voucher");
		menu.AddItem("voucher_package", sBuffer, ITEMDRAW_DEFAULT);
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Item Voucher");
		menu.AddItem("voucher_item", sBuffer, ITEMDRAW_DEFAULT);
	}
}

public bool Store_OnHandler(int client, char[] selection, int itemid)
{
	if (strcmp(selection, "voucher_package") == 0 || strcmp(selection, "voucher_item") == 0)
	{
		any item[Item_Data];
		MyStore_GetItem(itemid, item);

		g_iSelectedItem[client] = itemid;

		any handler[Type_Handler];
		MyStore_GetHandler(item[iHandler], handler);

		int clientItem[CLIENT_ITEM_SIZE];
		MyStore_GetClientItem(client, itemid, clientItem);

		if (MyStore_ShouldConfirm())
		{
			char sTitle[128];
			Format(sTitle, sizeof(sTitle), "%t", "Confirm_Voucher", item[szName], handler[szType]);
			MyStore_DisplayConfirmMenu(client, sTitle, Store_OnConfirmHandler, 1);
		}
		else
		{
			VoucherItem(client, itemid);
			MyStore_DisplayPreviousMenu(client);
		}

		return true;
	}

	return false;
}

public void Store_OnConfirmHandler(Menu menu, MenuAction action, int client, int param2)
{
	VoucherItem(client, g_iSelectedItem[client]);
}

void VoucherItem(int client, int itemid)
{
	if (!gc_bEnable.BoolValue)
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Store Disabled");
		return;
	}

	any item[Item_Data];
	MyStore_GetItem(itemid, item);

	char sBuffer[32];
	GenerateVoucherCode(sBuffer, sizeof(sBuffer));
	SQL_WriteVoucher(client, sBuffer, 0, false, item[szUniqueId]);
	g_iLastQuery[client] = GetTime();
}
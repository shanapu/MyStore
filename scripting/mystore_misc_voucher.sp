#include <sourcemod>
#include <sdktools>

#include <mystore>

#include <autoexecconfig>
#include <colors>

#pragma semicolon 1
#pragma newdecls required


/******************************************************************************
                   Variables
******************************************************************************/

#define REDEEM 1
#define CHECK 2
#define NUM 3
#define MIN 4
#define MAX 5
#define PURCHASE 6

ConVar gc_iMySQLCooldown;
ConVar gc_iExpireTime;
ConVar gc_bEnable;

int g_iChatType[MAXPLAYERS + 1] = {-1, ...};

char g_sChatPrefix[32];
char g_sCreditsName[32];
char g_sName[64];
char g_sSQLBuffer[1024]; // todo make non global

char g_sMenuItem[64];
char g_sMenuExit[64];

float g_fInputTime;

Handle g_hTimerInput[MAXPLAYERS+1] = null;

int g_iTempAmount[MAXPLAYERS + 1] = {0, ...};
int g_iCreateNum[MAXPLAYERS + 1] = {0, ...};
int g_iCreateMin[MAXPLAYERS + 1] = {0, ...};
int g_iCreateMax[MAXPLAYERS + 1] = {0, ...};
int g_iLastQuery[MAXPLAYERS + 1] = {0, ...};


public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");
	LoadTranslations("common.phrases");

	RegConsoleCmd("sm_voucher", Command_Voucher, "Open the Voucher main menu");
	RegAdminCmd("sm_createvoucher", Command_CreateVoucherCode, ADMFLAG_ROOT);

	AutoExecConfig_SetFile("vouchers", "MyStore");
	AutoExecConfig_SetCreateFile(true);

	gc_iMySQLCooldown = AutoExecConfig_CreateConVar("myc_mysql_cooldown", "20", "Seconds cooldown between client start database querys (redeem, check & purchase vouchers)", _, true, 5.0);
	gc_iExpireTime = AutoExecConfig_CreateConVar("myc_voucher_expire", "336", "0 - disabled, hours until a voucher expire after creation. 168 = one week", _, true, 1.0);

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	AddCommandListener(Command_Say, "say"); 
	AddCommandListener(Command_Say, "say_team");

	MyStore_RegisterHandler("vouchers", _, _, _, ShowMenu_Voucher, _, false, true);

	MyStore_SQLQuery("CREATE TABLE if NOT EXISTS mystore_voucher (\
					  voucher varchar(64) NOT NULL PRIMARY KEY default '',\
					  name_of_create varchar(64) NOT NULL default '',\
					  steam_of_create varchar(64) NOT NULL default '',\
					  credits INT NOT NULL default 0,\
					  date_of_create INT NOT NULL default 0,\
					  date_of_redeem INT NOT NULL default 0,\
					  name_of_redeem varchar(64) NOT NULL default '',\
					  steam_of_redeem TEXT NOT NULL default '',\
					  unlimited TINYINT NOT NULL default 0,\
					  date_of_expiration INT NOT NULL default 0);",
					  SQLCallback_Void, 0);
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;

	strcopy(g_sName, sizeof(g_sName), name);
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
	strcopy(g_sCreditsName, sizeof(g_sCreditsName), credits);

	g_fInputTime = 12.0; //todo? = time.FloatValue;

	ReadCoreCFG();
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

public void ShowMenu_Voucher(int client, int itemid)
{
	Menu_Voucher(client);
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

	if (MyStore_IsClientAdmin(client))
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Check Voucher");
		menu.AddItem("2", sBuffer);
	}

	Format(sBuffer, sizeof(sBuffer), "%t", "Purchase Voucher");
	menu.AddItem("6", sBuffer);

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
	int iCredits = MyStore_GetClientCredits(client); // Get credits
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


void Panel_VoucherPurchaseSuccess(int client, int credits, char[] voucher)
{
	char sBuffer[255];
	int iCredits = MyStore_GetClientCredits(client); // Get credits
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "Title Store", g_sName, "Title Credits", g_sCreditsName, iCredits);
	panel.SetTitle(sBuffer);

	panel.DrawText(" ");
	Format(sBuffer, sizeof(sBuffer), "%t", "Succesfully purchased voucher");
	panel.DrawText(sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%t", "Voucher Value", credits, g_sCreditsName);
	panel.DrawText(sBuffer);
	panel.DrawText(" ");
	Format(sBuffer, sizeof(sBuffer), "###   %s   ###", voucher);
	panel.DrawText(sBuffer);
	panel.DrawText(" ");
	Format(sBuffer, sizeof(sBuffer), "%t", "Voucher in chat and console");
	panel.DrawText(sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer);

	panel.Send(client, Handler_NullCancelVoucher, 14); // open info Panel
	delete panel;
}


void Panel_VoucherAccept(int client, int credits, char[] voucher)
{
	char sBuffer[255];
	int iCredits = MyStore_GetClientCredits(client); // Get credits
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "Title Store", g_sName, "Title Credits", g_sCreditsName, iCredits);
	panel.SetTitle(sBuffer);

	panel.DrawText(" ");
	Format(sBuffer, sizeof(sBuffer), "%t", "Voucher accepted");
	panel.DrawText(sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%s %i %s", "You have recieved", credits, g_sCreditsName);
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

void SQL_WriteVoucher(int client, char[] voucher, int credits, bool unlimited)
{
	// steam id
	char steamid[24];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));

	// player name
	char name[64];
	GetClientName(client, name, sizeof(name));
	char sanitized_name[64];
	Database Db;
	Db.Escape(name, sanitized_name, sizeof(name));
	Db.Escape(voucher, voucher, 64);

	Format(g_sSQLBuffer, sizeof(g_sSQLBuffer), "INSERT IGNORE INTO mystore_voucher (voucher, name_of_create, steam_of_create, credits, date_of_create, unlimited, date_of_expiration) VALUES ('%s', '%s', '%s', '%i', '%i', '%i', '%i')", voucher, sanitized_name, steamid, credits, GetTime(), view_as<int>(unlimited), gc_iExpireTime.IntValue == 0 ? 0 : GetTime() + gc_iExpireTime.IntValue*60*60);

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(credits);
	pack.WriteString(voucher);

	MyStore_SQLQuery(g_sSQLBuffer, SQLCallback_Write, pack);

}

public void SQLCallback_Write(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	if (!StrEqual("", error))
	{
		pack.Reset();
		int client = GetClientOfUserId(pack.ReadCell());
		MyStore_LogMessage(client, LOG_ERROR, "SQLCallback_Write: Error: %s", error);
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Creating voucher failed");

		FakeClientCommand(client, "play sound/%s", g_sMenuExit);
		delete pack;
		return;
	}

	char sBuffer[64];
	pack.Reset();
	int client = GetClientOfUserId(pack.ReadCell());
	int credits = pack.ReadCell();
	pack.ReadString(sBuffer, sizeof(sBuffer));
	delete pack;

	Panel_VoucherPurchaseSuccess(client, credits, sBuffer);
	Format(sBuffer, sizeof(sBuffer), "Purchase Voucher: %s", sBuffer);
	MyStore_SetClientCredits(client, MyStore_GetClientCredits(client) - credits, sBuffer);
	MyStore_LogMessage(client, LOG_EVENT, "Purchase Voucher: %s", sBuffer);
	CPrintToChat(client, "%t", "Voucher in chat", sBuffer, credits, g_sCreditsName);
	PrintToConsole(client, "%t", "Voucher in console", sBuffer);
}

void SQL_FetchVoucher(int client, char[] voucher)
{
	Database Db;
	Db.Escape(voucher, voucher, 20);
	StringToUpper(voucher);

	Format(g_sSQLBuffer, sizeof(g_sSQLBuffer), 
		"SELECT credits, date_of_expiration, date_of_redeem, unlimited, steam_of_redeem FROM mystore_voucher WHERE voucher = '%s'", voucher);

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteString(voucher);

	MyStore_SQLQuery(g_sSQLBuffer, SQLCallback_Fetch, pack);

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
			char sRedeems[21845];
			int credits = results.FetchInt(0);
			int date_of_expiration = results.FetchInt(1);
			int date_of_redeem = results.FetchInt(2);
			bool unlimited = view_as<bool>(results.FetchInt(3));
			results.FetchString(4, sRedeems, sizeof(sRedeems));

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
				char sanitized_name[64];
				Database Db;
				Db.Escape(name, sanitized_name, sizeof(name));

				char szBuffer[64];
				Format(szBuffer, sizeof(szBuffer), "Voucher: %s", voucher);
				MyStore_SetClientCredits(client, MyStore_GetClientCredits(client) + credits, szBuffer);

				Panel_VoucherAccept(client, credits, voucher);

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

				Format(g_sSQLBuffer, sizeof(g_sSQLBuffer), "UPDATE mystore_voucher SET name_of_redeem = '%s', steam_of_redeem = '%s', date_of_redeem = '%i' WHERE voucher = '%s'", sanitized_name, sRedeems, GetTime(), voucher);

				MyStore_SQLQuery(g_sSQLBuffer, SQLCallback_Void, 0);

				MyStore_LogMessage(client, LOG_EVENT, "Voucher %s redeemed", voucher);

				CPrintToChat(client, "%s%t", g_sChatPrefix, "Voucher accepted");
				CPrintToChat(client, "%s%t", g_sChatPrefix, "You get x Credits", credits, g_sCreditsName);
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
	Database Db;
	Db.Escape(voucher, voucher, 20);

	StringToUpper(voucher);

	Format(g_sSQLBuffer, sizeof(g_sSQLBuffer), 
		"SELECT credits, date_of_expiration, date_of_redeem, unlimited, steam_of_redeem FROM mystore_voucher WHERE voucher = '%s'", voucher);

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteString(voucher);

	MyStore_SQLQuery(g_sSQLBuffer, SQLCallback_Check, pack);
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
			char sRedeems[21845];
			int credits = results.FetchInt(0);
			int date_of_expiration = results.FetchInt(1);
			int date_of_redeem = results.FetchInt(2);
			bool unlimited = view_as<bool>(results.FetchInt(3));
			results.FetchString(4, sRedeems, sizeof(sRedeems));

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

			Format(sBuffer, sizeof(sBuffer), "%t %t", "Voucher Value", credits, g_sCreditsName, unlimited ? "and is unlimited" : "and is limited");
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
// idea https://forums.alliedmods.net/showthread.php?t=312422

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

#include <mystore>

#include <colors>
#include <autoexecconfig>

#pragma semicolon 1
#pragma newdecls required

ConVar gc_bEnable;

char g_sCreditsName[64];
char g_sChatPrefix[128];
char g_sName[64];

char g_sMenuItem[64];
char g_sMenuExit[64];

char g_sPersonalRefCode[MAXPLAYERS + 1][18];
char g_sRefBy[MAXPLAYERS + 1][32];
int g_iEarnings[MAXPLAYERS + 1] = {0, ...};

int g_iPage[MAXPLAYERS + 1];
int g_iList[MAXPLAYERS + 1];
int g_iUpdateTime;

#define TL_CREDITS 0
#define TL_ITEMS 1
#define TL_INV 2
#define TL_INV_CREDITS 3
ArrayList g_aReferrals[4];

public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");

	RegConsoleCmd("sm_referrals", Command_Referrals);

	AutoExecConfig_SetFile("referrals", "MyStore");
	AutoExecConfig_SetCreateFile(true);

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	ReadCoreCFG();

	MyStore_RegisterHandler("referrals", Referrals_OnMapStart, _, _, Referrals_Menu, _, false, true);

	MyStore_SQLQuery("CREATE TABLE if NOT EXISTS mystore_referral (\
					  player_id INT NOT NULL default 0,\
					  ref_code varchar(18) NOT NULL default '',\
					  ref_by INT NOT NULL default 0,\
					  ref_reward INT NOT NULL default 0);",
					  SQLCallback_Void, 0);
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
	strcopy(g_sCreditsName, sizeof(g_sCreditsName), credits);
	strcopy(g_sName, sizeof(g_sName), name);
}

public void Referrals_Menu(int client, int itemid)
{
	Panel_Credits(client);
}

public Action Command_Referrals(int client, int args)
{
	//Buisness as usual
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

	Panel_Credits(client);

	return Plugin_Handled;
}


void Panel_Credits(int client, int type)
{
	Panel panel = new Panel();

	char sName[64];
	char sBuffer[64];

	int iCredits = MyStore_GetClientCredits(client); // Get credits

	//Display title
	Format(sBuffer, sizeof(sBuffer), "%t - %s\n%t", "Title Store", g_sName, "referrals", "Title Credits", g_sCreditsName, iCredits);
	panel.SetTitle(sBuffer);

	panel.DrawText(" ");

	panel.DrawText("    Your ref code: %s", g_sPersonalRefCode[client]);

	panel.DrawText(" ");

	panel.CurrentKey = 1;
	Format(sBuffer, sizeof(sBuffer), "%s", "Print code to chat/console"); // todo translate
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);

	panel.CurrentKey = 2;
	Format(sBuffer, sizeof(sBuffer), "%s", "Your referrals"); // todo translate
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);

	if (!g_sRefBy[client][0])
	{
		panel.CurrentKey = 3;
		Format(sBuffer, sizeof(sBuffer), "%s", "Redeem referrals"); // todo translate
		panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "     Refed by %s", g_sRefBy[client]); // todo translate
		panel.DrawText(sBuffer);
	}

	panel.DrawText("    Earnigs %i %s", g_iEarnings, g_sCreditsName);
	panel.DrawText(" ");

	panel.CurrentKey = 7;
	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);

	panel.CurrentKey = 9;
	Format(sBuffer, sizeof(sBuffer), "%t", "Exit");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	panel.Send(client, Handler_Credits, MENU_TIME_FOREVER);

	delete panel;
}

public int Handler_Credits(Menu panel, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		switch(itemNum)
		{
			//Back
			case 7:
			{
				FakeClientCommand(client, "play sound/%s", g_sMenuExit);
				switch(g_iPage[client])
				{
					//On first page? go back to toplists menu
					case 0:
					{
						Menu_Referrals(client);
					}
					//Not on first page? go page back
					default:
					{
						g_iPage[client] -= 5;
						Panel_Credits(client, g_iList[client]);
					}
				}
			}
			//Display Next page
			case 8:
			{
					g_iPage[client] += 5;
					Panel_Credits(client, g_iList[client]);
					FakeClientCommand(client, "play sound/%s", g_sMenuItem);
			}
			//Close, reset page
			case 9:
			{
				g_iPage[client] = 0;
				FakeClientCommand(client, "play sound/%s", g_sMenuExit);
			}
		}
	}

	delete panel;
}

//Call for the menu sounds from sourcemods core.cfg for the panel keys
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

//Get & check callback keyvalues from core.cfg
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

public void SQLTXNCallback_Success(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	//Loop through the results array for all types of toplists
	for (int i = 0; i < numQueries; i++)
	{
		if (results[i] == null)
		{
			MyStore_LogMessage(0, LOG_ERROR, "SQLTXNCallback_Success: Error: No results for toplist #%i", i);
		}
		else
		{
			char sName[64];

			// Delete the DataPacks & clear the ArrayList
			if (g_aReferrals[i].Length > 0)
			{
				for (int j = 0; j < g_aReferrals[i].Length; j++)
				{
					DataPack pack = g_aReferrals[i].Get(j);
					delete pack;
				}
			}
			g_aReferrals[i].Clear();

			//Loop through the result rows and write them into DataPacks
			while(results[i].FetchRow())
			{
				DataPack pack = new DataPack();

				results[i].FetchString(0, sName, sizeof(sName));
				pack.WriteCell(results[i].FetchInt(1));
				pack.WriteString(sName);
				if (i > 1)
				{
					pack.WriteCell(results[i].FetchInt(2));
				}

				//Push these DataPacks to ArrayList
				g_aReferrals[i].Push(pack);
			}
		}
	}
}
//Format integer of N seconds into string of n hours, n minutes & n seconds
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

bool GenerateRefCode(char[] sBuffer, int maxlen)
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
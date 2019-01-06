#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <mystore>

#include <colors>
#include <autoexecconfig>

ConVar gc_bEnable;

ConVar gc_iGiveaway;

char g_sChatPrefix[128];
char g_sCreditsName[64];
int g_iSelectedItem;

ArrayList g_aParticipate;


public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");

	RegAdminCmd("sm_giveaway", Command_GiveAway, ADMFLAG_BAN, "");
	RegConsoleCmd("sm_jackpot", Command_Raffle, "");

	AutoExecConfig_SetFile("giveaway", "MyStore");
	AutoExecConfig_SetCreateFile(true);

	gc_iGiveaway = AutoExecConfig_CreateConVar("mystore_enable_giveaways", "2", "Enable/disable giveawaying of already bought items. [1 = everyone, 2 = admins only]", _, true, 1.0, true, 2.0);

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	g_aParticipate = new ArrayList();
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
	strcopy(g_sCreditsName, sizeof(g_sCreditsName), credits);
}

public Action Command_Raffle(int client, int args)
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

	if (g_iSelectedItem > -1)
	{
		CReplyToCommand(client, "%s%s", g_sChatPrefix, "No active giveaway to participate"); //todo translate

		return Plugin_Handled;
	}

	if (MyStore_HasClientItem(client, g_iSelectedItem) && g_iSelectedItem != -2) //g_iSelectedItem != -2 = credits
	{
		CReplyToCommand(client, "%s%s", g_sChatPrefix, "You already own the item"); //todo translate

		return Plugin_Handled;
	}

	int index = g_aParticipate.FindValue(client);
	if (index != -1)
	{
		if (index != 0)
		{
			CReplyToCommand(client, "%s%s", g_sChatPrefix, "You already participate"); //todo translate
		}
		else
		{
			//ShowGiveawayMenu(client);
		}

		return Plugin_Handled;
	}

	g_aParticipate.Push(client);

	CPrintToChatAll("%s%N participate on the giveaway!", g_sChatPrefix, client);

	return Plugin_Handled;
}

public Action Command_GiveAway(int client, int args)
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

	if (g_iSelectedItem > -1)
	{
		//ShowGiveawayMenu(client);
		CReplyToCommand(client, "%s%s", g_sChatPrefix, "Already a giveaway running"); //todo translate

		return Plugin_Handled;
	}

	if (args != 1)
	{
		CReplyToCommand(client, "%s%t", g_sChatPrefix, "Type in chat !giveaway [random/creditsamount]");

		return Plugin_Handled;
	}

	char sBuffer[32];
	GetCmdArg(1, sBuffer, 32);

	if (sBuffer[0] == 'r')
	{
		g_iSelectedItem = GetRandomItemID();
	}
	else if (IsCharNumeric(sBuffer[0]))
	{
		g_iSelectedItem = -2;
		
	}

	g_aParticipate.Clear();
	g_aParticipate.Push(client); //Starter is index 0 in array

	CPrintToChatAll("%s%N participate on the giveaway!", g_sChatPrefix, client);

	return Plugin_Handled;
}

public void OnAllPluginsLoaded()
{
	MyStore_RegisterItemHandler("giveaway", Store_OnMenu, Store_OnHandler);
}

public void Store_OnMenu(Menu &menu, int client, int itemid)
{
	if (g_iSelectedItem != -1)
		return;

	if (!MyStore_IsClientAdmin(client) || MyStore_IsClientVIP(client))
		return;

	any item[Item_Data];
	MyStore_GetItem(itemid, item);

	any handler[Type_Handler];
	MyStore_GetHandler(item[iHandler], handler);

	char sBuffer[128];
	if (StrEqual(handler[szType], "package"))
	{
		Format(sBuffer, sizeof(sBuffer), "%s", "Package Giveaway"); // todo translate
		menu.AddItem("giveaway_package", sBuffer, ITEMDRAW_DEFAULT);
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "%s", "Item Giveaway");
		menu.AddItem("giveaway_package", sBuffer, ITEMDRAW_DEFAULT);
	}
}

public bool Store_OnHandler(int client, char[] selection, int itemid)
{
	if (strcmp(selection, "giveaway_package") == 0|| strcmp(selection, "giveaway_package") == 0)
	{
		any item[Item_Data];
		MyStore_GetItem(itemid, item);

		any handler[Type_Handler];
		MyStore_GetHandler(item[iHandler], handler);

		g_aParticipate.Clear();
		g_aParticipate.Push(client); //Starter is index 0 in array

		g_iSelectedItem = itemid;

		CPrintToChatAll("%s%N started a Giveaway for %s %s", g_sChatPrefix, handler[szName], item[szName]);
		CPrintToChatAll("%sType !raffle in chat to participate"); // todo translate

		//magic
		MyStore_LogMessage(client, LOG_ADMIN, "Started giveaway for item: %s %s", handler[szName], item[szName]);

		return true;
	}

	return false;
}
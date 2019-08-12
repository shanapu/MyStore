/*
 * MyStore - Gift module
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
#include <sdkhooks>

#include <mystore> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/mystore.inc

#include <colors> //https://raw.githubusercontent.com/shanapu/MyStore/master/scripting/include/colors.inc
#include <autoexecconfig> //https://raw.githubusercontent.com/Impact123/AutoExecConfig/development/autoexecconfig.inc

ConVar gc_bEnable;

ConVar gc_iGift;

char g_sChatPrefix[128];
char g_sCreditsName[64];
int g_iSelectedItem[MAXPLAYERS + 1];

/*
 * Build date: <DATE>
 * Build number: <BUILD>
 * Commit: https://github.com/shanapu/MyStore/commit/<COMMIT>
 */

public Plugin myinfo = 
{
	name = "MyStore - Gift module",
	author = "shanapu",
	description = "",
	version = "0.1.<BUILD>",
	url = "github.com/shanapu/MyStore"
};

public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");

	AutoExecConfig_SetFile("gift", "sourcemod/mystore");
	AutoExecConfig_SetCreateFile(true);

	gc_iGift = AutoExecConfig_CreateConVar("mystore_enable_gifting", "1", "Enable/disable gifting of already bought items. [1 = everyone, 2 = admins only]", _, true, 1.0, true, 2.0);

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
	strcopy(g_sCreditsName, sizeof(g_sCreditsName), credits);
}

public void OnAllPluginsLoaded()
{
	MyStore_RegisterItemHandler("gift", Store_OnMenu, Store_OnHandler);
}

public void Store_OnMenu(Menu &menu, int client, int itemid)
{
	if (gc_iGift.IntValue < 1 || (gc_iGift.IntValue == 2 && !MyStore_IsClientAdmin(client)))
		return;

	if (!MyStore_HasClientItem(client, itemid) || MyStore_IsItemInBoughtPackage(client, itemid))
		return;

	if (MyStore_IsClientVIP(client))
		return;

	any item[Item_Data];
	MyStore_GetItem(itemid, item);

	int clientItem[CLIENT_ITEM_SIZE];
	MyStore_GetClientItem(client, itemid, clientItem);

	if (clientItem[PRICE_PURCHASE] <= 0)
		return;

	any handler[Type_Handler];
	MyStore_GetHandler(item[iHandler], handler);

	char sBuffer[128];
	if (StrEqual(handler[szType], "package"))
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Package Gift");
		menu.AddItem("gift_package", sBuffer, ITEMDRAW_DEFAULT);
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Item Gift");
		menu.AddItem("gift_package", sBuffer, ITEMDRAW_DEFAULT);
	}
}


public bool Store_OnHandler(int client, char[] selection, int itemid)
{
	if (strcmp(selection, "gift_package") == 0|| strcmp(selection, "gift_package") == 0)
	{
		any item[Item_Data];
		MyStore_GetItem(itemid, item);

		g_iSelectedItem[client] = itemid;

		int iCount = 0;
		Menu menu = new Menu(MenuHandler_Gift);
		menu.ExitBackButton = true;
		menu.SetTitle("%t\n%t", "Title Gift", "Title Credits", g_sCreditsName, MyStore_GetClientCredits(client));

		char sID[11];
		char sBuffer[64];

		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i))
				continue;

			int iFlags = GetUserFlagBits(i);
			if (!CheckFlagBits(i, item[iFlagBits], iFlags))
				continue;

			if (i != client && IsClientInGame(i) && !MyStore_HasClientItem(i, itemid))
			{
				IntToString(GetClientUserId(i), sID, sizeof(sID));
				Format(sBuffer, sizeof(sBuffer), "%N", i);
				menu.AddItem(sID, sBuffer);
				iCount++;
			}
		}

		if (iCount == 0)
		{
			menu.Cancel();
			MyStore_SetClientPreviousMenu(client, MENU_ITEM);
			MyStore_DisplayPreviousMenu(client);
			CPrintToChat(client, "%s%t", g_sChatPrefix, "Gift No Players");
		}
		else
		{
			menu.Display(client, MENU_TIME_FOREVER);
		}

		return true;
	}

	return false;
}

public int MenuHandler_Gift(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_End)
	{
		menu.Cancel();
	}
	else if (action == MenuAction_Select)
	{
		int iReceiver;

		// Confirmation was given
		if (menu == null)
		{
			iReceiver = GetClientOfUserId(param2);
			if (!iReceiver)
			{
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Gift Player Left");
				return;
			}
			GiftItem(client, iReceiver, g_iSelectedItem[client]);
			MyStore_DisplayPreviousMenu(client);
		}
		else
		{
			char sId[11];
			menu.GetItem(param2, sId, sizeof(sId));

			int iIndex = StringToInt(sId);
			iReceiver = GetClientOfUserId(iIndex);
			if (!iReceiver)
			{
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Gift Player Left");
				return;
			}

			if (MyStore_ShouldConfirm())
			{
				char sTitle[128];
				any item[Item_Data];
				MyStore_GetItem(g_iSelectedItem[client], item);
				any handler[Type_Handler];
				MyStore_GetHandler(item[iHandler], handler);
				Format(sTitle, sizeof(sTitle), "%t", "Confirm_Gift", item[szName], handler[szType], iReceiver);
				MyStore_DisplayConfirmMenu(client, sTitle, MenuHandler_Gift, iIndex);
				return;
			}
			else
			{
				GiftItem(client, iReceiver, g_iSelectedItem[client]);
			}

			MyStore_DisplayPreviousMenu(client);
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

void GiftItem(int client, int receiver, int itemid)
{
	if (!gc_bEnable.BoolValue)
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Store Disabled");
		return;
	}

	any item[Item_Data];
	MyStore_GetItem(itemid, item);

	any handler[Type_Handler];
	MyStore_GetHandler(item[iHandler], handler);

	MyStore_TransferClientItem(client, receiver, itemid);

	CPrintToChat(client, "%s%t", g_sChatPrefix, "Chat Gift Item Sent", receiver, item[szName], handler[szType]);
	CPrintToChat(receiver, "%s%t", g_sChatPrefix, "Chat Gift Item Received", client, item[szName], handler[szType]);

	MyStore_LogMessage(client, LOG_EVENT, "Gifted a %s to %N", item[szName], receiver);
}


bool CheckFlagBits(int client, int flagsNeed, int flags = -1)
{
	if (flags==-1)
	{
		flags = GetUserFlagBits(client);
	}

	if (flagsNeed == 0 || flags & flagsNeed || flags & ADMFLAG_ROOT)
	{
		return true;
	}

	return false;
}

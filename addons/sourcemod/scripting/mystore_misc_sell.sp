/*
 * MyStore - Sell module
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

ConVar gc_bSellEnabled;
ConVar gc_fSellRatio;

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
	name = "MyStore - Sell module",
	author = "shanapu", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "",
	version = "0.1.<BUILD>", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = "github.com/shanapu/MyStore"
};

public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");

	AutoExecConfig_SetFile("sell", "sourcemod/mystore");
	AutoExecConfig_SetCreateFile(true);

	gc_bSellEnabled = AutoExecConfig_CreateConVar("mystore_enable_selling", "1", "Enable/disable selling of already bought items.", _, true, 0.0, true, 1.0);

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	AutoExecConfig_SetFile("core", "sourcemod/mystore");
	AutoExecConfig_SetCreateFile(true);

	gc_fSellRatio = AutoExecConfig_CreateConVar("mystore_sell_ratio", "0.60", "Ratio of the original price to get for selling an item.", _, true, 0.0, true, 1.0);

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
	if (MyStore_RegisterItemHandler("sell", Store_OnMenu, Store_OnHandler) == -1)
	{
		SetFailState("Can't Register module to core - Reached max item handlers(%i).", STORE_MAX_ITEM_HANDLERS);
	}
}

public void Store_OnMenu(Menu &menu, int client, int itemid)
{
	if (!gc_bSellEnabled.BoolValue)
		return;

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
		Format(sBuffer, sizeof(sBuffer), "%t", "Package Sell", RoundToFloor(clientItem[PRICE_PURCHASE] * gc_fSellRatio.FloatValue), g_sCreditsName);
		menu.AddItem("sell_package", sBuffer, ITEMDRAW_DEFAULT);
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Item Sell", RoundToFloor(clientItem[PRICE_PURCHASE] * gc_fSellRatio.FloatValue), g_sCreditsName);
		menu.AddItem("sell_item", sBuffer, ITEMDRAW_DEFAULT);
	}
}

public bool Store_OnHandler(int client, char[] selection, int itemid)
{
	if (strcmp(selection, "sell_package") == 0 || strcmp(selection, "sell_item") == 0)
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
			Format(sTitle, sizeof(sTitle), "%t", "Confirm_Sell", item[szName], handler[szType], RoundToFloor(clientItem[PRICE_PURCHASE] * gc_fSellRatio.FloatValue));
			MyStore_DisplayConfirmMenu(client, sTitle, Store_OnConfirmHandler, 1);
		}
		else
		{
			SellItem(client, itemid);
			MyStore_DisplayPreviousMenu(client);
		}

		return true;
	}

	return false;
}

public void Store_OnConfirmHandler(Menu menu, MenuAction action, int client, int param2)
{
	SellItem(client, g_iSelectedItem[client]);
	MyStore_DisplayPreviousMenu(client);
}

void SellItem(int client, int itemid)
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

	MyStore_SellClientItem(client, itemid, gc_fSellRatio.FloatValue);
}
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#include <mystore>

char g_sInfoTitle[STORE_MAX_ITEMS][256];
char g_sInfo[STORE_MAX_ITEMS][256];

int g_iCount = 0;

public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");

	MyStore_RegisterHandler("info", _, Info_Reset, Info_Config, Info_Equip, _, false, true);
}

public void Info_Reset()
{
	g_iCount = 0;
}

public bool Info_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, g_iCount);

	kv.GetSectionName(g_sInfoTitle[g_iCount], sizeof(g_sInfoTitle[]));
	kv.GetString("text", g_sInfo[g_iCount], sizeof(g_sInfo[]));

	ReplaceString(g_sInfo[g_iCount], sizeof(g_sInfo[]), "\\n", "\n");

	g_iCount++;

	return true;
}

public void Info_Equip(int client, int itemid)
{
	int iIndex = MyStore_GetDataIndex(itemid);

	Panel panel = new Panel();
	panel.SetTitle(g_sInfoTitle[iIndex]);

	panel.DrawText(g_sInfo[iIndex]);

	char sBuffer[64];
	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.CurrentKey = 7;
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	panel.DrawItem("", ITEMDRAW_SPACER);
	Format(sBuffer, sizeof(sBuffer), "%t", "Exit");
	panel.CurrentKey = 9;
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);

	panel.Send(client, PanelHandler_Info, MENU_TIME_FOREVER);
}

public int PanelHandler_Info(Handle menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		if (param2 == 7)
		{
			MyStore_DisplayPreviousMenu(client);
		}
	}
}
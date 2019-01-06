#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#include <mystore>

#include <colors>
#include <chat-processor>

char g_sNameTags[STORE_MAX_ITEMS][MAXLENGTH_NAME];
char g_sNameColors[STORE_MAX_ITEMS][32];
char g_sMessageColors[STORE_MAX_ITEMS][32];

ConVar gc_bEnable;

int g_iNameTags = 0;
int g_iNameColors = 0;
int g_iMessageColors = 0;

public void OnPluginStart()
{
	MyStore_RegisterHandler("nametag", _, CPSupport_Reset, NameTags_Config, CPSupport_Equip, CPSupport_Remove, true);
	MyStore_RegisterHandler("namecolor", _, CPSupport_Reset, NameColors_Config, CPSupport_Equip, CPSupport_Remove, true);
	MyStore_RegisterHandler("msgcolor", _, CPSupport_Reset, MsgColors_Config, CPSupport_Equip, CPSupport_Remove, true);
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
}

public void CPSupport_Reset()
{
	g_iNameTags = 0;
	g_iNameColors = 0;
	g_iMessageColors = 0;
}

public bool NameTags_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, g_iNameTags);
	kv.GetString("tag", g_sNameTags[g_iNameTags], sizeof(g_sNameTags[]));
	g_iNameTags++;

	return true;
}

public bool NameColors_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, g_iNameColors);
	kv.GetString("color", g_sNameColors[g_iNameColors], sizeof(g_sNameColors[]));
	g_iNameColors++;

	return true;
}

public bool MsgColors_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, g_iMessageColors);
	kv.GetString("color", g_sMessageColors[g_iMessageColors], sizeof(g_sMessageColors[]));
	g_iMessageColors++;

	return true;
}

public int CPSupport_Equip(int client, int itemid)
{
	return ITEM_EQUIP_SUCCESS;
}

public int CPSupport_Remove(int client, int itemid)
{
	return ITEM_EQUIP_REMOVE;
}

public Action CP_OnChatMessage(int& author, ArrayList recipients, char[] flagstring, char[] name, char[] message, bool& processcolors, bool& removecolors)
{
	if (!gc_bEnable.BoolValue)
		return Plugin_Continue;

	int iEquippedNameTag = MyStore_GetEquippedItem(author, "nametag");
	int iEquippedNameColor = MyStore_GetEquippedItem(author, "namecolor");
	int iEquippedMsgColor = MyStore_GetEquippedItem(author, "msgcolor");

	if (iEquippedNameTag < 0 && iEquippedNameColor < 0 && iEquippedMsgColor < 0)
		return Plugin_Continue;

	char sName[MAXLENGTH_NAME*2];
	char sNameTag[MAXLENGTH_NAME];
	char sNameColor[32];

	if (iEquippedNameTag >= 0)
	{
		int iNameTag = MyStore_GetDataIndex(iEquippedNameTag);
		strcopy(sNameTag, sizeof(sNameTag), g_sNameTags[iNameTag]);
	}

	if (iEquippedNameColor >= 0)
	{
		int iNameColor = MyStore_GetDataIndex(iEquippedNameColor);
		strcopy(sNameColor, sizeof(sNameColor), g_sNameColors[iNameColor]);
	}

	Format(sName, sizeof(sName), "%s%s%s", sNameTag, sNameColor, name);

	CFormat(sName, sizeof(sName));

	strcopy(name, MAXLENGTH_NAME, sName);

	if (iEquippedMsgColor >= 0)
	{
		char sMessage[MAXLENGTH_BUFFER];
		strcopy(sMessage, sizeof(sMessage), message);
		Format(message, MAXLENGTH_BUFFER, "%s%s", g_sMessageColors[MyStore_GetDataIndex(iEquippedMsgColor)], sMessage);
		CFormat(message, MAXLENGTH_BUFFER);
	}

	return Plugin_Changed;
}
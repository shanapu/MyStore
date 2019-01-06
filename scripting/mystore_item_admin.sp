#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#include <mystore>

char g_sFlags[STORE_MAX_ITEMS][32];
GroupId g_gGroup[STORE_MAX_ITEMS];
int g_iImmunity[STORE_MAX_ITEMS];

int g_iCount = 0;

public void OnPluginStart()
{
	MyStore_RegisterHandler("admin", _, AdminGroup_Reset, AdminGroup_Config, AdminGroup_Equip, _, true);
}

public void AdminGroup_Reset()
{
	g_iCount = 0;
}

public bool AdminGroup_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, g_iCount);

	char sBuffer[64];
	kv.GetString("flags", g_sFlags[g_iCount], 32);
	kv.GetString("group", sBuffer, sizeof(sBuffer));

	g_gGroup[g_iCount] = FindAdmGroup(sBuffer);
	g_iImmunity[g_iCount] = kv.GetNum("immunity");

	g_iCount++;

	return true;
}

public int AdminGroup_Equip(int client, int itemid)
{
	int iIndex = MyStore_GetDataIndex(itemid);

	AdminId aAdmin = GetUserAdmin(client);
	if (aAdmin == INVALID_ADMIN_ID)
	{
		aAdmin = CreateAdmin();
		SetUserAdmin(client, aAdmin);
	}

	if (g_gGroup[iIndex] != INVALID_GROUP_ID)
	{
		AdminInheritGroup(aAdmin, g_gGroup[iIndex]);
	}

	if (GetAdminImmunityLevel(aAdmin) < g_iImmunity[iIndex])
	{
		SetAdminImmunityLevel(aAdmin, g_iImmunity[iIndex]);
	}

	AdminFlag aFlag;
	char sBuffer[32];
	strcopy(sBuffer, sizeof(sBuffer), g_sFlags[iIndex]);

	for (int i = 0; i < strlen(sBuffer); i++)
	{
		if (!FindFlagByChar(sBuffer[i], aFlag))
			continue;

		SetAdminFlag(aAdmin, aFlag, true);
	}

	RunAdminCacheChecks(client);

	return ITEM_EQUIP_SUCCESS;
}
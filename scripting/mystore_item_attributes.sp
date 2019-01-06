#include <sourcemod>
#include <sdktools>

#include <mystore>

#include <colors>

ConVar gc_bEnable;

public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");

	HookEvent("player_spawn", Event_PlayerSpawn);
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
}

public void MyStore_OnItemEquipt(int client, int itemid)
{
	if (!client || !IsClientInGame(client) || !IsPlayerAlive(client))
		return;

	any item[Item_Data];
	char sValue[32];

	MyStore_GetItem(itemid, item);

	if (item[hAttributes] == null)
		return;

	if (item[hAttributes].GetString("health", sValue, sizeof(sValue)))
	{
		SetEntityHealth(client, GetClientHealth(client) + StringToInt(sValue));
	}

	if (item[hAttributes].GetString("gravity", sValue, sizeof(sValue)))
	{
		SetEntityGravity(client, StringToFloat(sValue));
	}

	if (item[hAttributes].GetString("money", sValue, sizeof(sValue)))
	{
		SetEntProp(client, Prop_Send, "m_iAccount", GetEntProp(client, Prop_Send, "m_iAccount") + StringToInt(sValue));
	}

	if (item[hAttributes].GetString("armor", sValue, sizeof(sValue)))
	{
		SetEntProp(client, Prop_Send, "m_ArmorValue", GetEntProp(client, Prop_Send, "m_ArmorValue") + StringToInt(sValue));
	}

	if (item[hAttributes].GetString("speed", sValue, sizeof(sValue)))
	{
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", StringToFloat(sValue));
	}

	if (item[hAttributes].GetString("items", sValue, sizeof(sValue)))
	{
		if (sValue[0])
		{
			int iCount = 0;
			char siItem[12][32];
			iCount = ExplodeString(sValue, ",", siItem, sizeof(siItem), sizeof(siItem[]));

			for (int i = 0; i < iCount; i++)
			{
				GivePlayerItem(client, siItem[i]);
			}
		}
	}

	if (item[hAttributes].GetString("command", sValue, sizeof(sValue)))
	{
		if (!sValue[0])
			return;

		char sCommand[256];
		strcopy(sCommand, sizeof(sCommand), sValue);

		char sClientID[11];
		char sUserID[11];
		char sSteamID[32] = "\"";
		char sName[66] = "\"";

		IntToString(client, sClientID, sizeof(sClientID));
		IntToString(GetClientUserId(client), sUserID, sizeof(sUserID));
		GetClientAuthId(client, AuthId_Steam2, sSteamID[1], sizeof(sSteamID)-1);
		GetClientName(client, sName[1], sizeof(sName)-1);

		sSteamID[strlen(sSteamID)] = '"';
		sName[strlen(sName)] = '"';

		ReplaceString(sCommand, sizeof(sCommand), "{clientid}", sClientID);
		ReplaceString(sCommand, sizeof(sCommand), "{userid}", sUserID);
		ReplaceString(sCommand, sizeof(sCommand), "{steamid}", sSteamID);
		ReplaceString(sCommand, sizeof(sCommand), "{name}", sName);

		ServerCommand("%s", sCommand);
	}
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!gc_bEnable.BoolValue)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!client || !IsClientInGame(client) || !IsPlayerAlive(client))
		return;

	// Reset client
	SetEntityGravity(client, 1.0);

	int idx = -1;
	int item_idx = -1;
	any item[Item_Data];
	char sValue[32];

	while((item_idx = MyStore_IterateEquippedItems(client, idx, true)) != -1)
	{
		MyStore_GetItem(item_idx, item);

		if (item[hAttributes] == null)
			return;

		if (item[hAttributes].GetString("health", sValue, sizeof(sValue)))
		{
			SetEntityHealth(client, GetClientHealth(client) + StringToInt(sValue));
		}

		if (item[hAttributes].GetString("money", sValue, sizeof(sValue)))
		{
			SetEntProp(client, Prop_Send, "m_iAccount", GetEntProp(client, Prop_Send, "m_iAccount") + StringToInt(sValue));
		}

		if (item[hAttributes].GetString("gravity", sValue, sizeof(sValue)))
		{
			SetEntityGravity(client, StringToFloat(sValue));
		}

		if (item[hAttributes].GetString("armor", sValue, sizeof(sValue)))
		{
			SetEntProp(client, Prop_Send, "m_ArmorValue", GetEntProp(client, Prop_Send, "m_ArmorValue") + StringToInt(sValue));
		}

		if (item[hAttributes].GetString("speed", sValue, sizeof(sValue)))
		{
			SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", StringToFloat(sValue));
		}

		if (item[hAttributes].GetString("items", sValue, sizeof(sValue)))
		{
			if (sValue[0])
			{
				int iCount = 0;
				char siItem[12][32];
				iCount = ExplodeString(sValue, ",", siItem, sizeof(siItem), sizeof(siItem[]));

				for (int i = 0; i < iCount; i++)
				{
					GivePlayerItem(client, siItem[i]);
				}
			}
		}

		if (item[hAttributes].GetString("command", sValue, sizeof(sValue)))
		{
			if (!sValue[0])
				return;

			char sCommand[256];
			strcopy(sCommand, sizeof(sCommand), sValue);

			char sClientID[11];
			char sUserID[11];
			char sSteamID[32] = "\"";
			char sName[66] = "\"";

			IntToString(client, sClientID, sizeof(sClientID));
			IntToString(GetClientUserId(client), sUserID, sizeof(sUserID));
			GetClientAuthId(client, AuthId_Steam2, sSteamID[1], sizeof(sSteamID)-1);
			GetClientName(client, sName[1], sizeof(sName)-1);

			sSteamID[strlen(sSteamID)] = '"';
			sName[strlen(sName)] = '"';

			ReplaceString(sCommand, sizeof(sCommand), "{clientid}", sClientID);
			ReplaceString(sCommand, sizeof(sCommand), "{userid}", sUserID);
			ReplaceString(sCommand, sizeof(sCommand), "{steamid}", sSteamID);
			ReplaceString(sCommand, sizeof(sCommand), "{name}", sName);

			ServerCommand("%s", sCommand);
		}
	}
}
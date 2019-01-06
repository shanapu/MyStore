// https://forums.alliedmods.net/showthread.php?t=297516

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <mystore>

#include <autoexecconfig>

ConVar gc_bEnable;

bool g_bEquipt[MAXPLAYERS + 1] = false;
int ClientCamera[MAXPLAYERS+1];



public void OnPluginStart()
{
	LoadTranslations("mystore.phrases");

	AutoExecConfig_SetFile("items", "MyStore");
	AutoExecConfig_SetCreateFile(true);

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	MyStore_RegisterHandler("death_effect", _, _, DeathEffect_Config, DeathEffect_Equip, _, true);

	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
}

public void OnMapStart()
{
	PrecacheModel("models/blackout.mdl", true);
}

public void MyStore_OnConfigExecuted(ConVar enable, char[] name, char[] prefix, char[] credits)
{
	gc_bEnable = enable;
}

public bool DeathEffect_Config(KeyValues &kv, int itemid)
{
	MyStore_SetDataIndex(itemid, 0);

	return true;
}

public int DeathEffect_Equip(int client, int itemid)
{
	g_bEquipt[client] = true;

	return ITEM_EQUIP_SUCCESS;
}

public int DeathEffect_Remove(int client, int itemid)
{
	g_bEquipt[client] = false;

	return ITEM_EQUIP_REMOVE;
}


public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!gc_bEnable.BoolValue)
		return;

	int victim = GetClientOfUserId(event.GetInt("userid"));

	if (!IsValidClient(victim))
		return;

	if (!g_bEquipt[victim])
		return;

	int ragdoll = GetEntPropEnt(victim, Prop_Send, "m_hRagdoll");
	if (ragdoll < 0)
		return;

	SpawnCam(victim, ragdoll);
}

bool SpawnCam(int client, int Ragdoll)
{
	// Generate unique id for the client so we can set the parenting
	// through parentname.
	char StrName[64];
	Format(StrName, sizeof(StrName), "fpd_Ragdoll%d", client);
	DispatchKeyValue(Ragdoll, "targetname", StrName);

	// Spawn dynamic prop entity
	int iEntity = CreateEntityByName("prop_dynamic");
	if (iEntity == -1)
		return false;

	// Generate unique id for the entity
	char StrEntityName[64];
	Format(StrEntityName, sizeof(StrEntityName), "fpd_RagdollCam%d", iEntity);

	// Setup entity
	DispatchKeyValue(iEntity, "targetname", StrEntityName);
	DispatchKeyValue(iEntity, "parentname", StrName);
	DispatchKeyValue(iEntity, "model", "models/blackout.mdl");
	DispatchKeyValue(iEntity, "solid", "0");
	DispatchKeyValue(iEntity, "rendermode", "10"); // dont render
	DispatchKeyValue(iEntity, "disableshadows", "1"); // no shadows

	float angles[3]; GetClientEyeAngles(client, angles);
	char CamTargetAngles[64];
	Format(CamTargetAngles, 64, "%f %f %f", angles[0], angles[1], angles[2]);
	DispatchKeyValue(iEntity, "angles", CamTargetAngles); 

	SetEntityModel(iEntity, "models/blackout.mdl");
	DispatchSpawn(iEntity);

	// Set parent
	SetVariantString(StrName);
	AcceptEntityInput(iEntity, "SetParent", iEntity, iEntity, 0);

	// Set attachment
	SetVariantString("facemask");
	AcceptEntityInput(iEntity, "SetParentAttachment", iEntity, iEntity, 0);
	// this bricks the Angles of the iEntity

	// Activate
	AcceptEntityInput(iEntity, "TurnOn");

	// Set View
	SetClientViewEntity(client, iEntity);

	ClientCamera[client] = iEntity;

	CreateTimer(4.0, ClearCamTimer, client);

//	DarkenScreen(client, 3000, true);

	return true;
}

public Action ClearCamTimer(Handle timer, int client)
{
	if(ClientCamera[client])
	{
//		DarkenScreen(client, 0, false);

		SetClientViewEntity(client, client);
		ClientCamera[client] = false;
	}
}

void DarkenScreen(int client, int duration, bool dark)
{
	Handle hFadeClient = StartMessageOne("Fade", client);
	PbSetInt(hFadeClient, "duration", duration);
	PbSetInt(hFadeClient, "hold_time", 0);
	if(!dark)
	{
		PbSetInt(hFadeClient, "flags", 0x0010); // FFADE_STAYOUT	0x0008		ignores the duration, stays faded out until new ScreenFade message received
	}
	else
	{
		PbSetInt(hFadeClient, "flags", 0x0008); // FFADE_PURGE		0x0010		Purges all other fades, replacing them with this one
	}
	PbSetColor(hFadeClient, "clr", {0, 0, 0, 255});
	EndMessage();
}

public void OnClientDisconnect(int client)
{
	g_bEquipt[client] = false;
}

bool IsValidClient(int client, bool bots = true, bool dead = true)
{
	if (client <= 0)
		return false;

	if (client > MaxClients)
		return false;

	if (!IsClientInGame(client))
		return false;

	if (IsFakeClient(client) && !bots)
		return false;

	if (IsClientSourceTV(client))
		return false;

	if (IsClientReplay(client))
		return false;

	if (GetClientTeam(client) == 1)
		return false;

	if (!IsPlayerAlive(client) && !dead)
		return false;

	return true;
}
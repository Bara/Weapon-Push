#include <sourcemod>
#include <cstrike>
#include <sdkhooks>
#include <sdktools>

#include <multicolors>

#pragma semicolon 1
#pragma newdecls required

#define PL_NAME "Weapon Push"
#define PL_VERSION "1.0.0"
#define PL_DESCRIPTION "Player can push other players"

ConVar g_cEnableMessage = null;
ConVar g_cTeamCanUse = null;
ConVar g_cTeamCanHit = null;
ConVar g_cWeapons = null;
ConVar g_cMinDamage = null;
ConVar g_cMaxDamage = null;
ConVar g_cDisableDamage = null;
ConVar g_cEnableCustomDamage = null;
ConVar g_cCustomDamage = null;

ArrayList g_aWeapons = null;

public Plugin myinfo = 
{
	name = PL_NAME, 
	author = "Bara", 
	description = PL_DESCRIPTION, 
	version = PL_VERSION, 
	url = "www.bara.in"
};

public void OnPluginStart()
{
	if (GetEngineVersion() != Engine_CSS && GetEngineVersion() != Engine_CSGO)
	{
		SetFailState("Only CSS and CSGO Support");
		return ;
	}
	
	CreateConVar("weapon-push_version", PL_VERSION, PL_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD);
	
	g_cEnableMessage = CreateConVar("weapon-push_enable_message", "1", "Should be enabled message?");
	g_cTeamCanUse = CreateConVar("weapon-push_team_can_use", "3", "Who can use this plugin? 0 - Admin only (ADMFLAG_GENERIC), 1 - Both, 2 - Terrorists, 3 - Counter-Terrorists", _, true, 0.0, true, 3.0);
	g_cTeamCanHit = CreateConVar("weapon-push_team_can_hit", "2", "Who can be hit? 0 - Admin only (ADMFLAG_GENERIC), 1 - Both, 2 - Terrorists, 3 - Counter-Terrorists", _, true, 0.0, true, 3.0);
	g_cWeapons = CreateConVar("weapon-push_weapons", "knife;bayonet", "With which weapons/items should work this plugin");
	g_cMinDamage = CreateConVar("weapon-push_min_damage", "0", "Between which damage? (Minimum)");
	g_cMaxDamage = CreateConVar("weapon-push_max_damage", "65", "Between which damage? (Maximum)");
	g_cDisableDamage = CreateConVar("weapon-push_disable_damage", "1", "Should disable damage?", _, true, 0.0, true, 1.0);
	g_cEnableCustomDamage = CreateConVar("weapon-push_enable_custom_damage", "0", "Do you want modify damage?", _, true, 0.0, true, 1.0);
	g_cCustomDamage = CreateConVar("weapon-push_custom_damage", "5", "How much damage? (weapon-push_disable_damage must be 0)");
	
	AutoExecConfig(true);
	
	g_aWeapons = new ArrayList();
	
	LoadTranslations("weapon-push.phrases");
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
		}
	}
}

public void OnConfigsExecuted()
{
	g_aWeapons.Clear();
	
	char sBuffer[512];
	char sList[8][64];
	
	g_cWeapons.GetString(sBuffer, sizeof(sBuffer));
	
	int iWeapons = ExplodeString(sBuffer, ";", sList, sizeof(sList), sizeof(sList[]));
	
	for (int i = 0; i < iWeapons; i++)
	{
		g_aWeapons.PushString(sList[i]);
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
}

public Action OnTakeDamageAlive(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (CheckAttacker(attacker))
	{
		if (CheckVictim(victim))
		{
			if (damage >= g_cMinDamage.IntValue && damage <= g_cMaxDamage.IntValue)
			{
				char sWeapon[64];
				GetClientWeapon(attacker, sWeapon, sizeof(sWeapon));
				
				int size = g_aWeapons.Length;
				
				for (int i = 0; i < size; i++)
				{
					char sBuffer[64];
					g_aWeapons.GetString(i, sBuffer, sizeof(sBuffer));
					
					if ((StrContains(sWeapon, sBuffer, false) != -1))
					{
						PushPlayer(victim, attacker);
						
						if (g_cEnableMessage.BoolValue)
							CPrintToChat(victim, "%T", "PlayerHit", victim, attacker);
						
						if (g_cDisableDamage.BoolValue)
							return Plugin_Handled;
						
						if (g_cEnableCustomDamage.BoolValue)
						{
							damage = float(g_cCustomDamage.IntValue);
							return Plugin_Changed;
						}
						return Plugin_Continue;
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

stock bool CheckAttacker(int client)
{
	if (IsClientInGame(client) && 
		(g_cTeamCanUse.IntValue == 0 && GetClientTeam(client) == CS_TEAM_CT || GetClientTeam(client) == CS_TEAM_T && CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC)) || 
		(g_cTeamCanUse.IntValue == 1 && GetClientTeam(client) == CS_TEAM_CT || GetClientTeam(client) == CS_TEAM_T) || 
		(g_cTeamCanUse.IntValue == 2 && GetClientTeam(client) == CS_TEAM_T) || 
		(g_cTeamCanUse.IntValue == 3 && GetClientTeam(client) == CS_TEAM_CT))
	{
		return true;
	}
	return false;
}

stock bool CheckVictim(int client)
{
	if (IsClientInGame(client) && 
		(g_cTeamCanHit.IntValue == 0 && GetClientTeam(client) == CS_TEAM_CT || GetClientTeam(client) == CS_TEAM_T && CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC)) || 
		(g_cTeamCanHit.IntValue == 1 && GetClientTeam(client) == CS_TEAM_CT || GetClientTeam(client) == CS_TEAM_T) || 
		(g_cTeamCanHit.IntValue == 2 && GetClientTeam(client) == CS_TEAM_T) || 
		(g_cTeamCanHit.IntValue == 3 && GetClientTeam(client) == CS_TEAM_CT))
	{
		return true;
	}
	return false;
}

stock void PushPlayer(int victim, int attacker)
{
	float fAttackerOrigin[3], fAttackeEye[3], fVictimOrigin[3], fPush[3];
	
	GetClientAbsOrigin(attacker, fAttackerOrigin);
	GetClientAbsOrigin(victim, fVictimOrigin);
	GetClientEyeAngles(attacker, fAttackeEye);
	
	fPush[0] = (500.0 * Cosine(DegToRad(fAttackeEye[1])));
	fPush[1] = (500.0 * Sine(DegToRad(fAttackeEye[1])));
	fPush[2] = (-50.0 * Sine(DegToRad(fAttackeEye[0])));
	
	TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, fPush);
} 

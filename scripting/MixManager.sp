#include <sourcemod>
// #include <multimanager>
#include <sdktools>
#include <sdkhooks>
//Variables
//Defentitions
#define TEAM_TOTAL 4
#define TEAM_CT 3
#define TEAM_T 2
#define TEAM_SPECTATOR 1
//Convars
ConVar g_cServerName = null;
ConVar g_cMatchPauseTime = null;
ConVar g_cMatchUserPauseAllowed = null;
ConVar g_cMatchMaxPauseNeeded = null;
ConVar g_cMatchReadySystem = null;
ConVar g_cMatchMaxReadyNeeded = null;
ConVar g_cServerPassword = null;
ConVar g_cShowTeamWeapons = null;
ConVar g_cEnableKnifeRound = null;
//Ints
int g_iPauseRequest[TEAM_TOTAL] = 0;
int g_iPauseSeconds = 0;
int g_iPauseUsed[TEAM_TOTAL] = 0;
int g_iWinner = 0;
//int g_iMaxReadyPlayers[TEAM_TOTAL] = 0;
//Strings
char g_sServerName[64];
char g_sServerPassword[64];
//Handles
Handle g_hPauseTimer = INVALID_HANDLE;
Handle g_hReadyTimer = INVALID_HANDLE;
//Booleans
bool g_bIsMatchPaused = false;
bool g_bIsMatchAwatingPause = false;
bool g_bHasUserRequestedForPause[MAXPLAYERS+1] = false;
bool g_bIsUserReady[MAXPLAYERS+1] = false;
bool g_bIsFirstRoundOfTheMatch = false;
bool g_bHasKnifeRoundSetup = false;
bool g_bAskForWinner = false;






public Plugin myinfo =
{
	name = "[CS:GO] MixManager (MultiManager Free Version)",
	author = "noBrain",
	version = "0.0.6 (Build 42)"
};

public void OnPluginStart()
{
	//Admin Commands
	RegAdminCmd("sm_live", MatchAction_Live, ADMFLAG_KICK, "Live the match.")
	RegAdminCmd("sm_warmup", MatchAction_Warmup, ADMFLAG_KICK, "Warmup the match");
	RegAdminCmd("sm_talk", MatchAction_Talk, ADMFLAG_KICK, "Change talking stats");
	RegAdminCmd("sm_swap", MatchAction_Swap, ADMFLAG_KICK, "Swap teams.");
	RegAdminCmd("sm_bkick", MatchAction_KickBots, ADMFLAG_KICK, "Kick in game fake clients..");
	RegAdminCmd("sm_team", MatchAction_ChangeTeam, ADMFLAG_KICK, "Change user's team");
	RegAdminCmd("sm_password", MatchAction_ChangePassword, ADMFLAG_KICK, "Change server's password");
	RegAdminCmd("sm_r1", MatchAction_Restart, ADMFLAG_KICK, "R1");
	
	
	//Client Commands
	RegConsoleCmd("sm_pause", MatchAction_PauseTheMatch, "Pause the match");
	RegConsoleCmd("sm_unpause", MatchAction_UnpauseTheMatch, "Unpause the match");
	RegConsoleCmd("sm_ready", MatchAction_ReadyPlayer, "Ready for the match");
	RegConsoleCmd("sm_unready", MatchAction_UnreadyPlayer, "Unready on the match");


	//Hook Say Commands
	RegConsoleCmd("say", MatchEvent_Say);
	RegConsoleCmd("say_team", MatchEvent_Say);
	
	//Server Commands
	
	
	//ConVars Defention
	g_cServerPassword = FindConVar("sv_password");
	g_cServerName = FindConVar("hostname");
	g_cMatchPauseTime = CreateConVar("mm_pause_time", "60.0", "Detemine how many seconds you want a match can be paused.");
	g_cMatchUserPauseAllowed = CreateConVar("mm_can_pause", "1", "Is it allowed for clients to request and pause the match?");
	g_cMatchMaxPauseNeeded = CreateConVar("mm_pause_max_users", "3",  "How many people from a same team must request pause to actiavte it.");
	g_cMatchReadySystem = CreateConVar("mm_ready_system", "1", "Enable/Disable ready system.");
	g_cMatchMaxReadyNeeded = CreateConVar("mm_ready_max", "10", "How many users should be ready for the match to get started.");
	g_cShowTeamWeapons = CreateConVar("mm_show_weapons", "1", "Enable?Disable showing of weapons bought each round to teammates.");
	g_cEnableKnifeRound = CreateConVar("mm_knife_round_enable", "1", "This will enable knife round in the first round after the match has started.");
	
	//Hooks
	HookEvent("round_start", MatchEvent_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("cs_match_end_restart", MatchEvent_GameEnd, EventHookMode_PostNoCopy); 
	HookEvent("player_disconnect", MatchEvent_PlayerDisconnected, EventHookMode_Pre); 
	HookEvent("item_purchase", MatchEvent_WeaponPurchased, EventHookMode_Pre); 
	HookEvent("round_end", MatchEvent_RoundEnd, EventHookMode_Pre);
	
	HookConVarChange(g_cMatchReadySystem, ConVarChange_ReadySystem);
	HookConVarChange(g_cServerPassword, ConVarChange_ServerPassword);
	
	
	//OnPlugin Configurations
	
	
	GetConVarString(g_cServerName, g_sServerName, sizeof(g_sServerName));
	
	//Translations?
	LoadTranslations("common.phrases.txt");
	
}

public void OnMapStart()
{
	CreateTimer(10.0, Timer_MapChangeWarmup, _, TIMER_FLAG_NO_MAPCHANGE);
	CreateLiveConfig();
	CreateWarmupConfig();
	UnreadyAllPlayers();
}

public Action Timer_MapChangeWarmup(Handle timer)
{
	StartWarmup();
	// if(GetConVarBool(g_cMatchReadySystem))
	// {
	// 	g_hReadyTimer = CreateTimer(0.5, Timer_ReportReadyStatus, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	// }
}
public Action Timer_ReportReadyStatus(Handle timer)
{
	for(int i = 1 ; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			if(!g_bIsUserReady[i])
			{
				PrintHintText(i, "Type <font color='#00ffff'>!Ready</font> in chat to become Ready!\nCurrently Ready Users: <font color='#00ffff'>%d/%d</font>\nNeeded Ready Players: <font color='#00ffff'>%d</font>", GetReadyPlayers(), GetInGameUsers(), GetConVarInt(g_cMatchMaxReadyNeeded));
			}
			else
			{
				PrintHintText(i, "You are currently <font color='#00ffff'>Ready!</font>\nCurrently Ready Users: <font color='#00ffff'>%d/%d</font>\nNeeded Ready Players: <font color='#00ffff'>%d</font>", GetReadyPlayers(), GetInGameUsers(), GetConVarInt(g_cMatchMaxReadyNeeded));
			}
		}
	}
}

////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////

public Action MatchEvent_RoundStart(Event event, char[] name, bool dontBroadcast)
{
	if(g_bIsMatchAwatingPause)
	{
		if(PauseWithTimer(GetConVarFloat(g_cMatchPauseTime)))
		{
			char ReplyMessage[128];
			ApplyColorVariables(" {RED}[MixManager] {LIME}Match has paused.", ReplyMessage, sizeof(ReplyMessage));
			PrintToChatAll(ReplyMessage);
			g_bIsMatchAwatingPause = false;
			return Plugin_Continue;
		}
		else
		{
			char ReplyMessage[128];
			ApplyColorVariables(" {RED}[MixManager] {LIME}Could not pause the match.", ReplyMessage, sizeof(ReplyMessage));
			PrintToChatAll(ReplyMessage);
			return Plugin_Continue;
		}
	}

	if(g_bIsFirstRoundOfTheMatch && GetConVarBool(g_cEnableKnifeRound))
	{
		CreateTimer(1.0, Timer_GiveKnifeToUsers);
		g_bIsFirstRoundOfTheMatch = false;
		g_bHasKnifeRoundSetup = true;
	}

	ResetPauseRequests();
	return Plugin_Continue;
}

public Action Timer_GiveKnifeToUsers(Handle timer)
{
	SetupKnifeRound();
}

public Action MatchEvent_RoundEnd(Event event, char[] name, bool dontBroadcast)
{
	if(g_bHasKnifeRoundSetup)
	{
		g_iWinner = event.GetInt("winner");
		char ReplyMessage[128];
		ApplyColorVariables(" {RED}[MixManager] {LIME}Stay or Swap?.", ReplyMessage, sizeof(ReplyMessage));
		PrintToTeam(ReplyMessage, g_iWinner);
		g_bAskForWinner = true;
		g_bHasKnifeRoundSetup = false;
	}
	
}


public Action MatchEvent_GameEnd(Event event, char[] name, bool dontBroadcast)
{
	char ReplyMessage[128];
	ApplyColorVariables(" {RED}[MixManager] {LIME}Match has ended, will set on warmup in 10 seconds.", ReplyMessage, sizeof(ReplyMessage));
	PrintToChatAll(ReplyMessage);
	CreateTimer(10.0, Timer_MatchSetWarmup, _,  TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Continue;
}

public Action MatchEvent_PlayerDisconnected(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(g_bIsUserReady[client])
	{
		char ReplyMessage[128];
		Format(ReplyMessage, sizeof(ReplyMessage), " {RED}[MixManager] {LIME}Player {PURPLE}%N {LIME} has became unready.")
		ApplyColorVariables(ReplyMessage, ReplyMessage, sizeof(ReplyMessage));
		PrintToChatAll(ReplyMessage);
		g_bIsUserReady[client] =  false;
	}
	return Plugin_Continue;
}

public void ConVarChange_ReadySystem(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(GetConVarBool(g_cMatchReadySystem))
	{
		if(g_hReadyTimer != INVALID_HANDLE)
		{
			KillTimer(g_hReadyTimer);
			g_hReadyTimer = INVALID_HANDLE;
			g_hReadyTimer = CreateTimer(0.5, Timer_ReportReadyStatus, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		}
		else
		{
			g_hReadyTimer = CreateTimer(0.5, Timer_ReportReadyStatus, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	else
	{
		if(g_hReadyTimer != INVALID_HANDLE)
		{
			KillTimer(g_hReadyTimer);
			g_hReadyTimer = INVALID_HANDLE;
		}
	}
}

public Action MatchEvent_WeaponPurchased(Event event, char[] name, bool dontBroadcast)
{
	char WeaponName[64], ReplyMessage[256], Message[256];
	int client = GetClientOfUserId(event.GetInt("userid"));
	// int team = event.GetInt("team");
	event.GetString("weapon", WeaponName, sizeof(WeaponName));

	if (GameRules_GetProp("m_bWarmupPeriod") != 1 && GetConVarBool(g_cShowTeamWeapons))
	{

		Format(Message, sizeof(Message), " {RED}[MixManager] {LIME}Player {PURPLE}%N {LIME} has bought {ORANGE}%s.", client, WeaponName);
		ApplyColorVariables(Message, ReplyMessage, sizeof(ReplyMessage));

		PrintToTeam(ReplyMessage, GetClientTeam(client));
	}

	if (g_bHasKnifeRoundSetup && GetConVarBool(g_cEnableKnifeRound))
	{
		int weapon;
		for (int i; i <= 4; i++) 
		{
			if ((weapon = GetPlayerWeaponSlot(client, i)) != -1) 
			{
				if(IsValidEntity(weapon)) 
				{
					char g_szWeaponClassName[32];
					GetEdictClassname(weapon, g_szWeaponClassName, sizeof(g_szWeaponClassName));
					if(StrEqual(g_szWeaponClassName, WeaponName, false))
					{
						Format(Message, sizeof(Message), " {RED}[MixManager] {LIME}You cannot buy weapons in knife round.");
						ApplyColorVariables(Message, ReplyMessage, sizeof(ReplyMessage));
						PrintToChat(client, ReplyMessage);

						RemovePlayerItem(client, weapon);
						AcceptEntityInput(weapon, "Kill");
					}
				}
			}
		}
	}
	
}

public void ConVarChange_ServerPassword(ConVar convar, const char[] oldValue, const char[] newValue)
{
	char StrPassword[64];
	GetConVarString(g_cServerPassword, StrPassword, sizeof(StrPassword));
	if(!StrEqual(StrPassword, g_sServerPassword, false))
	{
		SetConVarString(g_cServerPassword, g_sServerPassword, true, false);
	}
}





public Action Timer_MatchSetWarmup(Handle timer)
{
	StartWarmup();
}
////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////

public Action MatchAction_Restart(int client, int args)
{
	ServerCommand("mp_restartgame 1");
	char ReplyMessage[128];
	ApplyColorVariables(" {RED}[MixManager] {LIME}Match has restarted.", ReplyMessage, sizeof(ReplyMessage));
	PrintToChatAll(ReplyMessage);
}

public Action MatchEvent_Say(int client, int args)
{
	if(g_bAskForWinner)
	{
		char ChatMessage[64];
		GetCmdArgString(ChatMessage, sizeof(ChatMessage));
		StripQuotes(ChatMessage);

		if(StrEqual(ChatMessage, "stay", false))
		{
			char ReplyMessage[128];
			ApplyColorVariables(" {RED}[MixManager] {LIME}Winner chose Stay, Game will start in 5 seconds.", ReplyMessage, sizeof(ReplyMessage));
			PrintToChatAll(ReplyMessage);
		}
		else if(StrEqual(ChatMessage, "swap", false))
		{
			char ReplyMessage[128];
			ApplyColorVariables(" {RED}[MixManager] {LIME}Winner chose Swap, Game will start in 5 seconds.", ReplyMessage, sizeof(ReplyMessage));
			PrintToChatAll(ReplyMessage)
			SwapTeams();
		}
		g_bAskForWinner = false;
		ServerCommand("mp_restartgame 5");
	}

	return Plugin_Continue;
}


public Action MatchAction_Live(int client, int args)
{
	StartMatch();
	char ReplyMessage[128];
	ApplyColorVariables(" {RED}[MixManager] {LIME}Match has started by admin.", ReplyMessage, sizeof(ReplyMessage));
	PrintToChatAll(ReplyMessage);
	
	if(g_hReadyTimer != INVALID_HANDLE)
	{
		KillTimer(g_hReadyTimer);
		g_hPauseTimer = INVALID_HANDLE;
	}
	return Plugin_Handled;
}
public Action MatchAction_Warmup(int client, int args)
{
	StartWarmup();
	char ReplyMessage[128];
	ApplyColorVariables(" {RED}[MixManager] {LIME}Match has set to be on warmup by admin.", ReplyMessage, sizeof(ReplyMessage));
	PrintToChatAll(ReplyMessage);
	
	return Plugin_Handled;
}
public Action MatchAction_Talk(int client, int args)
{
	char ReplyMessage[128], ActionMessage[32];
	GetCmdArg(1, ActionMessage, sizeof(ActionMessage));
	int i_iActionNumber = StringToInt(ActionMessage);
	if(SetTalk(i_iActionNumber))
	{
		ApplyColorVariables(" {RED}[MixManager] {LIME}Talk stats has been changed.", ReplyMessage, sizeof(ReplyMessage));
		PrintToChatAll(ReplyMessage);
	}
}
public Action MatchAction_Swap(int client, int args)
{
	SwapTeams();
	char ReplyMessage[128];
	ApplyColorVariables(" {RED}[MixManager] {LIME}Teams has just swaped by admin.", ReplyMessage, sizeof(ReplyMessage));
	PrintToChatAll(ReplyMessage);
}
public Action MatchAction_KickBots(int client, int args)
{
	KickBots();
	char ReplyMessage[128];
	ApplyColorVariables(" {RED}[MixManager] {LIME}Bots has been kicked by admin.", ReplyMessage, sizeof(ReplyMessage));
	PrintToChatAll(ReplyMessage);
}
public Action MatchAction_ChangeTeam(int client, int args)
{
	char TargetUser[32], TargetTeam[8], ReplyMessage[128];
	if(args < 2)
	{
		ReplyToCommand(client, "[MM] Usage: !team userid team (teams: CT - T - SPEC)");
		return Plugin_Handled;
	}
	else
	{
		GetCmdArg(1, TargetUser, sizeof(TargetUser));
		GetCmdArg(2, TargetTeam, sizeof(TargetTeam));
		if(StrEqual(TargetUser, "@all", false))
		{
			if(StrEqual(TargetTeam, "CT", false))
			{
				for(int i = 1 ; i <= MaxClients ; i++)
				{
					if(IsClientInGame(i) && !IsFakeClient(i))
					{
						ChangeClientTeam(i, 3);
						
					}
				}
				
				ApplyColorVariables(" {RED}[MixManager] {LIME}Everyone has moved to {PURPLE}Counter-Terrorists.", ReplyMessage, sizeof(ReplyMessage));
				PrintToChatAll(ReplyMessage);
				return Plugin_Handled;
			}
			else if(StrEqual(TargetTeam, "T", false))
			{
				for(int i = 1 ; i <= MaxClients ; i++)
				{
					if(IsClientInGame(i) && !IsFakeClient(i))
					{
						ChangeClientTeam(i, 2);
					}
				}
				
				ApplyColorVariables(" {RED}[MixManager] {LIME}Everyone has moved to {PURPLE}Terrorists.", ReplyMessage, sizeof(ReplyMessage));
				PrintToChatAll(ReplyMessage);
				return Plugin_Handled;
			}
			else if(StrEqual(TargetTeam, "SPEC", false))
			{
				for(int i = 1 ; i <= MaxClients ; i++)
				{
					if(IsClientInGame(i) && !IsFakeClient(i))
					{
						ChangeClientTeam(i, 1);
					}
				}
				
				ApplyColorVariables(" {RED}[MixManager] {LIME}Everyone has moved to {PURPLE}Spectectors.", ReplyMessage, sizeof(ReplyMessage));
				PrintToChatAll(ReplyMessage);
				return Plugin_Handled;
			}
			else
			{
				ReplyToCommand(client, "[MM] Team not found.");
				return Plugin_Handled;
			}
			
		}
		else
		{
			int i_iTargetUser = FindTarget(client, TargetUser, true, false);
			if(i_iTargetUser != -1)
			{
				if(StrEqual(TargetTeam, "CT", false))
				{
					ChangeClientTeam(i_iTargetUser, 3);
					Format(ReplyMessage, sizeof(ReplyMessage), "{RED}[MixManager] {LIME}User {YELLOW}%N {LIME}has moved to {PURPLE}Counter-Terrorists.", i_iTargetUser); 
					ApplyColorVariables(ReplyMessage, ReplyMessage, sizeof(ReplyMessage));
					PrintToChatAll(ReplyMessage);
					return Plugin_Handled;
				}
				else if(StrEqual(TargetTeam, "T", false))
				{
					ChangeClientTeam(i_iTargetUser, 2);
					Format(ReplyMessage, sizeof(ReplyMessage), "{RED}[MixManager] {LIME}User {YELLOW}%N {LIME}has moved to {PURPLE}Terrorists.", i_iTargetUser); 
					ApplyColorVariables(ReplyMessage, ReplyMessage, sizeof(ReplyMessage));
					PrintToChatAll(ReplyMessage);
					return Plugin_Handled;
				}
				else if(StrEqual(TargetTeam, "SPEC", false))
				{
					ChangeClientTeam(i_iTargetUser, 1);
					Format(ReplyMessage, sizeof(ReplyMessage), "{RED}[MixManager] {LIME}User {YELLOW}%N {LIME}has moved to {PURPLE}Spectectors.", i_iTargetUser); 
					ApplyColorVariables(ReplyMessage, ReplyMessage, sizeof(ReplyMessage));
					PrintToChatAll(ReplyMessage);
					return Plugin_Handled;
				}
				else
				{
					ReplyToCommand(client, "[MM] Team not found.");
					return Plugin_Handled;
				}
			}
			else
			{
				return Plugin_Handled;
			}
		}
	}
}
public Action MatchAction_PauseTheMatch(int client, int args)
{
	if(IsClientAdmin(client))
	{
		PauseMatch();
		char ReplyMessage[128];
		ApplyColorVariables(" {RED}[MixManager] {LIME}Match has paused by admin.", ReplyMessage, sizeof(ReplyMessage));
		PrintToChatAll(ReplyMessage);
		return Plugin_Handled;
	}
	else
	{
		if(GetConVarBool(g_cMatchUserPauseAllowed))
		{
			if (GameRules_GetProp("m_bWarmupPeriod") == 1)
			{
				ReplyToCommand(client, "[MM] You cannot pause the match in warmup!");
				return Plugin_Handled;
			}
			else if(GameRules_GetProp("m_bMatchWaitingForResume") == 1)
			{
				ReplyToCommand(client, "[MM] You cannot pause the match while it's already paused!");
				return Plugin_Handled;
			}
			else if (GameRules_GetProp("m_bFreezePeriod") == 1)
			{
				if(!g_bHasUserRequestedForPause[client])
				{
					g_iPauseRequest[GetClientTeam(client)]++;
					g_bHasUserRequestedForPause[client] = true;
					if(g_iPauseRequest[GetClientTeam(client)] == GetConVarInt(g_cMatchMaxPauseNeeded))
					{
						if(PauseWithTimer(GetConVarFloat(g_cMatchPauseTime)))
						{
							char ReplyMessage[128];
							ApplyColorVariables(" {RED}[MixManager] {LIME}Match has been paused during the freezetime.", ReplyMessage, sizeof(ReplyMessage));
							PrintToChatAll(ReplyMessage);
							g_iPauseRequest[GetClientTeam(client)] = 0;
							return Plugin_Handled;
						}
						else
						{
							char ReplyMessage[128];
							ApplyColorVariables(" {RED}[MixManager] {LIME}Could not pause the match.", ReplyMessage, sizeof(ReplyMessage));
							PrintToChatAll(ReplyMessage);
							return Plugin_Handled;
						}
					}
				}
				else
				{
					ReplyToCommand(client, "[MM] You cannot request for pause twice.");
					return Plugin_Handled;
				}
			}
			else if(g_bIsMatchAwatingPause)
			{
				ReplyToCommand(client, "[MM] You cannot request to pause the match becasue the match is already set to be paused on the next freezetime!");
				return Plugin_Handled;
			}
			else
			{
				if(!g_bHasUserRequestedForPause[client])
				{
					g_iPauseRequest[GetClientTeam(client)]++;
					g_bHasUserRequestedForPause[client] = true;
					if(g_iPauseRequest[GetClientTeam(client)] == GetConVarInt(g_cMatchMaxPauseNeeded))
					{
						char ReplyMessage[128];
						ApplyColorVariables(" {RED}[MixManager] {LIME}Match has set to pause in next round.", ReplyMessage, sizeof(ReplyMessage));
						PrintToChatAll(ReplyMessage);
						g_bIsMatchAwatingPause = true;
						return Plugin_Handled;
					}
				}
				else
				{
					ReplyToCommand(client, "[MM] You cannot request for pause twice.");
					return Plugin_Handled;
				}
				
			}
		}
		else
		{
			ReplyToCommand(client, "[MM] User pause is not allowed on this server.");
			return Plugin_Handled;
		}
	}
	return Plugin_Handled;
}
public Action MatchAction_UnpauseTheMatch(int client, int args)
{
	if(IsClientAdmin(client))
	{
		if(GameRules_GetProp("m_bMatchWaitingForResume") == 1)
		{
			UnpauseMatch();
		}
		else if(g_bIsMatchAwatingPause)
		{
			g_bIsMatchAwatingPause = false;
		}
	}
	return Plugin_Handled;
}
public Action MatchAction_ChangePassword(int client, int args)
{
	char InputPassword[64];
	if(args < 1)
	{
		ReplyToCommand(client, "[MM] Usage: sm_password password");
		return Plugin_Handled;
	}
	GetCmdArg(1, InputPassword, sizeof(InputPassword));
	ChangeServerPassword(InputPassword);
	return Plugin_Handled;
}

public Action MatchAction_ReadyPlayer(int client, int args)
{
	if(GetConVarBool(g_cMatchReadySystem))
	{
		if (GameRules_GetProp("m_bWarmupPeriod") == 1)
		{
			g_bIsUserReady[client] = true;
			ReplyToCommand(client, "[MM] You are now ready.");
			if(GetReadyPlayers() >= GetConVarInt(g_cMatchMaxReadyNeeded))
			{
				char ReplyMessage[128];
				ApplyColorVariables(" {RED}[MixManager] {LIME}Enough players are ready now, the match will start shortly.", ReplyMessage, sizeof(ReplyMessage));
				PrintToChatAll(ReplyMessage);
				StartMatchInSeconds(15.0);
			}
			return Plugin_Handled;
		}
		else
		{
			ReplyToCommand(client, "[MM] You cannot ready while the match is in progress.");
			return Plugin_Handled;
		}
		
	}
	else
	{
		ReplyToCommand(client, "[MM] Ready system is not enabled.");
		return Plugin_Handled;
	}
}

public Action MatchAction_UnreadyPlayer(int client, int args)
{
	if(GetConVarBool(g_cMatchReadySystem))
	{
		g_bIsUserReady[client] = false;
		ReplyToCommand(client, "[MM] You are now unready.");
		return Plugin_Handled;
	}
	else
	{
		ReplyToCommand(client, "[MM] Ready system is not enabled.");
		return Plugin_Handled;
	}
}



///////////////////////////////////////////////
///////////////////////////////////////////////
//////////////   Methods   ////////////////////
///////////////////////////////////////////////
///////////////////////////////////////////////

stock void StartMatch()
{
	char ConfigFile[128];
	// MM_GetId(ServerID, sizeof(ServerID));
	Format(ConfigFile, sizeof(ConfigFile), "live.cfg");
	ServerCommand("exec %s", ConfigFile);
	PrintToServer("[MM] Match config has executed.");
	SetServerStatus("Currently Matching");

	g_bIsFirstRoundOfTheMatch = true;
}

stock void StartWarmup()
{
	char ConfigFile[128];
	// MM_GetId(ServerID, sizeof(ServerID));
	Format(ConfigFile, sizeof(ConfigFile), "warmup.cfg");
	ServerCommand("exec %s", ConfigFile);
	PrintToServer("[MM] Warmup config has executed.");
	SetServerStatus("Currently On Warmup");

	if(GetConVarBool(g_cMatchReadySystem))
	{
		if(g_hReadyTimer != INVALID_HANDLE)
		{
			KillTimer(g_hReadyTimer);
			g_hReadyTimer = INVALID_HANDLE;
			g_hReadyTimer = CreateTimer(0.5, Timer_ReportReadyStatus, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		}
		else
		{
			g_hReadyTimer = CreateTimer(0.5, Timer_ReportReadyStatus, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		}
	}


	if(g_hPauseTimer != INVALID_HANDLE)
	{
		KillTimer(g_hPauseTimer);
		g_hPauseTimer = INVALID_HANDLE;
	}
	
	UnreadyAllPlayers();
	ResetPauseRequests();
}

stock void ApplyColorVariables(char[] message, char[] output, int maxlen)
{
	char input[128];
	Format(input, sizeof(input), "%s", message);
	ReplaceString(input, sizeof(input), "{RED}", "\x02");
	ReplaceString(input, sizeof(input), "{LIGHT PURPLE}", "\x03");
	ReplaceString(input, sizeof(input), "{GREEN}", "\x04");
	ReplaceString(input, sizeof(input), "{LIGHT GREEN}", "\x05");
	ReplaceString(input, sizeof(input), "{LIME}", "\x06");
	ReplaceString(input, sizeof(input), "{LIGHT RED}", "\x07");
	ReplaceString(input, sizeof(input), "{GREY}", "\x08");
	ReplaceString(input, sizeof(input), "{YELLOW}", "\x09");
	ReplaceString(input, sizeof(input), "{LIGHT BLUE}", "\x0B");
	ReplaceString(input, sizeof(input), "{DARK BLUE}", "\x0C");
	ReplaceString(input, sizeof(input), "{PURPLE}", "\x0E");
	ReplaceString(input, sizeof(input), "{ORANGE}", "\x10");
	
	Format(output, maxlen, input, sizeof(input));
}

stock void PrintToTeam(char[] Message, int team)
{
	for(int i = 1 ; i <= MaxClients ; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == team)
		{
			PrintToChat(i, Message);	
		}
	}
}

stock bool SetTalk(int talkmode)
{
	ConVar i_cServerAllTalk = null;
	i_cServerAllTalk = FindConVar("sv_full_alltalk");
	if(talkmode == 1)
	{
		SetConVarInt(i_cServerAllTalk, 1, true, true);
		return true;
	}
	else if(talkmode == 0)
	{
		SetConVarInt(i_cServerAllTalk, 0, true, true);
		return true;
	}
	else
	{
		return false;
	}
}
stock void SwapTeams()
{
	ServerCommand("mp_swapteams");
}

stock void KickBots()
{
	for(int i = 1; i <= MaxClients ; i++)
	{
		if(IsClientInGame(i) && IsFakeClient(i))
		{
			KickClient(i, "Fake Client");
		}
	}
}

stock void PauseMatch()
{
	ServerCommand("mp_pause_match");
	SetServerStatus("Currently Paused");
	g_bIsMatchPaused = true;
}

stock void UnpauseMatch()
{
	ServerCommand("mp_unpause_match");
	RestoreServerName();
	g_bIsMatchPaused = false;
}

stock void ChangeServerPassword(char[] password)
{
	//ConVar i_iServerPassword = null;
	//i_iServerPassword = FindConVar("sv_password");
	SetConVarString(g_cServerPassword, password, true, true);
	Format(g_sServerPassword, sizeof(g_sServerPassword), "%s", password);
}

stock void CreateWarmupConfig()
{
	char mFile[256];
	// MM_GetId(sID, sizeof(sID));
	Format(mFile, sizeof(mFile), "cfg/warmup.cfg");
	
	if(FileExists(mFile))
	{
		PrintToServer("[MixManager] ==> Warmup config already exists,");
	}
	Handle hFile = OpenFile(mFile, "w");
	PrintToServer("[MixManager] ==> warmup.cfg Has Created!");
	WriteFileLine(hFile, "//This Conifg File Was Created Automatically By MixManager");
	WriteFileLine(hFile, "// All Right Reserved For Dr.noBrain!");
	WriteFileLine(hFile, "mp_buy_anywhere 1");
	WriteFileLine(hFile, "mp_free_armor 1");
	WriteFileLine(hFile, "mp_maxmoney 60000");
	WriteFileLine(hFile, "mp_freezetime 0");
	WriteFileLine(hFile, "mp_friendlyfire 0");
	WriteFileLine(hFile, "mp_buytime 999999999");
	WriteFileLine(hFile, "mp_maxmoney 60000");
	WriteFileLine(hFile, "mp_startmoney 60000");
	WriteFileLine(hFile, "sv_talk_enemy_living 1");
	WriteFileLine(hFile, "sv_talk_enemy_dead 1");
	WriteFileLine(hFile, "sv_full_alltalk 1");
	WriteFileLine(hFile, "mp_free_armor 1");
	WriteFileLine(hFile, "mp_c4timer 999");
	WriteFileLine(hFile, "sv_damage_print_enable 1 ");
	WriteFileLine(hFile, "mp_maxrounds 999");
	WriteFileLine(hFile, "sv_voiceenable 1");
	WriteFileLine(hFile, "mp_death_drop_gun 0");
	WriteFileLine(hFile, "mp_buy_allow_grenades 0");
	WriteFileLine(hFile, "mp_death_drop_defuser 0");
	WriteFileLine(hFile, "sv_infinite_ammo 2");
	WriteFileLine(hFile, "mp_buy_anywhere 1");
	WriteFileLine(hFile, "mp_warmup_start");
	WriteFileLine(hFile, "mp_warmuptime 99999");
	WriteFileLine(hFile, "sv_coaching_enabled 0");
	WriteFileLine(hFile, "bot_quota	0");
	WriteFileLine(hFile, "sv_competitive_official_5v5 0");
	WriteFileLine(hFile, "echo [MixManager] ===> Warmup Has Started!");
	WriteFileLine(hFile, "echo [MixManager] ===> Now Teams Can Arrange ThemSelves!");
	CloseHandle(hFile);
}
stock void CreateLiveConfig()
{
	char mFile[256];
	// MM_GetId(sID, sizeof(sID));
	Format(mFile, sizeof(mFile), "cfg/live.cfg");
	
	if(FileExists(mFile))
	{
		PrintToServer("[MixManager] ==> live.cfg is already exist!");
	}
	else
	{
		Handle hFile = OpenFile(mFile, "w");
		PrintToServer("[MixManager] ==> live.cfg Has Created!");
		WriteFileLine(hFile, "//This Conifg File Was Created Automatically By MixManager");
		WriteFileLine(hFile, "// All Right Reserved For Dr.noBrain!");
		WriteFileLine(hFile, "bot_autodifficulty_threshold_high 0.0");
		WriteFileLine(hFile, "bot_autodifficulty_threshold_low -2.0");
		WriteFileLine(hFile, "bot_chatter normal");
		WriteFileLine(hFile, "bot_defer_to_human_goals 1");
		WriteFileLine(hFile, "bot_defer_to_human_items 1");
		WriteFileLine(hFile, "bot_difficulty 2");
		WriteFileLine(hFile, "bot_quota 0");
		WriteFileLine(hFile, "bot_quota_mode fill");
		WriteFileLine(hFile, "cash_player_bomb_defused 300");
		WriteFileLine(hFile, "cash_player_bomb_planted 300");
		WriteFileLine(hFile, "cash_player_damage_hostage -30");
		WriteFileLine(hFile, "cash_player_interact_with_hostage 300");
		WriteFileLine(hFile, "cash_player_killed_enemy_default 300");
		WriteFileLine(hFile, "cash_player_killed_enemy_factor 1");
		WriteFileLine(hFile, "cash_player_killed_hostage -1000");
		WriteFileLine(hFile, "cash_player_killed_teammate -300");
		WriteFileLine(hFile, "cash_player_rescued_hostage 1000");
		WriteFileLine(hFile, "cash_team_elimination_bomb_map 3250");
		WriteFileLine(hFile, "cash_team_elimination_hostage_map_t 3000");
		WriteFileLine(hFile, "cash_team_elimination_hostage_map_ct 3000");
		WriteFileLine(hFile, "cash_team_hostage_alive 0");
		WriteFileLine(hFile, "cash_team_hostage_interaction 600");
		WriteFileLine(hFile, "cash_team_loser_bonus	1400");
		WriteFileLine(hFile, "cash_team_loser_bonus_consecutive_rounds 500");
		WriteFileLine(hFile, "cash_team_planted_bomb_but_defused 800");
		WriteFileLine(hFile, "cash_team_rescued_hostage 600");
		WriteFileLine(hFile, "cash_team_terrorist_win_bomb 3500");
		WriteFileLine(hFile, "cash_team_win_by_defusing_bomb 3500");
		WriteFileLine(hFile, "cash_team_win_by_hostage_rescue 2900");
		WriteFileLine(hFile, "cash_team_win_by_time_running_out_hostage 3250");
		WriteFileLine(hFile, "cash_team_win_by_time_running_out_bomb 3250");
		WriteFileLine(hFile, "ff_damage_reduction_bullets 0.33");
		WriteFileLine(hFile, "ff_damage_reduction_grenade	 0.85");
		WriteFileLine(hFile, "ff_damage_reduction_grenade_self 1");
		WriteFileLine(hFile, "ff_damage_reduction_other 0.4");
		WriteFileLine(hFile, "mp_afterroundmoney 0");
		WriteFileLine(hFile, "mp_buytime 20");
		WriteFileLine(hFile, "mp_buy_anywhere 0");
		WriteFileLine(hFile, "mp_buy_during_immunity 0");
		WriteFileLine(hFile, "mp_death_drop_defuser 1");
		WriteFileLine(hFile, "mp_death_drop_grenade 2");
		WriteFileLine(hFile, "mp_death_drop_gun 1	");
		WriteFileLine(hFile, "mp_defuser_allocation	 0");
		WriteFileLine(hFile, "mp_force_pick_time 15");
		WriteFileLine(hFile, "mp_forcecamera 1");
		WriteFileLine(hFile, "mp_free_armor 0");
		WriteFileLine(hFile, "mp_freezetime 15");
		WriteFileLine(hFile, "mp_friendlyfire 1");
		WriteFileLine(hFile, "mp_win_panel_display_time 3");
		WriteFileLine(hFile, "mp_ggprogressive_round_restart_delay 15");
		WriteFileLine(hFile, "mp_ggtr_bomb_defuse_bonus 1");
		WriteFileLine(hFile, "mp_ggtr_bomb_detonation_bonus 1");
		WriteFileLine(hFile, "mp_ggtr_bomb_pts_for_flash 4");
		WriteFileLine(hFile, "mp_ggtr_bomb_pts_for_he 3");
		WriteFileLine(hFile, "mp_ggtr_bomb_pts_for_molotov 5");
		WriteFileLine(hFile, "mp_ggtr_bomb_pts_for_upgrade 2");
		WriteFileLine(hFile, "mp_ggtr_bomb_respawn_delay 0");
		WriteFileLine(hFile, "mp_ggtr_end_round_kill_bonus 1");
		WriteFileLine(hFile, "mp_ggtr_halftime_delay 0.0");
		WriteFileLine(hFile, "mp_ggtr_last_weapon_kill_ends_half 0");
		WriteFileLine(hFile, "mp_respawn_immunitytime 0");
		WriteFileLine(hFile, "mp_halftime 1");
		WriteFileLine(hFile, "mp_match_can_clinch 1");
		WriteFileLine(hFile, "mp_maxmoney 16000");
		WriteFileLine(hFile, "mp_maxrounds 30");
		WriteFileLine(hFile, "mp_molotovusedelay 0");
		WriteFileLine(hFile, "mp_playercashawards 1");
		WriteFileLine(hFile, "mp_roundtime 2.5");
		WriteFileLine(hFile, "mp_roundtime_hostage 2");
		WriteFileLine(hFile, "mp_roundtime_defuse	 2");
		WriteFileLine(hFile, "mp_solid_teammates 1");
		WriteFileLine(hFile, "mp_startmoney 800");
		WriteFileLine(hFile, "mp_teamcashawards 1");
		WriteFileLine(hFile, "mp_timelimit 0");
		WriteFileLine(hFile, "mp_warmuptime 60");
		WriteFileLine(hFile, "mp_warmup_end");
		WriteFileLine(hFile, "mp_weapons_allow_zeus 1");
		WriteFileLine(hFile, "spec_freeze_panel_extended_time 0");
		WriteFileLine(hFile, "spec_freeze_time 5.0");
		WriteFileLine(hFile, "sv_allow_votes 1");
		WriteFileLine(hFile, "sv_voiceenable 1");
		WriteFileLine(hFile, "sv_alltalk 0");
		WriteFileLine(hFile, "sv_arms_race_vote_to_restart_disallowed_after 0");
		WriteFileLine(hFile, "sv_deadtalk 1");
		WriteFileLine(hFile, "sv_ignoregrenaderadio	 0");
		WriteFileLine(hFile, "mp_warmup_pausetimer 0");
		WriteFileLine(hFile, "mp_halftime_pausetimer 0");
		WriteFileLine(hFile, "mp_randomspawn 0");
		WriteFileLine(hFile, "mp_randomspawn_los 0");
		WriteFileLine(hFile, "sv_infinite_ammo 0");
		WriteFileLine(hFile, "ammo_grenade_limit_flashbang 2");
		WriteFileLine(hFile, "ammo_grenade_limit_total 4");
		WriteFileLine(hFile, "mp_weapons_allow_map_placed 1");
		WriteFileLine(hFile, "mp_weapons_glow_on_ground 0");
		WriteFileLine(hFile, "mp_display_kill_assists 1");
		WriteFileLine(hFile, "mp_respawn_on_death_t 0");
		WriteFileLine(hFile, "mp_respawn_on_death_ct 0");
		WriteFileLine(hFile, "mp_ct_default_melee weapon_knife");
		WriteFileLine(hFile, "mp_ct_default_secondary weapon_hkp2000");
		WriteFileLine(hFile, "mp_ct_default_primary ");
		WriteFileLine(hFile, "mp_t_default_melee weapon_knife");
		WriteFileLine(hFile, "mp_t_default_secondary weapon_glock");
		WriteFileLine(hFile, "mp_t_default_primary ");
		WriteFileLine(hFile, "mp_default_team_winner_no_objective -1");
		WriteFileLine(hFile, "sv_full_alltalk 0");
		WriteFileLine(hFile, "sv_talk_enemy_living 0");
		WriteFileLine(hFile, "sv_talk_enemy_dead 0");
		WriteFileLine(hFile, "mp_death_drop_defuser 1");
		WriteFileLine(hFile, "mp_buy_allow_grenades 1");
		WriteFileLine(hFile, "mp_c4timer 45");
		WriteFileLine(hFile, "sv_coaching_enabled 1");
		WriteFileLine(hFile, "sv_competitive_official_5v5 1");
		WriteFileLine(hFile, "mp_overtime_enable 1");
		WriteFileLine(hFile, "mp_drop_knife_enable 0");
		CloseHandle(hFile);
	}
}

stock void SetServerStatus(char[] AddtionText)
{
	char ServerPostName[64];
	Format(ServerPostName, sizeof(ServerPostName), "%s [%s]", g_sServerName,  AddtionText);
	SetConVarString(g_cServerName, ServerPostName, true, false);
}
stock void RestoreServerName()
{
	SetConVarString(g_cServerName, g_sServerName, true, false);
}

stock bool IsClientAdmin(int client)
{
	if(GetUserFlagBits(client) == 0)
	{
		return false;
	}
	else
	{
		return true;
	}
}

stock bool PauseWithTimer(float pauseTime)
{
	if(g_bIsMatchPaused)
	{
		return false;
	}
	else
	{
		if(g_hPauseTimer == INVALID_HANDLE)
		{
			g_hPauseTimer = CreateTimer(1.0, Timer_PauseCounter, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
			g_iPauseSeconds = RoundFloat(pauseTime);
			PauseMatch();
			return true;
		}
		else
		{
			KillTimer(g_hPauseTimer);
			g_hPauseTimer = INVALID_HANDLE;
			g_hPauseTimer = CreateTimer(1.0, Timer_PauseCounter, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
			g_iPauseSeconds = RoundFloat(pauseTime);
			PauseMatch();
			return true;
		}
	}
}
public Action Timer_PauseCounter(Handle timer)
{
	if(g_iPauseSeconds == 0)
	{
		UnpauseMatch();
		ResetPauseRequests();
	}
	else
	{
		PrintHintTextToAll("<font color='#ff0000'>[MM]</font> Match will unpause in <font color='#00ffff'>%d</font> seconds.",  g_iPauseSeconds);
		g_iPauseSeconds--;
	}
}

stock void ResetAllMatchSettings()
{
	//g_iMaxReadyPlayers[TEAM_CT] = 0;
	//g_iMaxReadyPlayers[TEAM_T] = 0;
	for(int i = 1;i <= MaxClients;i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && g_bIsUserReady[i])
		{
			g_bIsUserReady[i] = false;
		}
	}
}

stock void StartMatchInSeconds(float seconds)
{
	CreateTimer(seconds, Timer_MatchPreperationTimer, _, TIMER_FLAG_NO_MAPCHANGE);
	if(g_hReadyTimer != INVALID_HANDLE)
	{
		KillTimer(g_hReadyTimer);
		g_hReadyTimer = INVALID_HANDLE;
	}
	
	PrintHintTextToAll("<font color='#ff0000'>[MM]</font> <font color='#00ffff'>Match will begin in</font> <font color='#0040ff'>10</font> <font color='#00ffff'>Seconds.</font>");
	
}
public Action Timer_MatchPreperationTimer(Handle timer)
{
	if(GetReadyPlayers() < GetConVarInt(g_cMatchMaxReadyNeeded))
	{
		PrintToChatAll(" \x2[MM] \x01Match has failed to start due to not enough players are ready as expected.");
		StartWarmup();
		// if(GetConVarBool(g_cMatchReadySystem))
		// {
		// 	g_hReadyTimer = CreateTimer(0.5, Timer_ReportReadyStatus, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		// }
	}
	else if(GetReadyPlayers() >= GetConVarInt(g_cMatchMaxReadyNeeded))
	{
		PrintHintTextToAll("<font color='#ff0000'>[MM]</font> Match has started.");
		StartMatch();
	}
}

stock void ReadyAllPlayers()
{
	for(int i = 1;i <= MaxClients;i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && !g_bIsUserReady[i])
		{
			g_bIsUserReady[i] = true;
		}
	}
	if(GetReadyPlayers() >= GetConVarInt(g_cMatchMaxReadyNeeded))
	{
		StartMatchInSeconds(15.0);
	}
}

stock void UnreadyAllPlayers()
{
	for(int i = 1;i <= MaxClients;i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && g_bIsUserReady[i])
		{
			g_bIsUserReady[i] = false;
		}
	}
}

stock int GetReadyPlayers()
{
	int i_iReadyCounter = 0;
	for(int i = 1;i <= MaxClients;i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && g_bIsUserReady[i])
		{
			i_iReadyCounter++;
		}
	}
	return i_iReadyCounter;
}

stock int GetInGameUsers()
{
	int i_iPlayerCounter = 0;
	for(int i = 1;i <= MaxClients;i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			i_iPlayerCounter++;
		}
	}
	return i_iPlayerCounter;
}
stock void ResetPauseRequests()
{
	for(int i = 1;i <= MaxClients;i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && g_bHasUserRequestedForPause[i])
		{
			g_bHasUserRequestedForPause[i] = false;
		}
	}
	g_iPauseRequest[TEAM_CT] = 0;
	g_iPauseRequest[TEAM_T] = 0;
}

stock void SetupKnifeRound()
{
	for(int i = 1;i <= MaxClients;i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			StripAllWeapons(i);
			GivePlayerItem(i, "weapon_knife");
		}
	}
}

stock void StripAllWeapons(int client) {

	if (client < 1 || client > MaxClients || !IsClientInGame(client)) 
	{
		return;
	}

	int weapon;
	for (int i; i < 4; i++) 
	{
		if ((weapon = GetPlayerWeaponSlot(client, i)) != -1) 
		{
			if (IsValidEntity(weapon)) 
			{
				RemovePlayerItem(client, weapon);
				AcceptEntityInput(weapon, "Kill");
			}
		}
	}
}











































